import 'package:intl/intl.dart';

class AppDateUtils {
  static String todayYyyyMmDd() {
    // Cairo time handled server-side, but for finalize we send "yyyy-MM-dd"
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}