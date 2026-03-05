import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/film_storage.dart';

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
  final _picker = ImagePicker();

  bool get _isEditing => widget.existingShot != null;

  @override
  void initState() {
    super.initState();
    _seqCtrl = TextEditingController(
        text: widget.defaultSequence.toString());
    _commentCtrl = TextEditingController(
        text: widget.existingShot?['comment'] as String? ?? '');
    _imagePath =
        widget.existingShot?['imagePath'] as String?;
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
      final imgDir = await FilmStorage.imageDir();
      final saved = await File(xfile.path).copy(
          '$imgDir/${DateTime.now().millisecondsSinceEpoch}.jpg');
      setState(() => _imagePath = saved.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera
                ? 'Camera is not available on this platform.'
                : 'Gallery is not available on this platform.'),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() => _pickImage(ImageSource.camera);

  Future<void> _pickFromGallery() => _pickImage(ImageSource.gallery);

  void _save() {
    final seq = int.tryParse(_seqCtrl.text) ??
        widget.defaultSequence;
    final shot = <String, dynamic>{
      'sequence': seq,
      'imagePath': _imagePath ?? '',
      'comment': _commentCtrl.text,
    };
    Navigator.pop(context, shot);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = _imagePath != null &&
        _imagePath!.isNotEmpty &&
        File(_imagePath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Edit Shot' : 'New Shot'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sequence number
            Text('Sequence Number',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _seqCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            // Photo section
            Text('Photo',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
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
                        File(_imagePath!),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(hasImage
                        ? 'Retake'
                        : 'Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: Text(hasImage
                        ? 'Replace'
                        : 'Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Comment section
            Text('Comment',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add a note about this shot...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
