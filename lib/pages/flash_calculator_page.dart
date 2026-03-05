import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/aperture_settings.dart';

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

  String _resultText = '';

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
    final gn = _parse(_gnController.text);
    final distance = _distance;
    final fstop = _apertureStops[_apertureIndex];
    final iso = _parse(_isoController.text) ?? 100.0;
    final flashPowerKey = _powerKeys[_powerIndex];
    final powerFraction = _powerMap[flashPowerKey] ?? 1.0;

    if (gn == null) {
      setState(() => _resultText = 'Enter a Guide Number.');
      return;
    }

    final gnIso = gn * (iso > 0 ? math.sqrt(iso / 100.0) : 1.0);

    if (_calculatePower) {
      final requiredGN = distance * fstop;
      final requiredPowerFraction = math.pow(requiredGN / gnIso, 2).toDouble();

      if (requiredPowerFraction >= 1.0) {
        setState(() => _resultText = 'Required power: >= 1. Full power required.');
        return;
      }

      // Find the nearest standard power step (closest by absolute difference)
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

      // Show signed offset (suggested - required), formatted
      final offset = suggestedVal - requiredPowerFraction;
      final offsetSign = offset >= 0 ? '+' : '-';
      final offsetAbs = offset.abs();

      final pct = (requiredPowerFraction * 100).clamp(0.0, 100.0);
      setState(() {
        final offsetStr = offsetAbs < 0.0005
            ? ''
            : ' ($offsetSign${offsetAbs.toStringAsFixed(3)})';
        _resultText =
            'Required power fraction: ${requiredPowerFraction.toStringAsFixed(3)}'
            ' (\u2248 ${pct.toStringAsFixed(1)}%).\n'
            'Flash Power Result: $suggestedKey$offsetStr';
      });
    } else {
      final gnAtPower = gnIso * math.sqrt(powerFraction);
      if (gnAtPower <= 0) {
        setState(() => _resultText = 'Invalid GN or power value.');
        return;
      }
      final calcDistance = gnAtPower / fstop;
      setState(() => _resultText =
          'Calculated distance: ${calcDistance.toStringAsFixed(2)}m'
          ' (using power $flashPowerKey)');
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

    if (_apertureStops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flash Calculator')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/'),
        ),
        title: const Text('Flash Calculator'),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Flash Calculator',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_calculatePower
                    ? 'Mode: Calculate Flash Power'
                    : 'Mode: Calculate Distance'),
                Switch(
                  value: _calculatePower,
                  onChanged: (v) => setState(() {
                    _calculatePower = v;
                    _compute();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Guide Number - text field
            _labeledTextField(
                'Guide Number (GN)', _gnController,
                hint: 'e.g. 60'),
            const SizedBox(height: 16),

            // F-stop / Aperture - slider
            Text('F-stop / Aperture',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                    'f/${_apertureStops[_apertureIndex]}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _apertureIndex.toDouble(),
                    min: 0,
                    max: (_apertureStops.length - 1).toDouble(),
                    divisions: _apertureStops.length - 1,
                    label:
                        'f/${_apertureStops[_apertureIndex]}',
                    onChanged: (v) => setState(() {
                      _apertureIndex = v.round();
                    }),
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
            Text('Distance',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 72,
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
                    onChanged: !_calculatePower ? null : (v) => setState(() {
                      _distance =
                          math.pow(10, v).toDouble();
                    }),
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
            Text('Flash Power',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                    _powerKeys[_powerIndex],
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _powerIndex.toDouble(),
                    min: 0,
                    max: (_powerKeys.length - 1).toDouble(),
                    divisions: _powerKeys.length - 1,
                    label: _powerKeys[_powerIndex],
                    onChanged: _calculatePower ? null : (v) => setState(() {
                      _powerIndex = v.round();
                    }),
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
                'ISO / Sensitivity', _isoController,
                hint: 'e.g. 100'),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _compute,
              icon: const Icon(Icons.calculate),
              label: const Text('Compute'),
            ),
            const SizedBox(height: 12),

            Text('Result',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                  _resultText.isEmpty
                      ? 'No result yet'
                      : _resultText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeledTextField(String label,
      TextEditingController controller,
      {String? hint}) {
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
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true),
          decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
