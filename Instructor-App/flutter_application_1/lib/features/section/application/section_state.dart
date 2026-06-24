import '../domain/section_models.dart';

class SectionState {
  final bool isLoading;
  final String? error;

  final StudentsResponse? students;
  final MeetingAttendanceResponse? meetingState; // history from getLatestMeetingForSectionToday
  final GenerateQrResponse? qr;
  final ScansResponse? scans;
  final FlagsResponse? flags;
  final AbsentResponse? absentState;

  final Set<String> presentSelected; // manual attendance selection
  final bool autoRefresh;
  final int serverClockOffset;

  const SectionState({
    this.isLoading = false,
    this.error,
    this.students,
    this.meetingState,
    this.qr,
    this.scans,
    this.flags,
    this.absentState,
    this.presentSelected = const {},
    this.autoRefresh = true,
    this.serverClockOffset = 0,
  });

  SectionState copyWith({
    bool? isLoading,
    String? error,
    StudentsResponse? students,
    MeetingAttendanceResponse? meetingState,
    GenerateQrResponse? qr,
    ScansResponse? scans,
    FlagsResponse? flags,
    AbsentResponse? absentState,
    Set<String>? presentSelected,
    bool? autoRefresh,
    int? serverClockOffset,
  }) {
    return SectionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      students: students ?? this.students,
      meetingState: meetingState ?? this.meetingState,
      qr: qr ?? this.qr,
      scans: scans ?? this.scans,
      flags: flags ?? this.flags,
      absentState: absentState ?? this.absentState,
      presentSelected: presentSelected ?? this.presentSelected,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      serverClockOffset: serverClockOffset ?? this.serverClockOffset,
    );
  }
}