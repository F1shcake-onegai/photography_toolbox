import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/aperture_settings.dart';

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
    final focalLength =
        double.tryParse(_focalLengthController.text);
    final coc = double.tryParse(_cocController.text) ?? 0.03;
    final aperture = _apertureStops[_apertureIndex];
    final s = _subjectDistance;

    if (focalLength == null || focalLength <= 0) {
      setState(
          () => _resultText = 'Enter a valid focal length.');
      return;
    }
    if (coc <= 0) {
      setState(() =>
          _resultText = 'Circle of confusion must be positive.');
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

    if (dfDenom <= 0) {
      // Far limit is at infinity
      setState(() {
        _resultText =
            'Hyperfocal distance: '
            '${(h / 1000.0).toStringAsFixed(2)} m\n'
            'Near limit: ${dn.toStringAsFixed(2)} m\n'
            'Far limit: Infinity\n'
            'Total DOF: Infinity';
      });
      return;
    }

    final dfMm = (h * sMm) / dfDenom;
    final df = dfMm / 1000.0;
    final dof = df - dn;

    setState(() {
      _resultText =
          'Hyperfocal distance: '
          '${(h / 1000.0).toStringAsFixed(2)} m\n'
          'Near limit: ${dn.toStringAsFixed(2)} m\n'
          'Far limit: ${df.toStringAsFixed(2)} m\n'
          'Total DOF: ${dof.toStringAsFixed(2)} m';
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

    if (_apertureStops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Depth of Field')),
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
        title: const Text('Depth of Field'),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Depth of Field Calculator',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            // Focal Length - input box
            _labeledTextField('Focal Length (mm)',
                _focalLengthController,
                hint: 'e.g. 50'),
            const SizedBox(height: 16),

            // Aperture - slider
            Text('Aperture',
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

            // Subject Distance - slider (logarithmic)
            Text('Subject Distance',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 72,
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
                    onChanged: (v) => setState(() {
                      _subjectDistance =
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
                'Circle of Confusion (mm)', _cocController,
                hint: '0.03'),

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
              child: Text(_resultText.isEmpty
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
