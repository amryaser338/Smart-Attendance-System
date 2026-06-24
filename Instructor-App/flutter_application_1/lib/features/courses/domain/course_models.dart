class CourseItem {
  final String courseId;
  final String courseName;
  final List<String> sections;

  CourseItem({
    required this.courseId,
    required this.courseName,
    required this.sections,
  });

  factory CourseItem.fromJson(Map<String, dynamic> json) {
    final secs = (json['sections'] as List? ?? []).map((e) => '$e').toList();
    return CourseItem(
      courseId: '${json['course_id']}',
      courseName: '${json['course_name']}',
      sections: secs,
    );
  }
}

class DoctorCoursesResponse {
  final String doctorId;
  final String today;
  final int count;
  final List<CourseItem> courses;

  DoctorCoursesResponse({
    required this.doctorId,
    required this.today,
    required this.count,
    required this.courses,
  });

  factory DoctorCoursesResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['courses'] as List? ?? [])
        .whereType<Map>()
        .map((e) => CourseItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return DoctorCoursesResponse(
      doctorId: '${json['doctor_id']}',
      today: '${json['today']}',
      count: (json['count'] as num?)?.toInt() ?? list.length,
      courses: list,
    );
  }
}