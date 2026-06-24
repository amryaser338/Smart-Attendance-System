class AttendanceDay {
  final String date;
  final String status;
  final String source;

  AttendanceDay({
    required this.date,
    required this.status,
    required this.source,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) {
    return AttendanceDay(
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'absent',
      source: json['source'] as String? ?? '',
    );
  }
}

class AttendanceSection {
  final String courseId;
  final String sectionId;
  final List<AttendanceDay> days;

  int get presentCount => days.where((d) => d.status == 'present').length;
  int get absentCount => days.where((d) => d.status == 'absent').length;

  AttendanceSection({
    required this.courseId,
    required this.sectionId,
    required this.days,
  });

  factory AttendanceSection.fromJson(Map<String, dynamic> json) {
    final daysList =
        (json['days'] as List<dynamic>?)
            ?.map((d) => AttendanceDay.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    return AttendanceSection(
      courseId: json['course_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      days: daysList,
    );
  }
}

class HistoryResponse {
  final String studentId;
  final int daysCount;
  final int presentDays;
  final int absentDays;
  final int sectionsCount;
  final List<AttendanceSection> sections;

  HistoryResponse({
    required this.studentId,
    required this.daysCount,
    required this.presentDays,
    required this.absentDays,
    required this.sectionsCount,
    required this.sections,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final sectionsList =
        (json['sections'] as List<dynamic>?)
            ?.map((s) => AttendanceSection.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];
    return HistoryResponse(
      studentId: json['student_id'] as String? ?? '',
      daysCount: json['days_count'] as int? ?? 0,
      presentDays: json['present_days'] as int? ?? 0,
      absentDays: json['absent_days'] as int? ?? 0,
      sectionsCount: json['sections_count'] as int? ?? 0,
      sections: sectionsList,
    );
  }
}
