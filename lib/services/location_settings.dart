import 'package:shared_preferences/shared_preferences.dart';

class LocationSettings {
  static const String _key = 'auto_capture_location';
  static const bool defaultValue = true;
  static bool _cached = defaultValue;

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getBool(_key) ?? defaultValue;
    return _cached;
  }

  static bool get value => _cached;

  static Future<void> save(bool value) async {
    _cached = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
