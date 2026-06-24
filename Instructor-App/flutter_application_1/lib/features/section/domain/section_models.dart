/// One student entry returned by getLatestMeetingForSectionToday
class MeetingStudentStatus {
  final int no;
  final String studentId;
  final String? name;
  final String status; // "present" or "absent"
  final String source; // "final", "scan+draft", "default_no_meeting", etc.

  MeetingStudentStatus({
    required this.no,
    required this.studentId,
    this.name,
    required this.status,
    required this.source,
  });

  factory MeetingStudentStatus.fromJson(Map<String, dynamic> json) {
    return MeetingStudentStatus(
      no: (json['no'] as num?)?.toInt() ?? 0,
      studentId: '${json['student_id']}',
      name: json['name']?.toString(),
      status: '${json['status']}',
      source: '${json['source'] ?? ''}',
    );
  }
}

/// Full response from POST /getLatestMeetingForSectionToday
class MeetingAttendanceResponse {
  final bool found;
  final String courseId;
  final String sectionId;
  final String date;
  final String mode; // "FINAL", "DRAFT", "DEFAULT"
  final bool hasFinal;
  final String? meetingId;
  final String? sessionId;
  final int presentCount;
  final int absentCount;
  final List<MeetingStudentStatus> students;

  MeetingAttendanceResponse({
    required this.found,
    required this.courseId,
    required this.sectionId,
    required this.date,
    required this.mode,
    required this.hasFinal,
    this.meetingId,
    this.sessionId,
    required this.presentCount,
    required this.absentCount,
    required this.students,
  });

  factory MeetingAttendanceResponse.fromJson(Map<String, dynamic> json) {
    final studentList = (json['students'] as List? ?? [])
        .whereType<Map>()
        .map((e) =>
            MeetingStudentStatus.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return MeetingAttendanceResponse(
      found: json['found'] == true,
      courseId: '${json['course_id']}',
      sectionId: '${json['section_id']}',
      date: '${json['date'] ?? ''}',
      mode: '${json['mode'] ?? 'DEFAULT'}',
      hasFinal: json['has_final'] == true,
      meetingId: json['meeting_id']?.toString(),
      sessionId: json['session_id']?.toString(),
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      absentCount: (json['absent_count'] as num?)?.toInt() ?? 0,
      students: studentList,
    );
  }

  /// Build a [StudentsResponse] from this meeting data so existing code works.
  StudentsResponse toStudentsResponse() {
    return StudentsResponse(
      studentIds: students.map((s) => s.studentId).toList(),
      studentNames: {for (final s in students) s.studentId: s.name ?? s.studentId},
    );
  }

  /// IDs of students who are currently marked present.
  Set<String> get presentStudentIds =>
      students.where((s) => s.status == 'present').map((s) => s.studentId).toSet();
}

class FlagsResponse {
  final String meetingId;
  final String courseId;
  final String sectionId;
  final int expiresAt;
  final int flagsCount;
  final List<FlagItem> flags;

  FlagsResponse({
    required this.meetingId,
    required this.courseId,
    required this.sectionId,
    required this.expiresAt,
    required this.flagsCount,
    required this.flags,
  });

  factory FlagsResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['flags'] as List? ?? [])
        .whereType<Map>()
        .map((e) => FlagItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return FlagsResponse(
      meetingId: '${json['meeting_id']}',
      courseId: '${json['course_id']}',
      sectionId: '${json['section_id']}',
      expiresAt: (json['expires_at'] as num?)?.toInt() ?? 0,
      flagsCount: (json['flags_count'] as num?)?.toInt() ?? items.length,
      flags: items,
    );
  }
}

class FlagItem {
  final String studentId;
  final String flagReason;
  final String message;
  final String? expectedAppId;
  final String? receivedAppId;
  final String timestamp;
  final String sessionId;

  FlagItem({
    required this.studentId,
    required this.flagReason,
    required this.message,
    required this.expectedAppId,
    required this.receivedAppId,
    required this.timestamp,
    required this.sessionId,
  });

  factory FlagItem.fromJson(Map<String, dynamic> json) {
    return FlagItem(
      studentId: '${json['student_id']}',
      flagReason: '${json['flag_reason']}',
      message: '${json['message']}',
      expectedAppId: json['expected_app_id']?.toString(),
      receivedAppId: json['received_app_id']?.toString(),
      timestamp: '${json['timestamp']}',
      sessionId: '${json['session_id']}',
    );
  }
}

class ScansResponse {
  final String meetingId;
  final List<String> scannedStudentIds;
  final int count;

  ScansResponse({
    required this.meetingId,
    required this.scannedStudentIds,
    required this.count,
  });

  factory ScansResponse.fromJson(Map<String, dynamic> json) {
    final ids = (json['scanned_student_ids'] as List? ?? [])
        .map((e) => '$e')
        .toList();
    return ScansResponse(
      meetingId: '${json['meeting_id']}',
      scannedStudentIds: ids,
      count: (json['count'] as num?)?.toInt() ?? ids.length,
    );
  }
}

class GenerateQrResponse {
  final String sessionId;
  final String meetingId;
  final String courseId;
  final String sectionId;
  final int expiresAt;

  GenerateQrResponse({
    required this.sessionId,
    required this.meetingId,
    required this.courseId,
    required this.sectionId,
    required this.expiresAt,
  });

  factory GenerateQrResponse.fromJson(Map<String, dynamic> json) {
    return GenerateQrResponse(
      sessionId: '${json['session_id']}',
      meetingId: '${json['meeting_id']}',
      courseId: '${json['course_id']}',
      sectionId: '${json['section_id']}',
      expiresAt: (json['expires_at'] as num?)?.toInt() ?? 0,
    );
  }
}

/// StudentsForSection response — flexible: accepts plain IDs or {student_id, name} objects.
/// Also built directly from [MeetingAttendanceResponse.toStudentsResponse].
class StudentsResponse {
  final List<String> studentIds;

  /// Optional map of student_id → display name (populated from meeting response)
  final Map<String, String> studentNames;

  StudentsResponse({
    required this.studentIds,
    this.studentNames = const {},
  });

  String displayName(String studentId) =>
      studentNames[studentId] ?? studentId;

  factory StudentsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['students'] ?? json['student_ids'] ?? json['items'];
    final ids = <String>[];
    final names = <String, String>{};

    if (raw is List) {
      for (final x in raw) {
        if (x is String) {
          ids.add(x);
        } else if (x is Map && x['student_id'] != null) {
          final id = '${x['student_id']}';
          ids.add(id);
          if (x['name'] != null) names[id] = '${x['name']}';
        }
      }
    }
    // fallback: if backend returns scanned_student_ids style
    if (ids.isEmpty && json['student_ids'] is List) {
      ids.addAll((json['student_ids'] as List).map((e) => '$e'));
    }

    return StudentsResponse(studentIds: ids, studentNames: names);
  }
}

class AbsentStudent {
  final String studentId;
  final String name;

  AbsentStudent({required this.studentId, required this.name});

  factory AbsentStudent.fromJson(Map<String, dynamic> json) {
    return AbsentStudent(
      studentId: '${json['student_id']}',
      name: '${json['name'] ?? json['student_id']}',
    );
  }
}

class AbsentResponse {
  final String courseId;
  final String sectionId;
  final String meetingId;
  final List<String> meetingsToday;
  final int absentCount;
  final List<AbsentStudent> absentStudents;

  AbsentResponse({
    required this.courseId,
    required this.sectionId,
    required this.meetingId,
    required this.meetingsToday,
    required this.absentCount,
    required this.absentStudents,
  });

  factory AbsentResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['absent_students'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => AbsentStudent.fromJson(e))
        .toList();

    return AbsentResponse(
      courseId: '${json['course_id']}',
      sectionId: '${json['section_id']}',
      meetingId: '${json['meeting_id']}',
      meetingsToday: (json['meetings_today'] as List? ?? [])
          .map((e) => '$e')
          .toList(),
      absentCount: (json['absent_count'] as num?)?.toInt() ?? list.length,
      absentStudents: list,
    );
  }
}