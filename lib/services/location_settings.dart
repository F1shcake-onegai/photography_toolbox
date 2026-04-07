import 'package:shared_preferences/shared_preferences.dart';

class LocationSettings {
  static const String _key = 'auto_capture_location';
  static const bool defaultValue = true;

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? defaultValue;
  }

  static Future<void> save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
