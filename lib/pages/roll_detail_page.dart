import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/film_storage.dart';
import '../services/import_export_service.dart';
import '../services/light_meter_constants.dart';
import '../services/app_localizations.dart';
import 'shot_page.dart';

class RollDetailPage extends StatefulWidget {
  final String rollId;
  const RollDetailPage({super.key, required this.rollId});

  @override
  State<RollDetailPage> createState() => _RollDetailPageState();
}

class _RollDetailPageState extends State<RollDetailPage> {
  Map<String, dynamic>? _roll;
  late TextEditingController _brandCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _isoCtrl;
  late TextEditingController _commentCtrl;
  Timer? _saveTimer;
  bool _deleted = false;
  double _ec = 0.0;
  double _ecStep = 1 / 3;

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _isoCtrl = TextEditingController();
    _commentCtrl = TextEditingController();
    _loadRoll();
    _loadEcStep();
  }

  Future<void> _loadEcStep() async {
    final step = await ExposureStepSettings.load();
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

  Future<void> _loadRoll() async {
    final roll = await FilmStorage.loadRoll(widget.rollId);
    if (roll != null) {
      // Sort shots on load
      final shots = (roll['shots'] as List).cast<Map<String, dynamic>>();
      shots.sort(_compareShots);
      setState(() {
        _roll = roll;
        _brandCtrl.text = roll['brand'] as String? ?? '';
        _modelCtrl.text = roll['model'] as String? ?? '';
        _isoCtrl.text = roll['sensitivity'] as String? ?? '';
        _commentCtrl.text = roll['comments'] as String? ?? '';
        _ec = (roll['ec'] as num?)?.toDouble() ?? 0.0;
        _ec = (_ec / _ecStep).roundToDouble() * _ecStep;
      });
    }
  }

  void _onFieldChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveRoll();
    });
  }

  void _saveRoll() {
    if (_roll != null && !_deleted) {
      _roll!['brand'] = _brandCtrl.text;
      _roll!['model'] = _modelCtrl.text;
      _roll!['sensitivity'] = _isoCtrl.text;
      _roll!['ec'] = _ec;
      _roll!['comments'] = _commentCtrl.text;
      FilmStorage.updateRoll(_roll!);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveRoll();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _isoCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _shots {
    if (_roll == null) return [];
    return (_roll!['shots'] as List)
        .cast<Map<String, dynamic>>();
  }

  /// Compare two shots by sequence number, then by createdAt timestamp.
  static int _compareShots(Map<String, dynamic> a, Map<String, dynamic> b) {
    final seqA = a['sequence'] as int? ?? 0;
    final seqB = b['sequence'] as int? ?? 0;
    if (seqA != seqB) return seqA.compareTo(seqB);
    final tsA = a['createdAt'] as int? ?? 0;
    final tsB = b['createdAt'] as int? ?? 0;
    return tsA.compareTo(tsB);
  }

  /// Move a single shot to its sorted position (efficient single-element reposition).
  void _repositionShot(Map<String, dynamic> shot) {
    final shots = _shots;
    shots.remove(shot);
    // Find insertion point
    int insertAt = shots.length;
    for (int i = 0; i < shots.length; i++) {
      if (_compareShots(shot, shots[i]) <= 0) {
        insertAt = i;
        break;
      }
    }
    shots.insert(insertAt, shot);
  }

  Future<void> _addShot() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ShotPage(
          defaultSequence: _shots.isEmpty ? 1 : _shots.map((s) => s['sequence'] as int).reduce((a, b) => a > b ? a : b) + 1,
        ),
      ),
    );
    if (result != null && _roll != null) {
      _shots.add(result);
      _repositionShot(result);
      await FilmStorage.updateRoll(_roll!);
      setState(() {});
    }
  }

  Future<void> _editShot(int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ShotPage(
          defaultSequence: _shots[index]['sequence'] as int,
          existingShot: _shots[index],
        ),
      ),
    );
    if (result != null && _roll != null) {
      _shots[index] = result;
      _repositionShot(result);
      await FilmStorage.updateRoll(_roll!);
      setState(() {});
    }
  }


  Future<void> _shareRoll() async {
    if (_roll == null) return;
    final l = AppLocalizations.of(context);
    final shots = _shots;
    if (shots.isEmpty) {
      // No shots — export roll without shot selection
      try {
        final path = await FilmStorage.exportRoll(_roll!);
        final name = '${_roll!['brand']} ${_roll!['model']}'.trim();
        await ImportExportService.shareFile(path, name);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('export_error'))),
          );
        }
      }
      return;
    }

    // Shot selection dialog
    final selected = Set<String>.from(
        shots.map((s) => s['uuid'] as String));
    final confirmed = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(l.t('share_select_shots')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setDialogState(() {
                            selected.addAll(
                                shots.map((s) => s['uuid'] as String));
                          }),
                          child: Text(l.t('share_select_all')),
                        ),
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => selected.clear()),
                          child: Text(l.t('share_select_none')),
                        ),
                      ],
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: shots.length,
                        itemBuilder: (_, i) {
                          final shot = shots[i];
                          final uuid = shot['uuid'] as String;
                          final seq = shot['sequence'] as int;
                          final comment =
                              shot['comment'] as String? ?? '';
                          return CheckboxListTile(
                            value: selected.contains(uuid),
                            onChanged: (v) => setDialogState(() {
                              if (v == true) {
                                selected.add(uuid);
                              } else {
                                selected.remove(uuid);
                              }
                            }),
                            title: Text('#$seq'),
                            subtitle: comment.isNotEmpty
                                ? Text(comment,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)
                                : null,
                            dense: true,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.t('share_shot_count',
                          {'count': selected.length.toString()}),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.t('import_cancel')),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selected),
                  child: Text(l.t('share_share')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == null || confirmed.isEmpty || !mounted) return;

    try {
      final path = await FilmStorage.exportRoll(_roll!,
          selectedShotUuids: confirmed.toList());
      final name = '${_roll!['brand']} ${_roll!['model']}'.trim();
      await ImportExportService.shareFile(path, name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('export_error'))),
        );
      }
    }
  }

  Future<void> _deleteRoll() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('roll_delete_title')),
        content: Text(l.t('roll_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('roll_cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('roll_delete')),
          ),
        ],
      ),
    );
    if (confirm == true && _roll != null) {
      _deleted = true;
      await FilmStorage.deleteRoll(_roll!['id'] as String);
      if (mounted) Navigator.pop(context);
    }
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    if (_roll == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.t('roll_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${_roll!['brand']} ${_roll!['model']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareRoll,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteRoll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addShot,
        child: const Icon(Icons.add_a_photo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Roll info fields
            Text(l.t('film_brand'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _brandCtrl,
              onChanged: (_) => _onFieldChanged(),
              decoration: InputDecoration(
                hintText: l.t('film_brand_hint'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(l.t('film_model'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _modelCtrl,
              onChanged: (_) => _onFieldChanged(),
              decoration: InputDecoration(
                hintText: l.t('film_model_hint'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // ISO & Exposure Compensation side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ISO (half width)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('film_sensitivity'),
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _isoCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _onFieldChanged(),
                        decoration: InputDecoration(
                          hintText: l.t('film_sensitivity_hint'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Exposure Compensation (half width)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('roll_ec'),
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(_ecLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Slider(
                              value: _ec,
                              min: -3.0,
                              max: 3.0,
                              divisions: (6 / _ecStep).round(),
                              label: _ecLabel,
                              onChanged: (v) {
                                setState(() {
                                  _ec = (v / _ecStep).roundToDouble() * _ecStep;
                                });
                                _onFieldChanged();
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
            // Comments
            Text(l.t('roll_comments'),
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              onChanged: (_) => _onFieldChanged(),
              decoration: InputDecoration(
                hintText: l.t('roll_comments_hint'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Shots header
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(l.t('roll_shots_header', {'count': _shots.length.toString()}),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall),
                TextButton.icon(
                  onPressed: _addShot,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.t('roll_add_shot')),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Shots grid
            _shots.isEmpty
                ? Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                              vertical: 32),
                      child: Text(l.t('roll_no_shots'),
                          style: TextStyle(
                              color: colorScheme
                                  .onSurfaceVariant)),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _shots.length,
                    itemBuilder: (context, index) {
                      return _shotTile(index);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _shotTile(int index) {
    final shot = _shots[index];
    final imagePath = shot['imagePath'] as String?;
    final seq = shot['sequence'] as int;
    final colorScheme = Theme.of(context).colorScheme;

    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();

    Widget imageWidget;
    if (hasImage) {
      imageWidget = Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      imageWidget = Center(
        child: Icon(Icons.photo_outlined,
            size: 36,
            color: colorScheme.onSurfaceVariant),
      );
    }

    return GestureDetector(
      onTap: () => _editShot(index),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surface
                        .withAlpha(200),
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                  child: Text('#$seq',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
