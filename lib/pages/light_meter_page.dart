import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../services/app_localizations.dart';
import '../services/error_log.dart';
import '../services/light_meter_constants.dart';

class LightMeterPage extends StatefulWidget {
  const LightMeterPage({super.key});

  @override
  State<LightMeterPage> createState() => _LightMeterPageState();
}

class _LightMeterPageState extends State<LightMeterPage>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _controller;
  bool _cameraReady = false;
  bool _cameraError = false;

  // Metering
  MeteringMode _meteringMode = MeteringMode.centerWeighted;
  Offset? _pointMeterPosition; // normalized 0-1

  // EV
  double _currentEV = 12.0;
  final TextEditingController _manualEvCtrl =
      TextEditingController(text: '12.0');
  DateTime _lastFrameTime = DateTime.now();


  // Parameters
  ExposureStep _exposureStep = ExposureStep.third;
  CalculatedParam _calculatedParam = CalculatedParam.shutterSpeed;
  int _apertureIndex = 8; // f/8 in 1/3-stop list
  int _shutterIndex = 30; // 1/30 in 1/3-stop list
  int _isoIndex = 3; // ISO 100 in 1/3-stop list

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStep();
    if (_isMobilePlatform) {
      _initCamera();
    }
  }

  Future<void> _loadStep() async {
    final step = await ExposureStepSettings.load();
    if (!mounted) return;
    setState(() => _exposureStep = step);
    // Re-snap indices to the new step's lists
    _snapIndicesToCurrentStep();
    _recalculate();
  }

  void _snapIndicesToCurrentStep() {
    final apertures = LightMeterConstants.apertureStops(_exposureStep);
    final shutters = LightMeterConstants.shutterSpeeds(_exposureStep);
    final isos = LightMeterConstants.isoValues(_exposureStep);
    _apertureIndex = _apertureIndex.clamp(0, apertures.length - 1);
    _shutterIndex = _shutterIndex.clamp(0, shutters.length - 1);
    _isoIndex = _isoIndex.clamp(0, isos.length - 1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _manualEvCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobilePlatform) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
      setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      // Prefer back camera
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(cam, ResolutionPreset.medium,
          enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _cameraReady = true);

      // Lock exposure to a fixed neutral point so frame luminance
      // reflects actual scene brightness, not AE compensation.
      try {
        await controller.setExposureMode(ExposureMode.locked);
        await controller.setExposureOffset(0.0);
      } catch (_) {
        // Some devices may not support locking — fall back to auto
      }

      controller.startImageStream(_processFrame);
    } catch (e, stack) {
      ErrorLog.log('Camera Init', e, stack);
      if (mounted) setState(() => _cameraError = true);
    }
  }

  void _processFrame(CameraImage image) {
    // Throttle to ~5 fps
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 200) return;
    _lastFrameTime = now;

    final double luminance;
    try {
      luminance = _computeLuminance(image);
    } catch (_) {
      return;
    }

    // Convert luminance (0-255) to EV
    // Calibrated so that mid-gray (~118) maps to roughly EV 12
    // Camera exposure is locked at init so frame brightness reflects
    // actual scene luminance, not AE-adjusted values.
    final ev = luminance > 0
        ? (math.log(luminance / 8.0) / math.ln2) + 4.0
        : 0.0;

    if (mounted) {
      setState(() {
        _currentEV = ev.clamp(-2.0, 22.0);
      });
      _recalculate();
    }
  }

  double _computeLuminance(CameraImage image) {
    // Android: YUV420 — Y plane is luminance
    // iOS: BGRA8888 — compute from RGB
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final width = image.width;
    final height = image.height;
    final isYUV = image.format.group == ImageFormatGroup.yuv420;

    final step = 8; // subsample every 8th pixel
    double totalWeight = 0;
    double weightedSum = 0;

    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        double lum;
        if (isYUV) {
          final rowStride = plane.bytesPerRow;
          final idx = y * rowStride + x;
          if (idx >= bytes.length) continue;
          lum = bytes[idx].toDouble();
        } else {
          // BGRA
          final rowStride = plane.bytesPerRow;
          final pixelIdx = y * rowStride + x * 4;
          if (pixelIdx + 2 >= bytes.length) continue;
          final b = bytes[pixelIdx];
          final g = bytes[pixelIdx + 1];
          final r = bytes[pixelIdx + 2];
          lum = 0.299 * r + 0.587 * g + 0.114 * b;
        }

        final weight = _meteringWeight(
            x / width, y / height, width.toDouble(), height.toDouble());
        weightedSum += lum * weight;
        totalWeight += weight;
      }
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }

  double _meteringWeight(
      double nx, double ny, double width, double height) {
    // Point metering overrides the base mode when active
    if (_pointMeterPosition != null) {
      final px = _pointMeterPosition!.dx;
      final py = _pointMeterPosition!.dy;
      final dx = nx - px;
      final dy = ny - py;
      final dist = math.sqrt(dx * dx + dy * dy);
      return dist < 0.08 ? 1.0 : 0.0;
    }

    switch (_meteringMode) {
      case MeteringMode.average:
        return 1.0;

      case MeteringMode.centerWeighted:
        final dx = nx - 0.5;
        final dy = ny - 0.5;
        final dist = dx * dx + dy * dy;
        return math.exp(-dist * 8.0);

      case MeteringMode.matrix:
        final dx = nx - 0.5;
        final dy = ny - 0.5;
        final dist = dx * dx + dy * dy;
        return 0.5 + 0.5 * math.exp(-dist * 4.0);

      case MeteringMode.point:
        // Fallback if no point set — treat as center-weighted
        final dx = nx - 0.5;
        final dy = ny - 0.5;
        final dist = dx * dx + dy * dy;
        return math.exp(-dist * 8.0);
    }
  }

  void _onPointMeterTap(TapDownDetails details, BoxConstraints constraints) {
    final nx = details.localPosition.dx / constraints.maxWidth;
    final ny = details.localPosition.dy / constraints.maxHeight;
    setState(() {
      _pointMeterPosition = Offset(nx.clamp(0, 1), ny.clamp(0, 1));
    });
    _controller?.setExposurePoint(
        Offset(nx.clamp(0, 1), ny.clamp(0, 1)));
    // Re-lock exposure at the new point
    _controller?.setExposureMode(ExposureMode.locked);
  }

  void _clearPointMeter() {
    setState(() {
      _pointMeterPosition = null;
    });
    _controller?.setExposurePoint(null);
    _controller?.setExposureMode(ExposureMode.locked);
  }

  // ───── Calculation ─────

  void _recalculate() {
    final ev = _currentEV;
    final apertures = LightMeterConstants.apertureStops(_exposureStep);
    final shutters = LightMeterConstants.shutterSpeeds(_exposureStep);
    final isos = LightMeterConstants.isoValues(_exposureStep);

    final ai = _apertureIndex.clamp(0, apertures.length - 1);
    final si = _shutterIndex.clamp(0, shutters.length - 1);
    final ii = _isoIndex.clamp(0, isos.length - 1);

    switch (_calculatedParam) {
      case CalculatedParam.shutterSpeed:
        final t = LightMeterConstants.solveShutter(
            ev, apertures[ai], isos[ii]);
        setState(() {
          _shutterIndex =
              LightMeterConstants.nearestStopIndex(shutters, t);
        });

      case CalculatedParam.aperture:
        final n = LightMeterConstants.solveAperture(
            ev, shutters[si], isos[ii]);
        setState(() {
          _apertureIndex =
              LightMeterConstants.nearestStopIndex(apertures, n);
        });

      case CalculatedParam.iso:
        final iso = LightMeterConstants.solveISO(
            ev, apertures[ai], shutters[si]);
        setState(() {
          _isoIndex = LightMeterConstants.nearestISOIndex(isos, iso);
        });
    }
  }

  void _incrementParam(CalculatedParam param) {
    final apertures = LightMeterConstants.apertureStops(_exposureStep);
    final shutters = LightMeterConstants.shutterSpeeds(_exposureStep);
    final isos = LightMeterConstants.isoValues(_exposureStep);
    setState(() {
      switch (param) {
        case CalculatedParam.aperture:
          if (_apertureIndex < apertures.length - 1) _apertureIndex++;
        case CalculatedParam.shutterSpeed:
          if (_shutterIndex < shutters.length - 1) _shutterIndex++;
        case CalculatedParam.iso:
          if (_isoIndex < isos.length - 1) _isoIndex++;
      }
    });
    _recalculate();
  }

  void _decrementParam(CalculatedParam param) {
    setState(() {
      switch (param) {
        case CalculatedParam.aperture:
          if (_apertureIndex > 0) _apertureIndex--;
        case CalculatedParam.shutterSpeed:
          if (_shutterIndex > 0) _shutterIndex--;
        case CalculatedParam.iso:
          if (_isoIndex > 0) _isoIndex--;
      }
    });
    _recalculate();
  }

  String _paramValue(CalculatedParam param) {
    final apertures = LightMeterConstants.apertureStops(_exposureStep);
    final shutters = LightMeterConstants.shutterSpeeds(_exposureStep);
    final isos = LightMeterConstants.isoValues(_exposureStep);
    switch (param) {
      case CalculatedParam.aperture:
        return LightMeterConstants.formatAperture(
            apertures[_apertureIndex.clamp(0, apertures.length - 1)]);
      case CalculatedParam.shutterSpeed:
        return LightMeterConstants.formatShutter(
            shutters[_shutterIndex.clamp(0, shutters.length - 1)]);
      case CalculatedParam.iso:
        return LightMeterConstants.formatISO(
            isos[_isoIndex.clamp(0, isos.length - 1)]);
    }
  }

  String _paramLabel(CalculatedParam param, AppLocalizations l) {
    switch (param) {
      case CalculatedParam.aperture:
        return l.t('lightmeter_aperture');
      case CalculatedParam.shutterSpeed:
        return l.t('lightmeter_shutter');
      case CalculatedParam.iso:
        return l.t('lightmeter_iso');
    }
  }

  // ───── Build ─────

  Widget _buildCameraPreview(AppLocalizations l, ColorScheme cs) {
    if (!_isMobilePlatform || _cameraError) {
      // Desktop fallback: manual EV input
      return Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wb_sunny_outlined,
                  size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              if (!_isMobilePlatform)
                Text(l.t('lightmeter_no_camera'),
                    style: TextStyle(color: cs.onSurfaceVariant))
              else
                Text('Camera error',
                    style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.t('lightmeter_manual_ev'),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _manualEvCtrl,
                      maxLength: 6,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        counterText: '',
                      ),
                      onChanged: (v) {
                        final ev = double.tryParse(v);
                        if (ev != null) {
                          _currentEV = ev.clamp(-2.0, 22.0);
                          _recalculate();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraReady || _controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l.t('lightmeter_initializing'),
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) =>
              _onPointMeterTap(details, constraints),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.previewSize?.height ?? 1,
                    height: _controller!.value.previewSize?.width ?? 1,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),

              // EV badge (top-right)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'EV ${_currentEV.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),

              // Point metering overlay
              if (_pointMeterPosition != null)
                Positioned(
                  left: _pointMeterPosition!.dx * constraints.maxWidth - 24,
                  top: _pointMeterPosition!.dy * constraints.maxHeight - 24,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.yellow, width: 2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),

              // Center-weighted indicator (only when no point active)
              if (_pointMeterPosition == null &&
                  _meteringMode == MeteringMode.centerWeighted)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white38, width: 1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMeteringSelector(AppLocalizations l, ColorScheme cs) {
    final hasPoint = _pointMeterPosition != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<MeteringMode>(
              segments: [
                ButtonSegment<MeteringMode>(
                  value: MeteringMode.centerWeighted,
                  label: Text(l.t('lightmeter_metering_center'),
                      style: const TextStyle(fontSize: 12)),
                ),
                ButtonSegment<MeteringMode>(
                  value: MeteringMode.matrix,
                  label: Text(l.t('lightmeter_metering_matrix'),
                      style: const TextStyle(fontSize: 12)),
                ),
                ButtonSegment<MeteringMode>(
                  value: MeteringMode.average,
                  label: Text(l.t('lightmeter_metering_average'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_meteringMode},
              onSelectionChanged: hasPoint
                  ? null
                  : (v) {
                      setState(() => _meteringMode = v.first);
                    },
            ),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.close,
              size: 16,
              color: hasPoint ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.3),
            ),
            label: Text(
              l.t('lightmeter_metering_point'),
              style: TextStyle(
                fontSize: 12,
                color: hasPoint ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
            backgroundColor: hasPoint ? cs.surfaceContainerHighest : null,
            side: BorderSide(
              color: hasPoint ? cs.outline : cs.outline.withValues(alpha: 0.3),
            ),
            onPressed: hasPoint ? _clearPointMeter : null,
          ),
        ],
      ),
    );
  }

  Widget _buildParamSelector(
      CalculatedParam param, AppLocalizations l, ColorScheme cs) {
    final isCalc = _calculatedParam == param;
    final value = _paramValue(param);
    final label = _paramLabel(param, l);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _calculatedParam = param);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isCalc
                ? cs.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCalc ? FontWeight.bold : FontWeight.normal,
                  color: isCalc ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              // Value with arrows
              if (isCalc)
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _decrementParam(param),
                      child: Icon(Icons.chevron_left,
                          size: 28, color: cs.onSurface),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _incrementParam(param),
                      child: Icon(Icons.chevron_right,
                          size: 28, color: cs.onSurface),
                    ),
                  ],
                ),
              if (isCalc)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.t('lightmeter_calculated'),
                    style: TextStyle(fontSize: 10, color: cs.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pop(context),
        ),
        title: Text(l.t('lightmeter_title')),
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: _buildCameraPreview(l, cs),
          ),

          // Metering mode selector
          _buildMeteringSelector(l, cs),

          // EV display (non-camera fallback already shows it)
          if (_isMobilePlatform && _cameraReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'EV ${_currentEV.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

          // Parameter selectors
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  _buildParamSelector(
                      CalculatedParam.aperture, l, cs),
                  _buildParamSelector(
                      CalculatedParam.shutterSpeed, l, cs),
                  _buildParamSelector(
                      CalculatedParam.iso, l, cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
