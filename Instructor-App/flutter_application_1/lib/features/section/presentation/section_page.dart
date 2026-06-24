import 'package:flutter/material.dart';
import 'section_dashboard_page.dart';

class SectionPage extends StatelessWidget {
  final String courseId;
  final String courseName;
  final String sectionId;

  const SectionPage({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.sectionId,
  });

  @override
  Widget build(BuildContext context) {
    return SectionDashboardPage(
      courseId: courseId,
      courseName: courseName,
      sectionId: sectionId,
    );
  }
}