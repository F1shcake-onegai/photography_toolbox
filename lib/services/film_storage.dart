import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FilmStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/film_rolls.json');
  }

  static Future<List<Map<String, dynamic>>> loadRolls() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRolls(List<Map<String, dynamic>> rolls) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(rolls));
  }

  static Future<Map<String, dynamic>?> loadRoll(String id) async {
    final rolls = await loadRolls();
    try {
      return rolls.firstWhere((r) => r['id'] == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateRoll(Map<String, dynamic> roll) async {
    final rolls = await loadRolls();
    final idx = rolls.indexWhere((r) => r['id'] == roll['id']);
    if (idx >= 0) {
      rolls[idx] = roll;
    } else {
      rolls.add(roll);
    }
    await saveRolls(rolls);
  }

  static Future<void> deleteRoll(String id) async {
    final rolls = await loadRolls();
    rolls.removeWhere((r) => r['id'] == id);
    await saveRolls(rolls);
  }

  static Future<String> imageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/film_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    return imgDir.path;
  }
}
