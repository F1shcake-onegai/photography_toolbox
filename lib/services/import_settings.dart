import 'package:shared_preferences/shared_preferences.dart';

/// How to handle duplicate items (matching UUID) on import.
enum DuplicateAction { ask, replace, skip, duplicate }

class ImportSettings {
  static const _key = 'import_duplicate_action';
  static const defaultAction = DuplicateAction.ask;

  static Future<DuplicateAction> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return DuplicateAction.values.firstWhere(
      (a) => a.name == value,
      orElse: () => defaultAction,
    );
  }

  static Future<void> save(DuplicateAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, action.name);
  }

  static String label(DuplicateAction action) {
    switch (action) {
      case DuplicateAction.ask:
        return 'Ask every time';
      case DuplicateAction.replace:
        return 'Replace existing';
      case DuplicateAction.skip:
        return 'Skip';
      case DuplicateAction.duplicate:
        return 'Import as copy';
    }
  }
}
