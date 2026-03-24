import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// File types recognized by the import/export system.
enum ExportFileType { recipe, roll }

/// Result of parsing an import file.
class ImportParseResult {
  final ExportFileType type;
  final Map<String, dynamic> data;

  /// For rolls: extracted image files mapped as originalName → tempPath.
  final Map<String, String> images;

  /// Image files that are below the minimum 100x100 size.
  /// Maps file name → "{width}x{height}".
  final Map<String, String> smallImages;

  const ImportParseResult({
    required this.type,
    required this.data,
    this.images = const {},
    this.smallImages = const {},
  });
}

/// Shared import/export service with file validation.
class ImportExportService {
  static const recipeExtension = '.ptrecipe';
  static const rollExtension = '.ptroll';
  static const minImageDimension = 100;

  // ───── Export ─────

  /// Export a recipe to a .ptrecipe file. Returns the file path.
  static Future<String> exportRecipe(Map<String, dynamic> recipe) async {
    final dir = await getApplicationDocumentsDirectory();
    final filmStock = recipe['filmStock'] as String? ?? 'recipe';
    final safeName = filmStock
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final file = File('${dir.path}/$safeName$recipeExtension');

    final exportData = Map<String, dynamic>.from(recipe);
    exportData['_type'] = 'recipe';
    // Keep uuid for duplicate detection on import

    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData));
    return file.path;
  }

  /// Export a roll to a .ptroll file (ZIP). Returns the file path.
  /// If [selectedShotUuids] is provided, only include those shots and their images.
  static Future<String> exportRoll(
    Map<String, dynamic> roll, {
    List<String>? selectedShotUuids,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final brand = roll['brand'] as String? ?? '';
    final model = roll['model'] as String? ?? 'roll';
    final safeName = '$brand $model'
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    // Prepare roll data
    final exportRoll = Map<String, dynamic>.from(roll);
    exportRoll['_type'] = 'roll';

    // Filter shots if selection provided
    var shots = (exportRoll['shots'] as List)
        .cast<Map<String, dynamic>>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    if (selectedShotUuids != null) {
      shots = shots.where((s) => selectedShotUuids.contains(s['uuid'])).toList();
    }

    // Build archive
    final archive = Archive();
    final imageFiles = <String, File>{};

    // Collect images and rewrite paths to relative
    for (final shot in shots) {
      final imagePath = shot['imagePath'] as String?;
      if (imagePath != null && imagePath.isNotEmpty) {
        final imageFile = File(imagePath);
        if (imageFile.existsSync()) {
          final fileName = imageFile.uri.pathSegments.last;
          imageFiles[fileName] = imageFile;
          shot['imagePath'] = 'images/$fileName';
        } else {
          shot['imagePath'] = '';
        }
      }
    }

    exportRoll['shots'] = shots;

    // Add roll.json to archive
    final rollJson = const JsonEncoder.withIndent('  ').convert(exportRoll);
    final rollJsonBytes = utf8.encode(rollJson);
    archive.addFile(ArchiveFile('roll.json', rollJsonBytes.length, rollJsonBytes));

    // Add images to archive
    for (final entry in imageFiles.entries) {
      final bytes = entry.value.readAsBytesSync();
      archive.addFile(
          ArchiveFile('images/${entry.key}', bytes.length, bytes));
    }

    // Write ZIP
    final zipPath = '${dir.path}/$safeName$rollExtension';
    final zipBytes = ZipEncoder().encode(archive);
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }

  // ───── Import ─────

  /// Parse and validate an import file. Returns [ImportParseResult] on success.
  /// Throws [FormatException] with a user-facing message on failure.
  static Future<ImportParseResult> parseImportFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw const FormatException('File not found.');
    }

    final ext = _extension(filePath);

    if (ext == recipeExtension) {
      return _parseRecipeFile(file);
    } else if (ext == rollExtension) {
      return _parseRollFile(file);
    } else {
      // Try to detect type from content
      return _parseUnknownFile(file);
    }
  }

  static String _extension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith(rollExtension)) return rollExtension;
    if (lower.endsWith(recipeExtension)) return recipeExtension;
    if (lower.endsWith('.json')) return '.json';
    if (lower.endsWith('.zip')) return '.zip';
    return '';
  }

  static Future<ImportParseResult> _parseRecipeFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return _validateRecipeData(data);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Could not read file: $e');
    }
  }

  static Future<ImportParseResult> _parseRollFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find roll.json
      final rollEntry = archive.files.where((f) => f.name == 'roll.json').firstOrNull;
      if (rollEntry == null) {
        throw const FormatException(
            'Invalid roll file: missing roll.json inside archive.');
      }

      final rollJson = utf8.decode(rollEntry.content as List<int>);
      final data = jsonDecode(rollJson) as Map<String, dynamic>;

      if (data['_type'] != null && data['_type'] != 'roll') {
        throw FormatException(
            'Invalid file: expected a roll export but found type "${data["_type"]}".');
      }

      // Validate required fields
      if (data['brand'] == null && data['model'] == null) {
        throw const FormatException(
            'Invalid roll: missing brand and model.');
      }
      if (data['shots'] == null) {
        throw const FormatException('Invalid roll: missing shots data.');
      }

      // Extract images to temp directory
      final tempDir = await getApplicationDocumentsDirectory();
      final importTempDir =
          Directory('${tempDir.path}/import_temp_${DateTime.now().millisecondsSinceEpoch}');
      await importTempDir.create(recursive: true);

      final images = <String, String>{};
      final smallImages = <String, String>{};
      for (final entry in archive.files) {
        if (entry.name.startsWith('images/') && entry.isFile) {
          final fileName = entry.name.replaceFirst('images/', '');
          final content = entry.content as List<int>;
          final outFile = File('${importTempDir.path}/$fileName');
          await outFile.writeAsBytes(content);
          images[entry.name] = outFile.path;

          // Check image dimensions
          final dims = parseImageDimensions(Uint8List.fromList(content));
          if (dims != null) {
            final (w, h) = dims;
            if (w < minImageDimension || h < minImageDimension) {
              smallImages[fileName] = '${w}x$h';
            }
          }
        }
      }

      return ImportParseResult(
        type: ExportFileType.roll,
        data: data,
        images: images,
        smallImages: smallImages,
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Could not read archive: $e');
    }
  }

  /// Try to detect file type from content when extension is unrecognized.
  static Future<ImportParseResult> _parseUnknownFile(File file) async {
    // Try JSON first
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (data['_type'] == 'recipe') {
        return _validateRecipeData(data);
      }
      if (data['_type'] == 'roll') {
        throw const FormatException(
            'This appears to be a roll export (.ptroll) but was not in ZIP format.');
      }
      // Legacy recipe (no _type field) — check for recipe-like fields
      if (data['filmStock'] != null && data['steps'] != null) {
        return _validateRecipeData(data);
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      // Not JSON — try ZIP
    }

    // Try ZIP
    try {
      return await _parseRollFile(file);
    } catch (_) {
      // Neither JSON nor valid ZIP
    }

    throw const FormatException(
        'Not a recognized Photography Toolbox export file.');
  }

  static ImportParseResult _validateRecipeData(Map<String, dynamic> data) {
    if (data['_type'] != null && data['_type'] != 'recipe') {
      throw FormatException(
          'Invalid file: expected a recipe but found type "${data["_type"]}".');
    }

    if (data['filmStock'] == null) {
      throw const FormatException(
          'Invalid recipe: missing film stock name.');
    }
    if (data['steps'] == null) {
      throw const FormatException('Invalid recipe: missing steps.');
    }

    return ImportParseResult(type: ExportFileType.recipe, data: data);
  }

  /// Clean up temp files created during import.
  static Future<void> cleanupTempImages(Map<String, String> images) async {
    if (images.isEmpty) return;
    // All temp images are in the same directory
    final firstPath = images.values.first;
    final tempDir = File(firstPath).parent;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }

  /// Summary info for the preview confirmation dialog.
  static Map<String, String> previewSummary(ImportParseResult result) {
    final data = result.data;
    switch (result.type) {
      case ExportFileType.recipe:
        final filmStock = data['filmStock'] as String? ?? '—';
        final developer = data['developer'] as String? ?? '—';
        final steps = (data['steps'] as List?)?.length ?? 0;
        return {
          'filmStock': filmStock,
          'developer': developer,
          'steps': steps.toString(),
        };
      case ExportFileType.roll:
        final brand = data['brand'] as String? ?? '';
        final model = data['model'] as String? ?? '';
        final shots = (data['shots'] as List?)?.length ?? 0;
        final imageCount = result.images.length;
        return {
          'film': '$brand $model'.trim(),
          'shots': shots.toString(),
          'images': imageCount.toString(),
        };
    }
  }

  // ───── Platform-aware Share ─────

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS);

  /// Share an exported file. On desktop, opens a "Save As" dialog.
  /// On mobile, opens the native share sheet.
  static Future<void> shareFile(String exportedPath, String displayName) async {
    if (_isDesktop) {
      final ext = exportedPath.contains(rollExtension) ? 'ptroll' : 'ptrecipe';
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: displayName,
        fileName: '$displayName.$ext',
      );
      if (savePath != null) {
        await File(exportedPath).copy(savePath);
      }
    } else {
      await Share.shareXFiles([XFile(exportedPath)], text: displayName);
    }
  }

  // ───── Image Dimension Parsing ─────

  /// Parse image dimensions from raw bytes without full decoding.
  /// Supports JPEG and PNG. Returns (width, height) or null if unrecognized.
  static (int, int)? parseImageDimensions(Uint8List bytes) {
    if (bytes.length < 8) return null;
    // PNG: 8-byte signature then IHDR with width/height
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return _parsePngDimensions(bytes);
    }
    // JPEG: starts with 0xFF 0xD8
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return _parseJpegDimensions(bytes);
    }
    return null;
  }

  static (int, int)? _parsePngDimensions(Uint8List bytes) {
    // PNG IHDR starts at byte 8: 4-byte length, 4-byte "IHDR", 4-byte width, 4-byte height
    if (bytes.length < 24) return null;
    final bd = ByteData.sublistView(bytes);
    final width = bd.getUint32(16, Endian.big);
    final height = bd.getUint32(20, Endian.big);
    return (width, height);
  }

  static (int, int)? _parseJpegDimensions(Uint8List bytes) {
    // Scan for SOF0 (0xFFC0) or SOF2 (0xFFC2) marker
    int i = 2;
    while (i < bytes.length - 9) {
      if (bytes[i] != 0xFF) { i++; continue; }
      final marker = bytes[i + 1];
      // SOF markers: C0, C1, C2, C3 (baseline, extended, progressive, lossless)
      if (marker >= 0xC0 && marker <= 0xC3) {
        final bd = ByteData.sublistView(bytes);
        final height = bd.getUint16(i + 5, Endian.big);
        final width = bd.getUint16(i + 7, Endian.big);
        return (width, height);
      }
      // Skip this marker segment
      if (marker == 0xD9 || marker == 0xDA) break; // EOI or SOS — stop
      if (i + 3 >= bytes.length) break;
      final segLen = ByteData.sublistView(bytes).getUint16(i + 2, Endian.big);
      i += 2 + segLen;
    }
    return null;
  }
}
