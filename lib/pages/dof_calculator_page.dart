import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/aperture_settings.dart';
import '../widgets/responsive_layout.dart';
import '../services/app_localizations.dart';

class DofCalculatorPage extends StatefulWidget {
  const DofCalculatorPage({super.key});

  @override
  State<DofCalculatorPage> createState() => _DofCalculatorPageState();
}

class _DofCalculatorPageState extends State<DofCalculatorPage> {
  final TextEditingController _focalLengthController =
      TextEditingController();
  final TextEditingController _cocController =
      TextEditingController(text: '0.03');

  double _subjectDistance = 5.0; // meters
  List<double> _apertureStops = [];
  int _apertureIndex = 0;

  // Structured results
  String _hyperfocalValue = '';
  String _rangeValue = '';
  String _errorText = '';

  bool get _hasResult => _hyperfocalValue.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadApertureStops();
  }

  Future<void> _loadApertureStops() async {
    final maxAperture = await ApertureSettings.load();
    setState(() {
      _apertureStops = ApertureSettings.stopsFrom(maxAperture);
      final idx = _apertureStops.indexOf(8.0);
      _apertureIndex = idx >= 0 ? idx : (_apertureStops.length ~/ 2);
    });
  }

  @override
  void dispose() {
    _focalLengthController.dispose();
    _cocController.dispose();
    super.dispose();
  }

  void _compute() {
    final l = AppLocalizations.of(context);
    final focalLength =
        double.tryParse(_focalLengthController.text);
    final coc = double.tryParse(_cocController.text) ?? 0.03;
    final aperture = _apertureStops[_apertureIndex];
    final s = _subjectDistance;

    if (focalLength == null || focalLength <= 0) {
      setState(() {
        _hyperfocalValue = '';
        _rangeValue = '';
        _errorText = l.t('dof_enter_focal_length');
      });
      return;
    }
    if (coc <= 0) {
      setState(() {
        _hyperfocalValue = '';
        _rangeValue = '';
        _errorText = l.t('dof_coc_positive');
      });
      return;
    }

    final f = focalLength; // mm
    final n = aperture;
    final c = coc; // mm
    final sMm = s * 1000.0; // convert subject distance to mm

    // H = (f^2 / (N * c)) + f
    final h = (f * f / (n * c)) + f;

    // DN = (H * s) / (H + (s - f))
    final dnMm = (h * sMm) / (h + (sMm - f));

    // DF = (H * s) / (H - (s - f))
    final dfDenom = h - (sMm - f);

    final dn = dnMm / 1000.0; // back to meters

    final hyperfocal = (h / 1000.0).toStringAsFixed(2);

    if (dfDenom <= 0) {
      // Far limit is at infinity
      setState(() {
        _errorText = '';
        _hyperfocalValue = '$hyperfocal m';
        _rangeValue = '${dn.toStringAsFixed(2)} m - \u221e';
      });
      return;
    }

    final dfMm = (h * sMm) / dfDenom;
    final df = dfMm / 1000.0;

    setState(() {
      _errorText = '';
      _hyperfocalValue = '$hyperfocal m';
      _rangeValue = '${dn.toStringAsFixed(2)} - ${df.toStringAsFixed(2)} m';
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1.0) {
      return '${(meters * 100).round()} cm';
    } else if (meters >= 100) {
      return '${meters.round()} m';
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
        appBar: AppBar(title: Text(l.t('dof_title'))),
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
        title: Text(l.t('dof_title')),
      ),
      body: CalculatorLayout(
        inputArea: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Focal Length - input box
                  _labeledTextField(l.t('dof_focal_length'),
                      _focalLengthController,
                      hint: l.t('dof_focal_length_hint'),
                      maxLength: 4,
                      allowDecimal: false),
                  const SizedBox(height: 16),

                  // Aperture - slider
                  Text(l.t('dof_aperture'),
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

                  // Subject Distance - slider (logarithmic)
                  Text(l.t('dof_subject_distance'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                            _formatDistance(_subjectDistance),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Slider(
                          value: math.log(_subjectDistance) /
                              math.ln10,
                          min: math.log(0.1) / math.ln10,
                          max: math.log(100.0) / math.ln10,
                          divisions: 100,
                          label:
                              _formatDistance(_subjectDistance),
                          onChanged: (v) {
                            setState(() => _subjectDistance = math.pow(10, v).toDouble());
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
                        Text('0.1 m',
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                        Text('100 m',
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Circle of Confusion - input box with default
                  _labeledTextField(
                      l.t('dof_coc'), _cocController,
                      hint: l.t('dof_coc_hint'),
                      maxLength: 6),

                  const SizedBox(height: 16),

                ],
              ),
            ),
        resultArea: _buildResultArea(colorScheme, l),
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
      child: _hasResult
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.t('dof_hyperfocal_label'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hyperfocalValue,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.t('dof_range_label'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _rangeValue,
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
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _errorText.isNotEmpty ? _errorText : l.t('dof_no_result'),
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
                counterText: ''),
            maxLength: maxLength,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}
