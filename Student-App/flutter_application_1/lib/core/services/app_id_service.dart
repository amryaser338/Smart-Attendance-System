import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates a unique app_id on first launch and persists it.
/// This is the device-binding identifier sent with every QR scan.
class AppIdService {
  static const String _key = 'app_id';

  static String? _cached;

  /// Returns the persistent app_id (generates one if not yet set).
  static Future<String> getAppId() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString(_key);

    if (stored == null) {
      stored = const Uuid().v4();
      await prefs.setString(_key, stored);
    }

    _cached = stored;
    return _cached!;
  }
}
