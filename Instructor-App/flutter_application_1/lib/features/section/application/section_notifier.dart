import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../data/section_api.dart';
import '../domain/section_models.dart';
import 'section_state.dart';

final sectionApiProvider = Provider((ref) => SectionApi());

final sectionProvider =
    StateNotifierProvider.autoDispose<SectionNotifier, SectionState>((ref) {
  return SectionNotifier(ref);
});

class SectionNotifier extends StateNotifier<SectionState> {
  final Ref ref;
  Timer? _timer;

  SectionNotifier(this.ref) : super(const SectionState());

  // ======================
  // Students list — loads via attendance history
  // ======================
  Future<void> loadStudents({
    required String courseId,
    required String sectionId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Always call getLatestMeetingForSectionToday first.
      // This returns FINAL / DRAFT / DEFAULT mode with correct per-student status.
      final json = await ref
          .read(sectionApiProvider)
          .getLatestMeetingForSectionToday(
              courseId: courseId, sectionId: sectionId);

      final meeting = MeetingAttendanceResponse.fromJson(json);

      // Build StudentsResponse from the meeting response (includes names)
      final students = meeting.toStudentsResponse();

      // Pre-fill present/absent from what the backend says
      final present = meeting.presentStudentIds;

      // If the meeting had a session today, restore qr partial state
      // so the meetingId/sessionId are known for flags and "Not Scanned" screens.
      GenerateQrResponse? restoredQr;
      FlagsResponse? loadedFlags;
      
      if (meeting.meetingId != null && meeting.sessionId != null) {
        restoredQr = GenerateQrResponse(
          sessionId: meeting.sessionId!,
          meetingId: meeting.meetingId!,
          courseId: courseId,
          sectionId: sectionId,
          expiresAt: 0, // session already ended or is historical
        );

        // Fetch flags for the main dashboard if we have a session ID
        try {
          final flagsJson = await ref
              .read(sectionApiProvider)
              .getFlagsForSession(sessionId: meeting.sessionId!);
          loadedFlags = FlagsResponse.fromJson(flagsJson);
        } catch (_) {
          // Ignore fetch errors
        }
      }

      state = state.copyWith(
        isLoading: false,
        students: students,
        meetingState: meeting,
        presentSelected: present,
        qr: restoredQr ?? state.qr,
        flags: loadedFlags ?? state.flags,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void togglePresent(String studentId) {
    final s = {...state.presentSelected};
    if (s.contains(studentId)) {
      s.remove(studentId);
    } else {
      s.add(studentId);
    }
    state = state.copyWith(presentSelected: s);
  }

  // ======================
  // QR flow
  // ======================
  Future<void> generateQr({
    required String courseId,
    required String sectionId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final json = await ref.read(sectionApiProvider).generateQr(
            courseId: courseId,
            sectionId: sectionId,
          );
      final qr = GenerateQrResponse.fromJson(json);

      // Simple clock sync: calculate the difference between server expiry and local time.
      // Assuming the backend sets a 60-second duration locally in the cloud,
      // we align the local 'now' so that the display shows the correct duration.
      final localNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Offset = (Expiration on Server) - (60 seconds) - (Local Time Now)
      final offset = qr.expiresAt - 60 - localNow;

      state = state.copyWith(
        isLoading: false, 
        qr: qr,
        serverClockOffset: offset,
      );

      // Start live refresh while QR running
      setAutoRefresh(true);
      await refreshScansAndFlags();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refreshScansAndFlags() async {
    final qr = state.qr;
    if (qr == null) return;

    try {
      final scansJson = await ref
          .read(sectionApiProvider)
          .getScansForMeeting(meetingId: qr.meetingId);

      final flagsJson = await ref
          .read(sectionApiProvider)
          .getFlagsForSession(sessionId: qr.sessionId);

      final scans = ScansResponse.fromJson(scansJson);
      final flags = FlagsResponse.fromJson(flagsJson);

      state = state.copyWith(scans: scans, flags: flags);
    } catch (_) {
      // ignore periodic failures
    }
  }

  void setAutoRefresh(bool v) {
    state = state.copyWith(autoRefresh: v);
    _timer?.cancel();

    if (!v) {
      _timer = null;
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await refreshScansAndFlags();
    });
  }

  /// Instructor ends session locally (stop polling + stop accepting more in UI)
  /// NOTE: Your backend still allows scans until expires_at hits, but instructor UI ends now.
  void endQrSessionNow() {
    setAutoRefresh(false);
  }

  /// After QR ends:
  /// - scanned students => checked
  /// - not scanned => unchecked
  void applyQrResultAsAttendance() {
    final scans = state.scans;
    final students = state.students;

    if (students == null) return;
    final all = students.studentIds.toSet();

    // If no scans loaded, treat as none scanned
    final scanned = (scans?.scannedStudentIds ?? []).toSet();

    // Only keep scanned as present
    final present = scanned.intersection(all);

    state = state.copyWith(presentSelected: present);
  }

  // ======================
  // Absent Students Load
  // ======================
  Future<void> loadAbsentStudents({
    required String courseId,
    required String sectionId,
    required String meetingId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final json = await ref.read(sectionApiProvider).getAbsentForMeeting(
            courseId: courseId,
            sectionId: sectionId,
            meetingId: meetingId,
          );
      final absentState = AbsentResponse.fromJson(json);

      // Also attempt to refresh flags here to keep both screens in sync
      FlagsResponse? updatedFlags;
      final sid = state.qr?.sessionId ?? state.meetingState?.sessionId;
      if (sid != null) {
        try {
          final fJson = await ref
              .read(sectionApiProvider)
              .getFlagsForSession(sessionId: sid);
          updatedFlags = FlagsResponse.fromJson(fJson);
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false, 
        absentState: absentState,
        flags: updatedFlags ?? state.flags,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ======================
  // Final save
  // ======================
  Future<Map<String, dynamic>?> finalize({
    required String courseId,
    required String sectionId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final date = AppDateUtils.todayYyyyMmDd();
      final json = await ref.read(sectionApiProvider).saveFinalAttendance(
            courseId: courseId,
            sectionId: sectionId,
            date: date,
            presentStudentIds: state.presentSelected.toList(),
          );

      state = state.copyWith(isLoading: false);
      return json;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}