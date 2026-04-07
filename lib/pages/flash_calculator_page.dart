import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/aperture_settings.dart';
import '../services/app_localizations.dart';

class FlashCalculatorPage extends StatefulWidget {
  const FlashCalculatorPage({super.key});

  @override
  State<FlashCalculatorPage> createState() => _FlashCalculatorPageState();
}

class _FlashCalculatorPageState extends State<FlashCalculatorPage> {
  final TextEditingController _gnController = TextEditingController();
  final TextEditingController _isoController = TextEditingController(text: '100');

  List<double> _apertureStops = [];
  int _apertureIndex = 0;
  double _distance = 5.0; // meters
  int _powerIndex = 0; // default full power

  bool _calculatePower = true;

  static const List<String> _powerKeys = [
    '1', '1/2', '1/4', '1/8', '1/16', '1/32', '1/64',
  ];

  static const Map<String, double> _powerMap = {
    '1': 1.0,
    '1/2': 0.5,
    '1/4': 0.25,
    '1/8': 0.125,
    '1/16': 0.0625,
    '1/32': 0.03125,
    '1/64': 0.015625,
  };

  // Structured results: list of (label, value) pairs
  List<(String, String)> _resultItems = [];
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _loadApertureStops();
  }

  Future<void> _loadApertureStops() async {
    final maxAperture = await ApertureSettings.load();
    setState(() {
      _apertureStops = ApertureSettings.stopsFrom(maxAperture);
      // default to f/8 or closest available
      final idx = _apertureStops.indexOf(8.0);
      _apertureIndex = idx >= 0 ? idx : (_apertureStops.length ~/ 2);
    });
  }

  @override
  void dispose() {
    _gnController.dispose();
    _isoController.dispose();
    super.dispose();
  }

  double? _parse(String? s) => s == null ? null : double.tryParse(s);

  void _compute() {
    final l = AppLocalizations.of(context);
    final gn = _parse(_gnController.text);
    final distance = _distance;
    final fstop = _apertureStops[_apertureIndex];
    final iso = _parse(_isoController.text) ?? 100.0;
    final flashPowerKey = _powerKeys[_powerIndex];
    final powerFraction = _powerMap[flashPowerKey] ?? 1.0;

    if (gn == null) {
      setState(() {
        _resultItems = [];
        _errorText = l.t('flash_enter_gn');
      });
      return;
    }

    final gnIso = gn * (iso > 0 ? math.sqrt(iso / 100.0) : 1.0);

    if (_calculatePower) {
      final requiredGN = distance * fstop;
      final requiredPowerFraction = math.pow(requiredGN / gnIso, 2).toDouble();

      if (requiredPowerFraction >= 1.0) {
        setState(() {
          _resultItems = [];
          _errorText = l.t('flash_result_full_power');
        });
        return;
      }

      // Find the nearest standard power step
      String suggestedKey = _powerMap.keys.first;
      double suggestedVal = _powerMap[suggestedKey]!;
      double bestDiff = (suggestedVal - requiredPowerFraction).abs();
      for (final entry in _powerMap.entries) {
        final diff = (entry.value - requiredPowerFraction).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          suggestedKey = entry.key;
          suggestedVal = entry.value;
        }
      }

      final offset = suggestedVal - requiredPowerFraction;
      final offsetSign = offset >= 0 ? '+' : '-';
      final offsetAbs = offset.abs();
      final offsetStr = offsetAbs < 0.0005
          ? ''
          : ' ($offsetSign${offsetAbs.toStringAsFixed(3)})';

      final pct = (requiredPowerFraction * 100).clamp(0.0, 100.0);

      setState(() {
        _errorText = '';
        _resultItems = [
          (l.t('flash_result_power_label'),
              '${requiredPowerFraction.toStringAsFixed(3)} (\u2248 ${pct.toStringAsFixed(1)}%)'),
          (l.t('flash_result_suggested_label'),
              '$suggestedKey$offsetStr'),
        ];
      });
    } else {
      final gnAtPower = gnIso * math.sqrt(powerFraction);
      if (gnAtPower <= 0) {
        setState(() {
          _resultItems = [];
          _errorText = l.t('flash_result_invalid');
        });
        return;
      }
      final calcDistance = gnAtPower / fstop;
      setState(() {
        _errorText = '';
        _resultItems = [
          (l.t('flash_result_distance_label'),
              '${calcDistance.toStringAsFixed(2)} m'),
        ];
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1.0) {
      return '${(meters * 100).round()} cm';
    } else {
      return '${meters.toStringAsFixed(1)} m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    if (_apertureStops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.t('flash_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pop(context),
        ),
        title: Text(l.t('flash_title')),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 600;
          final inputArea = SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.t('flash_calculate_label'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(l.t('flash_power')),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(l.t('flash_distance')),
                      ),
                    ],
                    selected: {_calculatePower},
                    onSelectionChanged: (v) => setState(() {
                      _calculatePower = v.first;
                      _compute();
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Guide Number - text field
                  _labeledTextField(
                      l.t('flash_guide_number'), _gnController,
                      hint: l.t('flash_guide_number_hint'),
                      maxLength: 3,
                      allowDecimal: false),
                  const SizedBox(height: 16),

                  // F-stop / Aperture - slider
                  Text(l.t('flash_fstop'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                            'f/${_apertureStops[_apertureIndex]}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _apertureIndex.toDouble(),
                          min: 0,
                          max: (_apertureStops.length - 1).toDouble(),
                          divisions: _apertureStops.length - 1,
                          label:
                              'f/${_apertureStops[_apertureIndex]}',
                          onChanged: (v) {
                            setState(() => _apertureIndex = v.round());
                            _compute();
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('f/${_apertureStops.first}',
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                        Text('f/${_apertureStops.last}',
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Distance - logarithmic slider
                  Text(l.t('flash_distance'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                            _formatDistance(_distance),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Slider(
                          value: math.log(_distance) / math.ln10,
                          min: math.log(0.5) / math.ln10,
                          max: math.log(50.0) / math.ln10,
                          divisions: 100,
                          label: _formatDistance(_distance),
                          onChanged: !_calculatePower ? null : (v) {
                            setState(() => _distance = math.pow(10, v).toDouble());
                            _compute();
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0.5 m',
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                        Text('50 m',
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Flash Power - discrete slider
                  Text(l.t('flash_power'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                            _powerKeys[_powerIndex],
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _powerIndex.toDouble(),
                          min: 0,
                          max: (_powerKeys.length - 1).toDouble(),
                          divisions: _powerKeys.length - 1,
                          label: _powerKeys[_powerIndex],
                          onChanged: _calculatePower ? null : (v) {
                            setState(() => _powerIndex = v.round());
                            _compute();
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_powerKeys.first,
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                        Text(_powerKeys.last,
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ISO - text field
                  _labeledTextField(
                      l.t('flash_iso'), _isoController,
                      hint: l.t('flash_iso_hint'),
                      maxLength: 4,
                      allowDecimal: false),
                  const SizedBox(height: 16),

                ],
              ),
            );
          final resultArea = _buildResultArea(colorScheme, l);
          return wide
              ? Row(
                  children: [
                    Expanded(child: inputArea),
                    SizedBox(width: 300, child: resultArea),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: inputArea),
                    resultArea,
                  ],
                );
        },
      ),
    );
  }

  Widget _buildResultArea(ColorScheme colorScheme, AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: _resultItems.isNotEmpty
          ? Row(
              children: [
                for (int i = 0; i < _resultItems.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _resultItems[i].$1,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _resultItems[i].$2,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _errorText.isNotEmpty ? _errorText : l.t('flash_no_result'),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }

  Widget _labeledTextField(String label,
      TextEditingController controller,
      {String? hint, int? maxLength, bool allowDecimal = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant)),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _compute();
          },
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(
                decimal: allowDecimal),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(allowDecimal ? r'[0-9.]' : r'[0-9]')),
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength),
            ],
            decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                counterText: ''),
            maxLength: maxLength,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}
