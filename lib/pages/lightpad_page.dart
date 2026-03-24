import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_drawer.dart';
import '../services/app_localizations.dart';

class LightpadPage extends StatefulWidget {
  const LightpadPage({super.key});

  @override
  State<LightpadPage> createState() => _LightpadPageState();
}

class _LightpadPageState extends State<LightpadPage> {
  Color _color = Colors.white;
  double _brightness = 1.0;
  double _opacity = 1.0;
  bool _fullscreen = false;

  // Long-press exit state
  Offset? _pressPosition;
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  static const _holdDuration = Duration(seconds: 2);
  static const _tickInterval = Duration(milliseconds: 16);

  void _resetColor() {
    setState(() => _color = Colors.white);
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

  String get _rgbText {
    final c = _color;
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return 'R: $r  G: $g  B: $b';
  }

  String get _hsvText {
    final hsv = HSVColor.fromColor(_color);
    return 'H: ${hsv.hue.round()}\u00b0  '
        'S: ${(hsv.saturation * 100).round()}%  '
        'V: ${(hsv.value * 100).round()}%';
  }

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
    return Scaffold(
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
    );
  }

  Widget _buildEditor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/'),
        ),
        title: Text(l.t('lightpad_title')),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color preview
            GestureDetector(
              onTap: _pickColor,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: _displayColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.outlineVariant),
                ),
                child: Center(
                  child: Icon(Icons.color_lens,
                      size: 40,
                      color: _color.computeLuminance() > 0.5
                          ? Colors.black38
                          : Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Color codes
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(_rgbText,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text(_hsvText,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              fontFamily: 'monospace')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Brightness slider
            Text(l.t('lightpad_brightness', {'value': (_brightness * 100).round().toString()}),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            Slider(
              value: _brightness,
              min: 0,
              max: 1,
              divisions: 100,
              label: '${(_brightness * 100).round()}%',
              onChanged: (v) =>
                  setState(() => _brightness = v),
            ),
            const SizedBox(height: 8),

            // Transparency slider
            Text(l.t('lightpad_transparency', {'value': (100 - _opacity * 100).round().toString()}),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            Slider(
              value: 1.0 - _opacity,
              min: 0,
              max: 1,
              divisions: 100,
              label: '${(100 - _opacity * 100).round()}%',
              onChanged: (v) =>
                  setState(() => _opacity = 1.0 - v),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetColor,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.t('lightpad_default_white')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _enterFullscreen,
                    icon: const Icon(Icons.fullscreen),
                    label: Text(l.t('lightpad_fullscreen')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _pickColor() {
    final l = AppLocalizations.of(context);
    double hue = HSVColor.fromColor(_color).hue;
    double sat = HSVColor.fromColor(_color).saturation;
    double val = HSVColor.fromColor(_color).value;
    final hexCtrl = TextEditingController();
    final hueCtrl = TextEditingController();
    final satCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    bool updating = false;

    void syncFromHSV(StateSetter setDialogState) {
      if (updating) return;
      updating = true;
      final c = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
      final r = (c.r * 255).round();
      final g = (c.g * 255).round();
      final b = (c.b * 255).round();
      hexCtrl.text = '${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
      hueCtrl.text = hue.round().toString();
      satCtrl.text = (sat * 100).round().toString();
      valCtrl.text = (val * 100).round().toString();
      updating = false;
    }

    void syncFromHex(String hex, StateSetter setDialogState) {
      if (updating) return;
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length != 6) return;
      final parsed = int.tryParse(clean, radix: 16);
      if (parsed == null) return;
      updating = true;
      final c = Color((0xFF << 24) | parsed);
      final hsv = HSVColor.fromColor(c);
      hue = hsv.hue;
      sat = hsv.saturation;
      val = hsv.value;
      hueCtrl.text = hue.round().toString();
      satCtrl.text = (sat * 100).round().toString();
      valCtrl.text = (val * 100).round().toString();
      setDialogState(() {});
      updating = false;
    }

    void syncFromFields(StateSetter setDialogState) {
      if (updating) return;
      final h = double.tryParse(hueCtrl.text);
      final s = double.tryParse(satCtrl.text);
      final v = double.tryParse(valCtrl.text);
      if (h == null || s == null || v == null) return;
      updating = true;
      hue = h.clamp(0, 360);
      sat = (s / 100).clamp(0, 1);
      val = (v / 100).clamp(0, 1);
      final c = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
      final r = (c.r * 255).round();
      final g = (c.g * 255).round();
      final b = (c.b * 255).round();
      hexCtrl.text = '${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
      setDialogState(() {});
      updating = false;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          syncFromHSV(setDialogState);
          final preview =
              HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
          return AlertDialog(
            title: Text(l.t('lightpad_pick_color')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: preview,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Hex input
                  TextField(
                    controller: hexCtrl,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: l.t('lightpad_hex'),
                      prefixText: '#',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        syncFromHex(v, setDialogState),
                  ),
                  const SizedBox(height: 12),
                  // Hue
                  _sliderWithInput(
                    label: 'H',
                    value: hue,
                    min: 0,
                    max: 360,
                    controller: hueCtrl,
                    onSlider: (v) {
                      hue = v;
                      syncFromHSV(setDialogState);
                      setDialogState(() {});
                    },
                    onField: () =>
                        syncFromFields(setDialogState),
                  ),
                  const SizedBox(height: 4),
                  // Saturation
                  _sliderWithInput(
                    label: 'S',
                    value: sat * 100,
                    min: 0,
                    max: 100,
                    controller: satCtrl,
                    onSlider: (v) {
                      sat = v / 100;
                      syncFromHSV(setDialogState);
                      setDialogState(() {});
                    },
                    onField: () =>
                        syncFromFields(setDialogState),
                  ),
                  const SizedBox(height: 4),
                  // Value
                  _sliderWithInput(
                    label: 'V',
                    value: val * 100,
                    min: 0,
                    max: 100,
                    controller: valCtrl,
                    onSlider: (v) {
                      val = v / 100;
                      syncFromHSV(setDialogState);
                      setDialogState(() {});
                    },
                    onField: () =>
                        syncFromFields(setDialogState),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  hexCtrl.dispose();
                  hueCtrl.dispose();
                  satCtrl.dispose();
                  valCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: Text(l.t('lightpad_cancel')),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _color = HSVColor.fromAHSV(
                            1.0, hue, sat, val)
                        .toColor();
                  });
                  hexCtrl.dispose();
                  hueCtrl.dispose();
                  satCtrl.dispose();
                  valCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: Text(l.t('lightpad_select')),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _sliderWithInput({
    required String label,
    required double value,
    required double min,
    required double max,
    required TextEditingController controller,
    required ValueChanged<double> onSlider,
    required VoidCallback onField,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label),
            const Spacer(),
            SizedBox(
              width: 72,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => onField(),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onSlider,
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
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
