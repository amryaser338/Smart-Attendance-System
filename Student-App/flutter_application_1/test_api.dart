import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://evsz0yar55.execute-api.il-central-1.amazonaws.com/studentAttendanceHistory');
  final body = jsonEncode({'student_id': 'S001'});
  print('Sending: $body');
  
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
