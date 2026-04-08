import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/developer_settings.dart';
import '../services/error_log.dart';
import '../services/film_storage.dart';
import '../services/import_export_service.dart';
import '../services/light_meter_constants.dart';
import '../widgets/input_decorations.dart';
import '../services/location_service.dart';
import '../services/location_settings.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_picker_page.dart';
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
  late FocusNode _commentFocus;
  String? _imagePath;
  String? _resolvedPath;
  final _picker = ImagePicker();
  double _ec = 0.0;
  double _ecStep = 1 / 3;
  double? _latitude;
  double? _longitude;
  bool _locationLoading = false;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final FocusNode _latFocus;
  late final FocusNode _lngFocus;
  final MapController _previewMapCtrl = MapController();

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
    _commentFocus = FocusNode()..addListener(() {
      if (!_commentFocus.hasFocus) {
        final trimmed = _commentCtrl.text.trim();
        if (trimmed != _commentCtrl.text) _commentCtrl.text = trimmed;
      }
    });
    _ec = (widget.existingShot?['ec'] as num?)?.toDouble() ?? 0.0;
    _latitude = (widget.existingShot?['latitude'] as num?)?.toDouble();
    _longitude = (widget.existingShot?['longitude'] as num?)?.toDouble();
    _latCtrl = TextEditingController(
        text: _latitude?.toStringAsFixed(4) ?? '');
    _lngCtrl = TextEditingController(
        text: _longitude?.toStringAsFixed(4) ?? '');
    _latFocus = FocusNode()..addListener(_onCoordFocusChanged);
    _lngFocus = FocusNode()..addListener(_onCoordFocusChanged);
    _loadEcStep();
    _imagePath =
        widget.existingShot?['imagePath'] as String?;
    _resolveImage();
    if (!_isEditing) _maybeAutoCapture();
  }

  void _maybeAutoCapture() {
    if (!LocationService.isSupported) return;
    if (!LocationSettings.value) return;
    _captureLocation(silent: true);
  }

  Future<void> _loadEcStep() async {
    final step = await ExposureStepSettings.load();
    if (mounted) {
      setState(() {
        _ecStep = switch (step) {
          ExposureStep.full => 1.0,
          ExposureStep.half => 0.5,
          ExposureStep.third => 1 / 3,
          ExposureStep.quarter => 0.25,
        };
        _ec = (_ec / _ecStep).roundToDouble() * _ecStep;
      });
    }
  }

  String get _ecLabel {
    if (_ec == 0) return '0';
    final abs = _ec.abs();
    final sign = _ec > 0 ? '+' : '-';
    final thirds = (abs / (1 / 3)).round();
    final quarters = (abs / 0.25).round();
    if ((abs - thirds * (1 / 3)).abs() < 0.01) {
      final whole = thirds ~/ 3;
      final rem = thirds % 3;
      if (rem == 0) return '$sign$whole';
      if (whole == 0) return '$sign$rem/3';
      return '$sign$whole $rem/3';
    }
    if ((abs - quarters * 0.25).abs() < 0.01) {
      final whole = quarters ~/ 4;
      final rem = quarters % 4;
      if (rem == 0) return '$sign$whole';
      if (rem == 2) {
        if (whole == 0) return '$sign\u00bd';
        return '$sign$whole\u00bd';
      }
      if (whole == 0) return '$sign$rem/4';
      return '$sign$whole $rem/4';
    }
    return '${_ec > 0 ? "+" : ""}${_ec.toStringAsFixed(1)}';
  }

  Future<void> _captureLocation({bool silent = false}) async {
    setState(() => _locationLoading = true);
    try {
      final result = await LocationService.getCurrentPosition();
      if (result != null && mounted) {
        setState(() {
          _latitude = result.$1;
          _longitude = result.$2;
        });
        _syncCoordControllers();
        _movePreviewMap();
      } else if (mounted && !silent) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('shot_location_unavailable'))),
        );
      }
    } catch (e, stack) {
      ErrorLog.log('GPS Location', e, stack);
      if (mounted && !silent) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DeveloperSettings.verbose
              ? '${l.t('shot_location_error')}: $e'
              : l.t('shot_location_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _syncCoordControllers() {
    _latCtrl.text = _latitude?.toStringAsFixed(4) ?? '';
    _lngCtrl.text = _longitude?.toStringAsFixed(4) ?? '';
  }

  void _movePreviewMap() {
    if (_latitude == null || _longitude == null) return;
    try {
      _previewMapCtrl.move(
          LatLng(_latitude!, _longitude!), _previewMapCtrl.camera.zoom);
    } catch (_) {}
  }

  void _onCoordFocusChanged() {
    if (_latFocus.hasFocus || _lngFocus.hasFocus) return;
    // Both lost focus — commit values
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat != null && lng != null) {
      final cLat = lat.clamp(-90.0, 90.0);
      final cLng = lng.clamp(-180.0, 180.0);
      setState(() {
        _latitude = cLat;
        _longitude = cLng;
      });
      _syncCoordControllers();
      _movePreviewMap();
    } else if (_latCtrl.text.isEmpty && _lngCtrl.text.isEmpty) {
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
  }

  void _clearLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
    _syncCoordControllers();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<(double, double)>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialLat: _latitude,
          initialLng: _longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result.$1;
        _longitude = result.$2;
      });
      _syncCoordControllers();
      _movePreviewMap();
    }
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
    _commentFocus.dispose();
    _commentCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _latFocus.dispose();
    _lngFocus.dispose();
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
    } catch (e, stack) {
      ErrorLog.log('Image Picker', e, stack);
      if (mounted) {
        final l = AppLocalizations.of(context);
        final msg = source == ImageSource.camera
            ? l.t('shot_camera_unavailable')
            : l.t('shot_gallery_unavailable');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DeveloperSettings.verbose
              ? '$msg: $e' : msg)),
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
      'ec': _ec,
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
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
            // Sequence + Exposure compensation (single row)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seq # (1/4 width)
                Flexible(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Seq #',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextField(
                          controller: _seqCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textAlign: TextAlign.left,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          isDense: true,
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // EC (3/4 width)
                Flexible(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('shot_ec'),
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          GestureDetector(
                            onDoubleTap: () =>
                                setState(() => _ec = 0.0),
                            child: SizedBox(
                              width: 40,
                              child: Text(_ecLabel,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight:
                                              FontWeight.bold)),
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _ec,
                              min: -3.0,
                              max: 3.0,
                              divisions: (6 / _ecStep).round(),
                              label: _ecLabel,
                              onChanged: (v) {
                                setState(() {
                                  _ec = (v / _ecStep)
                                          .roundToDouble() *
                                      _ecStep;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            // Location section
            const SizedBox(height: 20),
            Text(l.t('shot_location'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            if (_latitude != null) ...[
              // Inline map preview
              GestureDetector(
                onTap: _openMapPicker,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: colorScheme.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: IgnorePointer(
                      child: FlutterMap(
                        mapController: _previewMapCtrl,
                        options: MapOptions(
                          initialCenter:
                              LatLng(_latitude!, _longitude!),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.muxianli.photographytoolbox',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                    _latitude!, _longitude!),
                                width: 40,
                                height: 40,
                                child: Icon(Icons.location_pin,
                                    size: 40,
                                    color: colorScheme.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Editable coordinates + clear button
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Lat',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _latCtrl,
                      focusNode: _latFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.\-]')),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                      decoration: underlineHoverDecoration(colorScheme),
                    ),
                  ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 6, right: 6, bottom: 4),
                    child: Text(',',
                        style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Lng',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _lngCtrl,
                      focusNode: _lngFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.\-]')),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                      decoration: underlineHoverDecoration(colorScheme),
                    ),
                  ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _clearLocation,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: l.t('shot_clear_location'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ] else ...[
              // No location — capture (mobile) or pick on map
              Row(
                children: [
                  if (_isMobilePlatform) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _locationLoading ? null : _captureLocation,
                        icon: _locationLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        label: Text(l.t('shot_capture_location')),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openMapPicker,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(l.t('shot_pick_on_map')),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            // Comment section
            Text(l.t('shot_comment'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentCtrl,
              focusNode: _commentFocus,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.t('shot_comment_hint'),
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
