import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

class CoursesApi {
  Future<Map<String, dynamic>> getDoctorCoursesSections({
    required String doctorId,
  }) {
    return DioClient.post(
      ApiConstants.getDoctorCoursesSections,
      data: {"doctor_id": doctorId},
    );
  }
}