import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../domain/history_models.dart';

class HistoryApi {
  /// POST /studentAttendanceHistory
  static Future<HistoryResponse> fetchHistory(String studentId) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.studentAttendanceHistory}',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'student_id': studentId}),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Request timed out. Check your connection.'),
        );

    if (response.statusCode != 200) {
      throw Exception('Failed to load history: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return HistoryResponse.fromJson(body);
  }
}
