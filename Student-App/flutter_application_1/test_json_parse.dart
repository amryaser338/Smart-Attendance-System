import 'dart:convert';
import 'lib/features/history/domain/history_models.dart';

void main() {
  const jsonStr = '''{"student_id": "S001", "days_count": 9, "present_days": 5, "absent_days": 4, "sections_count": 1, "sections": [{"course_id": "CSE101", "section_id": "SEC1", "days": [{"date": "2026-03-04", "status": "absent", "source": "final"}, {"date": "2026-03-03", "status": "absent", "source": "final"}]}]}''';
  
  try {
    final map = jsonDecode(jsonStr);
    final response = HistoryResponse.fromJson(map);
    print('Success: \${response.sections.length} sections');
  } catch (e, stack) {
    print('Error: \$e');
    print(stack);
  }
}
