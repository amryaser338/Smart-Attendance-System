import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthService {
  static const _keyEmail = 'auth_email';
  static const _keyPassword = 'auth_password';

  static Future<({String email, String password})?>
  getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    final password = prefs.getString(_keyPassword);
    if (email != null && password != null) {
      return (email: email, password: password);
    }
    return null;
  }

  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, password);
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
  }

  // ^[a-zA-Z]+[0-9]{7}@miuegypt\.edu\.eg$
  static bool isValidMiuEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z]+[0-9]{7}@miuegypt\.edu\.eg$');
    return regex.hasMatch(email);
  }

  /// Extracts the student ID from an MIU email.
  /// Format: [name][2-digit-year][id]@miuegypt.edu.eg
  /// Returns the digits after the 2-digit year prefix.
  /// e.g. ziad2112008@miuegypt.edu.eg → "12008"
  static String extractStudentId(String email) {
    final localPart = email.split('@').first;
    final digits = localPart.replaceFirst(RegExp(r'^[a-zA-Z]+'), '');
    return digits.substring(2);
  }
}
