import 'package:shared_preferences/shared_preferences.dart';

class LocaleSettings {
  static const String _key = 'app_locale';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String? localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (localeCode == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, localeCode);
    }
  }
}
