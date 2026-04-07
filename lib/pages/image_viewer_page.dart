import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../services/app_localizations.dart';
import '../services/developer_settings.dart';
import '../services/error_log.dart';

class ImageViewerPage extends StatelessWidget {
  final String imagePath;
  final String rollName;
  final int sequence;

  const ImageViewerPage({
    super.key,
    required this.imagePath,
    required this.rollName,
    required this.sequence,
  });

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _saveToGallery(BuildContext context) async {
    final l = AppLocalizations.of(context);
    try {
      await Gal.putImage(imagePath, album: 'OpenGrains');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('viewer_saved'))),
        );
      }
    } catch (e, stack) {
      ErrorLog.log('Save to Gallery', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DeveloperSettings.verbose
              ? '${l.t('viewer_save_failed')}: $e'
              : l.t('viewer_save_failed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '#$sequence',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_isMobilePlatform)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: l.t('viewer_save'),
              onPressed: () => _saveToGallery(context),
            ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
