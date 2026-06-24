import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class DioClient {
  DioClient._();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final res = await dio.post(path, data: data);
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    throw Exception('Unexpected response type');
  }
}