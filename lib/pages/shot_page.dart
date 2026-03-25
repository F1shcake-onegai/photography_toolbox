import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/film_storage.dart';
import '../services/import_export_service.dart';
import 'package:uuid/uuid.dart';
import '../services/app_localizations.dart';
import 'image_viewer_page.dart';

class ShotPage extends StatefulWidget {
  final int defaultSequence;
  final Map<String, dynamic>? existingShot;

  const ShotPage({
    super.key,
    required this.defaultSequence,
    this.existingShot,
  });

  @override
  State<ShotPage> createState() => _ShotPageState();
}

class _ShotPageState extends State<ShotPage> {
  late TextEditingController _seqCtrl;
  late TextEditingController _commentCtrl;
  String? _imagePath;
  String? _resolvedPath;
  final _picker = ImagePicker();

  bool get _isEditing => widget.existingShot != null;

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _seqCtrl = TextEditingController(
        text: widget.defaultSequence.toString());
    _commentCtrl = TextEditingController(
        text: widget.existingShot?['comment'] as String? ?? '');
    _imagePath =
        widget.existingShot?['imagePath'] as String?;
    _resolveImage();
  }

  Future<void> _resolveImage() async {
    if (_imagePath == null || _imagePath!.isEmpty) {
      setState(() => _resolvedPath = null);
      return;
    }
    final resolved = await FilmStorage.resolveImagePath(_imagePath!);
    if (mounted) setState(() => _resolvedPath = resolved);
  }

  @override
  void dispose() {
    _seqCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
          source: source, imageQuality: 85);
      if (xfile == null) return;

      // Check image dimensions (minimum 100x100)
      final bytes = await File(xfile.path).readAsBytes();
      final dims = ImportExportService.parseImageDimensions(Uint8List.fromList(bytes));
      if (dims != null) {
        final (w, h) = dims;
        if (w < ImportExportService.minImageDimension ||
            h < ImportExportService.minImageDimension) {
          if (mounted) {
            final l = AppLocalizations.of(context);
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.t('shot_image_too_small_title')),
                content: Text(l.t('shot_image_too_small_message',
                    {'size': '${w}x$h'})),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      final imgDir = await FilmStorage.imageDir();
      final shotUuid = widget.existingShot?['uuid'] ?? const Uuid().v4();
      // Delete old image if replacing
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        final oldPath = await FilmStorage.resolveImagePath(_imagePath!);
        final oldFile = File(oldPath);
        if (oldFile.existsSync()) await oldFile.delete();
      }
      final fileName = '$shotUuid.jpg';
      await File(xfile.path).copy('$imgDir/$fileName');
      _imagePath = fileName;
      _resolvedPath = '$imgDir/$fileName';
      setState(() {});
    } catch (e) {
      debugPrint('image_picker error: $e');
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera
                ? l.t('shot_camera_unavailable')
                : l.t('shot_gallery_unavailable')),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() => _pickImage(ImageSource.camera);

  Future<void> _pickFromGallery() => _pickImage(ImageSource.gallery);

  void _viewImage(BuildContext context) {
    if (_resolvedPath == null) return;
    final seq = int.tryParse(_seqCtrl.text) ?? widget.defaultSequence;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          imagePath: _resolvedPath!,
          rollName: '',
          sequence: seq,
        ),
      ),
    );
  }

  void _save() {
    final seq = int.tryParse(_seqCtrl.text) ??
        widget.defaultSequence;
    final shot = <String, dynamic>{
      'uuid': widget.existingShot?['uuid'] ?? const Uuid().v4(),
      'sequence': seq,
      'imagePath': _imagePath ?? '',
      'comment': _commentCtrl.text,
      'createdAt': widget.existingShot?['createdAt'] ??
          DateTime.now().millisecondsSinceEpoch,
    };
    Navigator.pop(context, shot);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final hasImage = _resolvedPath != null &&
        _resolvedPath!.isNotEmpty &&
        File(_resolvedPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? l.t('shot_edit_title') : l.t('shot_new_title')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sequence number
            Text(l.t('shot_sequence'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _seqCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            // Photo section
            Text(l.t('shot_photo'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: hasImage ? () => _viewImage(context) : null,
              child: Container(
                height: 240,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.outlineVariant),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(12),
                        child: Image.file(
                          File(_resolvedPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Center(
                        child: Icon(
                            Icons.photo_outlined,
                            size: 64,
                            color: colorScheme
                                .onSurfaceVariant),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isMobilePlatform) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(hasImage
                          ? l.t('shot_retake')
                          : l.t('shot_camera')),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: Text(hasImage
                        ? l.t('shot_replace')
                        : l.t('shot_gallery')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Comment section
            Text(l.t('shot_comment'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.t('shot_comment_hint'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(l.t('shot_save')),
            ),
          ],
        ),
      ),
    );
  }
}
