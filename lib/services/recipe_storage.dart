import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RecipeStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recipes.json');
  }

  static Future<List<Map<String, dynamic>>> loadRecipes() async {
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

  static Future<void> saveRecipes(List<Map<String, dynamic>> recipes) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(recipes));
  }

  static Future<Map<String, dynamic>?> loadRecipe(String id) async {
    final recipes = await loadRecipes();
    try {
      return recipes.firstWhere((r) => r['id'] == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateRecipe(Map<String, dynamic> recipe) async {
    final recipes = await loadRecipes();
    final idx = recipes.indexWhere((r) => r['id'] == recipe['id']);
    if (idx >= 0) {
      recipes[idx] = recipe;
    } else {
      recipes.add(recipe);
    }
    await saveRecipes(recipes);
  }

  static Future<void> deleteRecipe(String id) async {
    final recipes = await loadRecipes();
    recipes.removeWhere((r) => r['id'] == id);
    await saveRecipes(recipes);
  }

  /// Export a single recipe to a temp JSON file. Returns the file path.
  static Future<String> exportRecipe(Map<String, dynamic> recipe) async {
    final dir = await getApplicationDocumentsDirectory();
    final filmStock = recipe['filmStock'] as String? ?? 'recipe';
    final name = filmStock
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final file = File('${dir.path}/$name.json');
    final exportData = Map<String, dynamic>.from(recipe);
    exportData.remove('id');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData));
    return file.path;
  }

  /// Import a recipe from a JSON file path. Returns the imported recipe map.
  static Future<Map<String, dynamic>> importRecipe(String filePath) async {
    final file = File(filePath);
    final json = await file.readAsString();
    final data = jsonDecode(json) as Map<String, dynamic>;

    // Validate required fields
    if (data['filmStock'] == null || data['steps'] == null) {
      throw const FormatException('Invalid recipe: missing filmStock or steps');
    }

    // Assign new ID
    data['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    data['baseTemp'] ??= 20.0;

    // Save
    await updateRecipe(data);
    return data;
  }
}
