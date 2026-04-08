import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_localizations.dart';
import '../widgets/input_decorations.dart';

enum _ColorMode { rgb, hsv, hex }

class LightpadPage extends StatefulWidget {
  const LightpadPage({super.key});

  @override
  State<LightpadPage> createState() => _LightpadPageState();
}

class _LightpadPageState extends State<LightpadPage> {
  double _brightness = 1.0;
  double _opacity = 1.0;
  bool _fullscreen = false;
  _ColorMode _colorMode = _ColorMode.hsv;

  // HSV state (source of truth)
  double _hue = 0;
  double _sat = 0;
  double _val = 1.0;
  bool _updating = false;

  // Controllers
  late final TextEditingController _hexCtrl;
  late final TextEditingController _rCtrl;
  late final TextEditingController _gCtrl;
  late final TextEditingController _bCtrl;

  // Focus nodes for RGB fields (commit on unfocus)
  late final FocusNode _rFocus;
  late final FocusNode _gFocus;
  late final FocusNode _bFocus;

  // Long-press exit state
  Offset? _pressPosition;
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  static const _holdDuration = Duration(seconds: 2);
  static const _tickInterval = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    _hexCtrl = TextEditingController();
    _rCtrl = TextEditingController();
    _gCtrl = TextEditingController();
    _bCtrl = TextEditingController();
    _rFocus = FocusNode()..addListener(_onRGBFocusChanged);
    _gFocus = FocusNode()..addListener(_onRGBFocusChanged);
    _bFocus = FocusNode()..addListener(_onRGBFocusChanged);
    _syncAllFields();
  }

  Color get _color =>
      HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();

  int get _r => (_color.r * 255).round();
  int get _g => (_color.g * 255).round();
  int get _b => (_color.b * 255).round();

  void _syncAllFields() {
    if (_updating) return;
    _updating = true;
    final r = _r;
    final g = _g;
    final b = _b;
    _hexCtrl.text = '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
    _rCtrl.text = r.toString();
    _gCtrl.text = g.toString();
    _bCtrl.text = b.toString();
    _updating = false;
  }

  void _setFromRGB(int r, int g, int b) {
    final c = Color.fromARGB(
        255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    final hsv = HSVColor.fromColor(c);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
  }

  void _onRGBFocusChanged() {
    if (_rFocus.hasFocus || _gFocus.hasFocus || _bFocus.hasFocus) return;
    // All RGB fields lost focus — clamp and commit
    final r = (int.tryParse(_rCtrl.text) ?? 0).clamp(0, 255);
    final g = (int.tryParse(_gCtrl.text) ?? 0).clamp(0, 255);
    final b = (int.tryParse(_bCtrl.text) ?? 0).clamp(0, 255);
    _rCtrl.text = r.toString();
    _gCtrl.text = g.toString();
    _bCtrl.text = b.toString();
    _setFromRGB(r, g, b);
    _updating = true;
    final c = _color;
    final nr = (c.r * 255).round();
    final ng = (c.g * 255).round();
    final nb = (c.b * 255).round();
    _hexCtrl.text = '${nr.toRadixString(16).padLeft(2, '0')}'
        '${ng.toRadixString(16).padLeft(2, '0')}'
        '${nb.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
    _updating = false;
    setState(() {});
  }

  void _onHexChanged(String hex) {
    if (_updating) return;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return;
    final parsed = int.tryParse(clean, radix: 16);
    if (parsed == null) return;
    final c = Color((0xFF << 24) | parsed);
    final hsv = HSVColor.fromColor(c);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
    _updating = true;
    _rCtrl.text = _r.toString();
    _gCtrl.text = _g.toString();
    _bCtrl.text = _b.toString();
    _updating = false;
    setState(() {});
  }

  void _resetColor() {
    setState(() {
      _hue = 0;
      _sat = 0;
      _val = 1.0;
      _syncAllFields();
    });
  }

  void _enterFullscreen() {
    setState(() => _fullscreen = true);
  }

  Color get _displayColor {
    final hsl = HSLColor.fromColor(_color);
    final adjusted = hsl.withLightness(
        (hsl.lightness * _brightness).clamp(0.0, 1.0));
    return adjusted.toColor().withAlpha(
        (_opacity * 255).round().clamp(0, 255));
  }

  String get _hexText {
    final r = _r;
    final g = _g;
    final b = _b;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  String get _rgbText => 'R: $_r  G: $_g  B: $_b';

  String get _hsvText =>
      'H: ${_hue.round()}\u00b0  '
      'S: ${(_sat * 100).round()}%  '
      'V: ${(_val * 100).round()}%';

  void _onHoldStart(LongPressStartDetails details) {
    setState(() {
      _pressPosition = details.localPosition;
      _holdProgress = 0.0;
    });
    _holdTimer?.cancel();
    final totalTicks =
        _holdDuration.inMilliseconds ~/ _tickInterval.inMilliseconds;
    int ticks = 0;
    _holdTimer = Timer.periodic(_tickInterval, (timer) {
      ticks++;
      setState(() {
        _holdProgress = (ticks / totalTicks).clamp(0.0, 1.0);
      });
      if (ticks >= totalTicks) {
        timer.cancel();
        setState(() {
          _fullscreen = false;
          _pressPosition = null;
          _holdProgress = 0.0;
        });
      }
    });
  }

  void _onHoldUpdate(LongPressMoveUpdateDetails details) {
    setState(() => _pressPosition = details.localPosition);
  }

  void _onHoldEnd(LongPressEndDetails details) {
    _holdTimer?.cancel();
    setState(() {
      _pressPosition = null;
      _holdProgress = 0.0;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _hexCtrl.dispose();
    _rCtrl.dispose();
    _gCtrl.dispose();
    _bCtrl.dispose();
    _rFocus.dispose();
    _gFocus.dispose();
    _bFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) {
      return _buildFullscreen();
    }
    return _buildEditor(context);
  }

  Widget _buildFullscreen() {
    return PopScope(
      canPop: false,
      child: Scaffold(
      body: GestureDetector(
        onLongPressStart: _onHoldStart,
        onLongPressMoveUpdate: _onHoldUpdate,
        onLongPressEnd: _onHoldEnd,
        child: Stack(
          children: [
            Container(color: _displayColor),
            if (_pressPosition != null)
              Positioned(
                left: _pressPosition!.dx - 40,
                top: _pressPosition!.dy - 40,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: _holdProgress,
                      color: _color.computeLuminance() > 0.5
                          ? Colors.black54
                          : Colors.white70,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final contrastColor = _color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    final contrastColorDim = _color.computeLuminance() > 0.5
        ? Colors.black54
        : Colors.white70;

    final overlaySecondary = switch (_colorMode) {
      _ColorMode.rgb => _rgbText,
      _ColorMode.hsv => _hsvText,
      _ColorMode.hex => '',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l.t('lightpad_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.t('lightpad_default_white'),
            onPressed: _resetColor,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview card with mode chips
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: _displayColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Stack(
                children: [
                  // Hex display
                  Positioned(
                    left: 16,
                    bottom: overlaySecondary.isNotEmpty ? 36 : 16,
                    child: Text(_hexText,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: contrastColor,
                        )),
                  ),
                  // Secondary info
                  if (overlaySecondary.isNotEmpty)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Text(overlaySecondary,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: contrastColorDim,
                          )),
                    ),
                  // Mode chips
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _ColorMode.values.map((mode) {
                        final isActive = _colorMode == mode;
                        final label = switch (mode) {
                          _ColorMode.rgb => 'RGB',
                          _ColorMode.hsv => 'HSV',
                          _ColorMode.hex => 'Hex',
                        };
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _colorMode = mode;
                              _syncAllFields();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? contrastColor.withAlpha(180)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.transparent
                                      : contrastColorDim.withAlpha(120),
                                ),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? (_color.computeLuminance() > 0.5
                                            ? Colors.white
                                            : Colors.black87)
                                        : contrastColorDim,
                                  )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mode-specific controls
            if (_colorMode == _ColorMode.rgb)
              _buildRGBControls(colorScheme),
            if (_colorMode == _ColorMode.hsv)
              _buildHSVControls(colorScheme),
            if (_colorMode == _ColorMode.hex)
              _buildHexControls(l),

            const SizedBox(height: 16),

            // Brightness slider
            Text(l.t('lightpad_brightness', {
              'value': (_brightness * 100).round().toString()
            }),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            Slider(
              value: _brightness,
              min: 0,
              max: 1,
              divisions: 100,
              label: '${(_brightness * 100).round()}%',
              onChanged: (v) => setState(() => _brightness = v),
            ),
            const SizedBox(height: 8),

            // Transparency slider
            Text(l.t('lightpad_transparency', {
              'value': (100 - _opacity * 100).round().toString()
            }),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            Slider(
              value: 1.0 - _opacity,
              min: 0,
              max: 1,
              divisions: 100,
              label: '${(100 - _opacity * 100).round()}%',
              onChanged: (v) => setState(() => _opacity = 1.0 - v),
            ),
            const SizedBox(height: 20),

            // Fullscreen button
            FilledButton.icon(
              onPressed: _enterFullscreen,
              icon: const Icon(Icons.fullscreen),
              label: Text(l.t('lightpad_fullscreen')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- RGB mode: gradient sliders with numeric fields ---

  Widget _buildRGBControls(ColorScheme cs) {
    return Column(
      children: [
        _buildGradientSlider(
          label: 'R',
          value: _r,
          startColor: Color.fromARGB(255, 0, _g, _b),
          endColor: Color.fromARGB(255, 255, _g, _b),
          controller: _rCtrl,
          focusNode: _rFocus,
          onSliderChanged: (v) {
            _setFromRGB(v, _g, _b);
            _syncAllFields();
            setState(() {});
          },
          cs: cs,
        ),
        const SizedBox(height: 12),
        _buildGradientSlider(
          label: 'G',
          value: _g,
          startColor: Color.fromARGB(255, _r, 0, _b),
          endColor: Color.fromARGB(255, _r, 255, _b),
          controller: _gCtrl,
          focusNode: _gFocus,
          onSliderChanged: (v) {
            _setFromRGB(_r, v, _b);
            _syncAllFields();
            setState(() {});
          },
          cs: cs,
        ),
        const SizedBox(height: 12),
        _buildGradientSlider(
          label: 'B',
          value: _b,
          startColor: Color.fromARGB(255, _r, _g, 0),
          endColor: Color.fromARGB(255, _r, _g, 255),
          controller: _bCtrl,
          focusNode: _bFocus,
          onSliderChanged: (v) {
            _setFromRGB(_r, _g, v);
            _syncAllFields();
            setState(() {});
          },
          cs: cs,
        ),
      ],
    );
  }

  Widget _buildGradientSlider({
    required String label,
    required int value,
    required Color startColor,
    required Color endColor,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<int> onSliderChanged,
    required ColorScheme cs,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                onPanDown: (d) {
                  final v =
                      (d.localPosition.dx / width * 255).round().clamp(0, 255);
                  onSliderChanged(v);
                },
                onPanUpdate: (d) {
                  final v =
                      (d.localPosition.dx / width * 255).round().clamp(0, 255);
                  onSliderChanged(v);
                },
                child: SizedBox(
                  height: 36,
                  child: CustomPaint(
                    size: Size(width, 36),
                    painter: _GradientTrackPainter(
                      startColor: startColor,
                      endColor: endColor,
                      value: value / 255,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
          width: 40,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLength: 3,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              height: 1,
            ),
            decoration: underlineAlwaysDecoration(cs),
          ),
        ),
        ),
      ],
    );
  }

  // --- HSV mode: hue bar + 2D SV rectangle ---

  Widget _buildHSVControls(ColorScheme cs) {
    return Column(
      children: [
        // Hue bar
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onPanDown: (d) => setState(() {
                _hue = (d.localPosition.dx / width * 360).clamp(0, 360);
                _syncAllFields();
              }),
              onPanUpdate: (d) => setState(() {
                _hue = (d.localPosition.dx / width * 360).clamp(0, 360);
                _syncAllFields();
              }),
              child: SizedBox(
                height: 28,
                child: CustomPaint(
                  size: Size(width, 28),
                  painter: _HueBarPainter(hue: _hue),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // SV rectangle
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 200.0;
            return GestureDetector(
              onPanDown: (d) => setState(() {
                _sat = (d.localPosition.dx / width).clamp(0, 1);
                _val = (1.0 - d.localPosition.dy / height).clamp(0, 1);
                _syncAllFields();
              }),
              onPanUpdate: (d) => setState(() {
                _sat = (d.localPosition.dx / width).clamp(0, 1);
                _val = (1.0 - d.localPosition.dy / height).clamp(0, 1);
                _syncAllFields();
              }),
              child: SizedBox(
                height: height,
                child: CustomPaint(
                  size: Size(width, height),
                  painter: _SVRectPainter(
                    hue: _hue,
                    saturation: _sat,
                    value: _val,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- Hex mode: text field only ---

  Widget _buildHexControls(AppLocalizations l) {
    return TextField(
      controller: _hexCtrl,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: l.t('lightpad_hex'),
        prefixText: '#',
        isDense: true,
      ),
      onChanged: _onHexChanged,
    );
  }
}

// --- Custom painters ---

class _GradientTrackPainter extends CustomPainter {
  final Color startColor;
  final Color endColor;
  final double value;

  _GradientTrackPainter({
    required this.startColor,
    required this.endColor,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 14.0;
    final trackY = (size.height - trackHeight) / 2;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackY, size.width, trackHeight),
      const Radius.circular(7),
    );

    // Gradient fill
    final gradient = LinearGradient(colors: [startColor, endColor]);
    canvas.drawRRect(trackRect,
        Paint()..shader = gradient.createShader(trackRect.outerRect));

    // Border
    canvas.drawRRect(
        trackRect,
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);

    // Thumb
    const thumbR = 11.0;
    final thumbX = (value * size.width).clamp(thumbR, size.width - thumbR);
    final center = Offset(thumbX, size.height / 2);

    // Shadow
    canvas.drawCircle(
        center + const Offset(0, 1), thumbR, Paint()..color = Colors.black26);
    // White fill
    canvas.drawCircle(center, thumbR, Paint()..color = Colors.white);
    // Outline
    canvas.drawCircle(
        center,
        thumbR,
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    // Color dot
    final thumbColor = Color.lerp(startColor, endColor, value) ?? endColor;
    canvas.drawCircle(center, 7, Paint()..color = thumbColor);
  }

  @override
  bool shouldRepaint(_GradientTrackPainter old) =>
      old.startColor != startColor ||
      old.endColor != endColor ||
      old.value != value;
}

class _HueBarPainter extends CustomPainter {
  final double hue;

  _HueBarPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );

    // Rainbow gradient
    final colors = List.generate(
        7, (i) => HSVColor.fromAHSV(1.0, i * 60.0, 1.0, 1.0).toColor());
    final gradient = LinearGradient(colors: colors);
    canvas.drawRRect(trackRect,
        Paint()..shader = gradient.createShader(trackRect.outerRect));

    // Border
    canvas.drawRRect(
        trackRect,
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);

    // Thumb
    const thumbR = 11.0;
    final thumbX =
        (hue / 360 * size.width).clamp(thumbR, size.width - thumbR);
    final center = Offset(thumbX, size.height / 2);

    canvas.drawCircle(
        center + const Offset(0, 1), thumbR, Paint()..color = Colors.black26);
    canvas.drawCircle(center, thumbR, Paint()..color = Colors.white);
    canvas.drawCircle(
        center,
        thumbR,
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawCircle(center, 7,
        Paint()..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor());
  }

  @override
  bool shouldRepaint(_HueBarPainter old) => old.hue != hue;
}

class _SVRectPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _SVRectPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    canvas.save();
    canvas.clipRRect(rrect);

    // Base hue
    final hueColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    canvas.drawRect(rect, Paint()..color = hueColor);

    // Saturation: white → transparent (left to right)
    final satGradient = LinearGradient(
      colors: [Colors.white, Colors.white.withAlpha(0)],
    );
    canvas.drawRect(
        rect, Paint()..shader = satGradient.createShader(rect));

    // Value: transparent → black (top to bottom)
    final valGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black.withAlpha(0), Colors.black],
    );
    canvas.drawRect(
        rect, Paint()..shader = valGradient.createShader(rect));

    canvas.restore();

    // Border
    canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);

    // Indicator circle
    final x = (saturation * size.width).clamp(0.0, size.width);
    final y = ((1.0 - value) * size.height).clamp(0.0, size.height);
    final center = Offset(x, y);

    canvas.drawCircle(
        center,
        11,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..color = Colors.black38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(_SVRectPainter old) =>
      old.hue != hue ||
      old.saturation != saturation ||
      old.value != value;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = color.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
