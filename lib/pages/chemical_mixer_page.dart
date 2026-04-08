import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_localizations.dart';
import '../widgets/responsive_layout.dart';

class ChemicalMixerPage extends StatefulWidget {
  final String? prefillDilution;

  const ChemicalMixerPage({super.key, this.prefillDilution});

  @override
  State<ChemicalMixerPage> createState() => _ChemicalMixerPageState();
}

class _ChemicalMixerPageState extends State<ChemicalMixerPage> {
  bool _usePlus = true; // true = A+B (additive), false = A:B (ratio)
  final List<TextEditingController> _partCtrls = [];
  final _volumeCtrl = TextEditingController(text: '500');

  @override
  void initState() {
    super.initState();
    if (widget.prefillDilution != null) {
      _parseDilution(widget.prefillDilution!);
    } else {
      _partCtrls.add(TextEditingController(text: '1'));
      _partCtrls.add(TextEditingController(text: '1'));
    }
  }

  void _parseDilution(String raw) {
    // Extract numeric pattern like 1+50 or 1:25 or 1+1+100
    final plusMatch = RegExp(r'(\d+(?:\s*\+\s*\d+)+)').firstMatch(raw);
    final colonMatch = RegExp(r'(\d+(?:\s*:\s*\d+)+)').firstMatch(raw);

    String? matched;
    if (plusMatch != null) {
      matched = plusMatch.group(1);
      _usePlus = true;
    } else if (colonMatch != null) {
      matched = colonMatch.group(1);
      _usePlus = false;
    }

    if (matched != null) {
      final cleaned = matched.replaceAll(' ', '');
      final sep = _usePlus ? '+' : ':';
      final parts = cleaned.split(sep);
      for (final p in parts) {
        _partCtrls.add(TextEditingController(text: p));
      }
    } else {
      // No numeric pattern found — default
      _partCtrls.add(TextEditingController(text: '1'));
      _partCtrls.add(TextEditingController(text: '1'));
    }
  }

  @override
  void dispose() {
    for (final c in _partCtrls) {
      c.dispose();
    }
    _volumeCtrl.dispose();
    super.dispose();
  }

  void _addPart() {
    if (_partCtrls.length >= 4) return;
    setState(() {
      _partCtrls.insert(_partCtrls.length - 1,
          TextEditingController(text: '1'));
    });
  }

  void _removePart(int index) {
    if (_partCtrls.length <= 2) return;
    setState(() {
      _partCtrls[index].dispose();
      _partCtrls.removeAt(index);
    });
  }

  List<double>? _compute() {
    final parts = <double>[];
    for (final c in _partCtrls) {
      final v = double.tryParse(c.text);
      if (v == null || v < 0) return null;
      parts.add(v);
    }
    final volume = double.tryParse(_volumeCtrl.text);
    if (volume == null || volume <= 0) return null;

    if (_usePlus) {
      // A+B: total ratio = sum of all parts
      final totalRatio = parts.fold<double>(0, (a, b) => a + b);
      if (totalRatio <= 0) return null;
      return parts.map((p) => volume * p / totalRatio).toList();
    } else {
      // A:B: last number is total, preceding are portions of that total
      // e.g., 1:50 = 1 part stock in 50 total
      // e.g., 1:1:100 = 1 part A + 1 part B, total 100 parts,
      //        water = 100 - 1 - 1 = 98 parts
      final total = parts.last;
      if (total <= 0) return null;
      final stockParts = parts.sublist(0, parts.length - 1);
      final stockSum = stockParts.fold<double>(0, (a, b) => a + b);
      if (stockSum >= total) return null;
      final waterRatio = total - stockSum;
      final results = <double>[];
      for (final sp in stockParts) {
        results.add(volume * sp / total);
      }
      results.add(volume * waterRatio / total);
      return results;
    }
  }

  String _partLabel(int index, AppLocalizations l) {
    final count = _partCtrls.length;
    if (index == count - 1) {
      return l.t('mixer_water');
    }
    if (count == 2) {
      return l.t('mixer_stock');
    }
    // Multi-part: Part A, Part B, Part C
    final letter = String.fromCharCode(65 + index); // A, B, C
    return '${l.t('mixer_part')} $letter';
  }

  String _formatMl(double ml) {
    if (ml >= 100) return '${ml.toStringAsFixed(1)} ml';
    if (ml >= 10) return '${ml.toStringAsFixed(1)} ml';
    return '${ml.toStringAsFixed(2)} ml';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final results = _compute();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l.t('mixer_title')),
      ),
      body: CalculatorLayout(
        inputArea: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Notation toggle
                  Text(l.t('mixer_notation'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(l.t('mixer_plus')),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(l.t('mixer_ratio')),
                      ),
                    ],
                    selected: {_usePlus},
                    onSelectionChanged: (v) =>
                        setState(() => _usePlus = v.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _usePlus
                        ? l.t('mixer_plus_desc')
                        : l.t('mixer_ratio_desc'),
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  // Parts
                  Text(l.t('mixer_parts'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  ...List.generate(_partCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(_partLabel(i, l),
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _partCtrls[i],
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.]')),
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_partCtrls.length > 2)
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  size: 20,
                                  color: colorScheme.error),
                              onPressed: () => _removePart(i),
                              visualDensity: VisualDensity.compact,
                            )
                          else
                            const SizedBox(width: 40),
                        ],
                      ),
                    );
                  }),
                  if (_partCtrls.length < 4)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addPart,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l.t('mixer_add_part')),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Target volume
                  Text(l.t('mixer_volume'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _volumeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d.]')),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: 'ml',
                      hintText: l.t('mixer_volume_hint'),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
        resultArea: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: results != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.t('mixer_result'),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      ...List.generate(results.length, (i) {
                        final label = _usePlus
                            ? _partLabel(i, l)
                            : (i < _partCtrls.length - 1
                                ? _partLabel(i, l)
                                : l.t('mixer_water'));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label,
                                  style: const TextStyle(fontSize: 14)),
                              Text(_formatMl(results[i]),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l.t('mixer_total'),
                              style: const TextStyle(fontSize: 14)),
                          Text(
                              '${results.fold<double>(0, (a, b) => a + b).toStringAsFixed(1)} ml',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(l.t('mixer_no_result'),
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant)),
                    ),
                  ),
          ),
      ),
    );
  }
}
