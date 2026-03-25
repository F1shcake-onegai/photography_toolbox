import 'package:shared_preferences/shared_preferences.dart';

class DeveloperSettings {
  static const _verboseKey = 'verbose_errors';

  static bool _verbose = false;

  static bool get verbose => _verbose;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _verbose = prefs.getBool(_verboseKey) ?? false;
  }

  static Future<void> setVerbose(bool value) async {
    _verbose = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_verboseKey, value);
  }
}
