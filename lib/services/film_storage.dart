import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'import_export_service.dart';
import 'import_settings.dart';

const _uuid = Uuid();

class FilmStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/film_rolls.json');
  }

  /// Generate a new UUID.
  static String newUuid() => _uuid.v4();

  static Future<List<Map<String, dynamic>>> loadRolls() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      final rolls = list.cast<Map<String, dynamic>>();
      bool changed = _migrateUuids(rolls);
      changed = _migrateImagePaths(rolls) || changed;
      if (changed) {
        await _file().then((f) => f.writeAsString(jsonEncode(rolls)));
      }
      return rolls;
    } catch (_) {
      return [];
    }
  }

  /// Backfill UUIDs for rolls and shots that have timestamp-based IDs.
  static bool _migrateUuids(List<Map<String, dynamic>> rolls) {
    bool changed = false;
    for (final roll in rolls) {
      final oldId = roll['id'] as String?;
      if (_isTimestampId(oldId)) {
        // Preserve the creation date from the old timestamp ID
        if (roll['createdAt'] == null && oldId != null) {
          final ms = int.tryParse(oldId);
          if (ms != null) roll['createdAt'] = ms;
        }
        roll['id'] = _uuid.v4();
        changed = true;
      }
      final shots = roll['shots'] as List?;
      if (shots != null) {
        for (final shot in shots.cast<Map<String, dynamic>>()) {
          if (shot['uuid'] == null) {
            shot['uuid'] = _uuid.v4();
            changed = true;
          }
        }
      }
    }
    return changed;
  }

  /// Strip absolute image paths to just filenames.
  static bool _migrateImagePaths(List<Map<String, dynamic>> rolls) {
    bool changed = false;
    for (final roll in rolls) {
      final shots = roll['shots'] as List?;
      if (shots == null) continue;
      for (final shot in shots.cast<Map<String, dynamic>>()) {
        final path = shot['imagePath'] as String? ?? '';
        if (path.isNotEmpty && (path.contains('/') || path.contains('\\'))) {
          shot['imagePath'] = Uri.file(path).pathSegments.last;
          changed = true;
        }
      }
    }
    return changed;
  }

  /// Returns true if the ID looks like a millisecond timestamp (all digits).
  static bool _isTimestampId(String? id) {
    if (id == null || id.isEmpty) return true;
    return RegExp(r'^\d+$').hasMatch(id);
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

  /// Resolve a stored image filename to its full absolute path.
  static Future<String> resolveImagePath(String stored) async {
    if (stored.isEmpty) return '';
    // Already absolute (legacy) — return as-is
    if (stored.contains('/') || stored.contains('\\')) return stored;
    final dir = await imageDir();
    return '$dir/$stored';
  }

  /// Export a roll to a .ptroll file. Returns the file path.
  static Future<String> exportRoll(
    Map<String, dynamic> roll, {
    List<String>? selectedShotUuids,
  }) {
    return ImportExportService.exportRoll(roll,
        selectedShotUuids: selectedShotUuids);
  }

  /// Find an existing roll by UUID.
  static Future<Map<String, dynamic>?> findByUuid(String uuid) async {
    final rolls = await loadRolls();
    for (final r in rolls) {
      if (r['id'] == uuid) return r;
    }
    return null;
  }

  /// Import a roll from parsed data.
  /// [images] maps archive paths to temp file paths.
  /// [smallImages] lists images that are below minimum size (to skip).
  /// Returns 'imported', 'replaced', 'skipped', or 'duplicated'.
  static Future<String> importRollData(
    Map<String, dynamic> data,
    DuplicateAction action,
    Map<String, String> images,
    Map<String, String> smallImages,
  ) async {
    data.remove('_type');
    final imgDirPath = await imageDir();

    // Copy valid images to app storage, rewrite shot paths
    final shots = (data['shots'] as List?) ?? [];
    for (final shot in shots.cast<Map<String, dynamic>>()) {
      final archivePath = shot['imagePath'] as String? ?? '';
      if (archivePath.isEmpty) continue;

      final fileName = archivePath.replaceFirst('images/', '');
      if (smallImages.containsKey(fileName)) {
        // Skip undersized images
        shot['imagePath'] = '';
        continue;
      }

      final tempPath = images[archivePath];
      if (tempPath != null && File(tempPath).existsSync()) {
        final shotUuid = shot['uuid'] as String? ?? _uuid.v4();
        shot['uuid'] ??= shotUuid;
        final destName = '$shotUuid.jpg';
        await File(tempPath).copy('$imgDirPath/$destName');
        shot['imagePath'] = destName;
      } else {
        shot['imagePath'] = '';
      }
    }

    final uuid = data['id'] as String?;

    // Check for existing roll with same UUID
    if (uuid != null) {
      final existing = await findByUuid(uuid);
      if (existing != null) {
        switch (action) {
          case DuplicateAction.replace:
            await updateRoll(data);
            return 'replaced';
          case DuplicateAction.skip:
            return 'skipped';
          case DuplicateAction.duplicate:
            data['id'] = _uuid.v4();
            await updateRoll(data);
            return 'duplicated';
          case DuplicateAction.ask:
            return 'skipped';
        }
      }
    }

    // No duplicate — assign UUID if missing and import
    data['id'] ??= _uuid.v4();
    await updateRoll(data);
    return 'imported';
  }
}
