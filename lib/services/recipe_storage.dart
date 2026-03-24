import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'import_export_service.dart';
import 'import_settings.dart';

const _uuid = Uuid();

class RecipeStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recipes.json');
  }

  /// Generate a new UUID.
  static String newUuid() => _uuid.v4();

  static Future<List<Map<String, dynamic>>> loadRecipes() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        // Seed with built-in recipes on first launch
        final seed = _builtInRecipes();
        await file.writeAsString(jsonEncode(seed));
        return seed;
      }
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      final recipes = list.cast<Map<String, dynamic>>();
      if (_migrateUuids(recipes)) {
        await _file().then((f) => f.writeAsString(jsonEncode(recipes)));
      }
      return recipes;
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _builtInRecipes() {
    return [
      {
        'id': _uuid.v4(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'filmStock': 'C-41',
        'developer': 'C-41',
        'dilution': '',
        'processType': 'color_neg',
        'notes': 'Follow standard temperature and procedures.',
        'baseTemp': null,
        'redSafelight': false,
        'steps': [
          {
            'type': 'develop',
            'label': '',
            'time': 195,
            'agitation': {'method': 'rolling', 'speed': 60},
          },
          {'type': 'stop', 'time': 30},
          {'type': 'fix', 'time': 390},
          {'type': 'wash', 'time': 180, 'speedWash': false},
          {'type': 'rinse', 'time': 60},
        ],
      },
      {
        'id': _uuid.v4(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'filmStock': 'E-6',
        'developer': 'E-6',
        'dilution': '',
        'processType': 'color_pos',
        'notes': 'Follow standard temperature and procedures.',
        'baseTemp': null,
        'redSafelight': false,
        'steps': [
          {
            'type': 'develop',
            'label': '',
            'time': 360,
            'agitation': {'method': 'rolling', 'speed': 60},
          },
          {'type': 'wash', 'time': 120, 'speedWash': false},
          {
            'type': 'custom',
            'label': 'Color Developer',
            'time': 360,
            'agitation': {'method': 'rolling', 'speed': 60},
          },
          {'type': 'fix', 'time': 360},
          {'type': 'wash', 'time': 240, 'speedWash': false},
          {'type': 'rinse', 'time': 60},
        ],
      },
    ];
  }

  /// Backfill UUIDs for recipes that have timestamp-based IDs.
  static bool _migrateUuids(List<Map<String, dynamic>> recipes) {
    bool changed = false;
    for (final recipe in recipes) {
      if (_isTimestampId(recipe['id'] as String?)) {
        recipe['id'] = _uuid.v4();
        changed = true;
      }
    }
    return changed;
  }

  static bool _isTimestampId(String? id) {
    if (id == null || id.isEmpty) return true;
    return RegExp(r'^\d+$').hasMatch(id);
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

  /// Export a single recipe to a .ptrecipe file. Returns the file path.
  /// Uses ImportExportService for the standard format.
  static Future<String> exportRecipe(Map<String, dynamic> recipe) async {
    return ImportExportService.exportRecipe(recipe);
  }

  /// Find an existing recipe by UUID. Returns null if not found.
  static Future<Map<String, dynamic>?> findByUuid(String uuid) async {
    final recipes = await loadRecipes();
    for (final r in recipes) {
      if (r['id'] == uuid) return r;
    }
    return null;
  }

  /// Import a recipe from parsed data.
  /// [action] determines how to handle duplicates.
  /// Returns a description of what happened: 'imported', 'replaced', 'skipped', 'duplicated'.
  static Future<String> importRecipeData(
    Map<String, dynamic> data,
    DuplicateAction action,
  ) async {
    data['baseTemp'] ??= 20.0;
    data.remove('_type'); // strip export metadata

    final uuid = data['id'] as String?;

    // Check for existing item with same UUID
    if (uuid != null) {
      final existing = await findByUuid(uuid);
      if (existing != null) {
        switch (action) {
          case DuplicateAction.replace:
            await updateRecipe(data);
            return 'replaced';
          case DuplicateAction.skip:
            return 'skipped';
          case DuplicateAction.duplicate:
            data['id'] = _uuid.v4();
            await updateRecipe(data);
            return 'duplicated';
          case DuplicateAction.ask:
            // Should not reach here — caller handles 'ask' before calling
            return 'skipped';
        }
      }
    }

    // No duplicate — assign UUID if missing and import
    data['id'] ??= _uuid.v4();
    await updateRecipe(data);
    return 'imported';
  }
}
