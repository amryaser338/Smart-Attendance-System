class ApiConstants {
  static const String baseUrl =
      'https://vzgz6fos1k.execute-api.il-central-1.amazonaws.com';

  // Routes (match your API Gateway routes)
  static const String getDoctorCoursesSections = '/getDoctorCoursesSections';
  static const String getStudentsForSection = '/getStudentsForSection';
  static const String getLatestMeetingForSectionToday =
      '/getLatestMeetingForSectionToday';
  static const String getAbsentForMeeting = '/getAbsentForMeeting';
  static const String markDraftForMeeting = '/markDraftForMeeting';
  static const String generateQr = '/generateQr';
  static const String getScansForMeeting = '/getScansForMeeting';
  static const String getFlagsForSession = '/getFlagsForSession';
  static const String saveFinalAttendance = '/saveFinalAttendance';
}