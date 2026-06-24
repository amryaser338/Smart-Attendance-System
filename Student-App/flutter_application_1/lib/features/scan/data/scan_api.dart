import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

class ScanApi {
  /// POST /scanQr
  /// Returns a map with 'success' (bool) and 'message' (String).
  static Future<Map<String, dynamic>> scanQr({
    required String sessionId,
    required String studentId,
    required String appId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.scanQr}');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'session_id': sessionId,
            'student_id': studentId,
            'app_id': appId,
          }),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Request timed out. Check your connection.'),
        );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final message = body['message'] as String? ?? 'Unknown response';

    if (response.statusCode == 200) {
      return {'success': true, 'message': message};
    } else {
      return {'success': false, 'message': message};
    }
  }
}
