import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

class SectionApi {
  final Dio _dio = DioClient.dio;

  Future<Map<String, dynamic>> getStudentsForSection({
    required String courseId,
    required String sectionId,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/getStudentsForSection',
      data: {"course_id": courseId, "section_id": sectionId},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getAbsentForMeeting({
    required String courseId,
    required String sectionId,
    required String meetingId,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/getAbsentForMeeting',
      data: {
        "course_id": courseId,
        "section_id": sectionId,
        "meeting_id": meetingId,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getLatestMeetingForSectionToday({
    required String courseId,
    required String sectionId,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/getLatestMeetingForSectionToday',
      data: {"course_id": courseId, "section_id": sectionId},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> generateQr({
    required String courseId,
    required String sectionId,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/generateQr',
      data: {"course_id": courseId, "section_id": sectionId},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getScansForMeeting({
    required String meetingId,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/getScansForMeeting',
      data: {"meeting_id": meetingId},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getFlagsForSession({
    required String sessionId,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/getFlagsForSession',
      data: {"session_id": sessionId},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> markDraftForMeeting({
    required String meetingId,
    required String studentId,
    required String status, // "present" or "absent"
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/markDraftForMeeting',
      data: {"meeting_id": meetingId, "student_id": studentId, "status": status},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getDraftForMeeting({
    required String meetingId,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/getDraftForMeeting',
      data: {"meeting_id": meetingId},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> saveFinalAttendance({
    required String courseId,
    required String sectionId,
    required String date,
    required List<String> presentStudentIds,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.baseUrl}/saveFinalAttendance',
      data: {
        "course_id": courseId,
        "section_id": sectionId,
        "date": date,
        "present_student_ids": presentStudentIds,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }
}