import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_localizations.dart';
import '../services/recipe_storage.dart';

class RecipeEditPage extends StatefulWidget {
  final Map<String, dynamic>? existingRecipe;

  const RecipeEditPage({super.key, this.existingRecipe});

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  late TextEditingController _filmStockCtrl;
  late TextEditingController _developerCtrl;
  late TextEditingController _dilutionCtrl;
  double? _baseTemp = 20.0; // null = N/A (no temp compensation)
  String _processType = 'bw_neg';
  late TextEditingController _notesCtrl;
  late List<Map<String, dynamic>> _steps;
  bool _redSafelight = false;

  bool get _isEditing => widget.existingRecipe != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRecipe;
    _filmStockCtrl = TextEditingController(
        text: r?['filmStock'] as String? ?? '');
    _developerCtrl = TextEditingController(
        text: r?['developer'] as String? ?? '');
    _dilutionCtrl = TextEditingController(
        text: r?['dilution'] as String? ?? '');
    _notesCtrl = TextEditingController(
        text: r?['notes'] as String? ?? '');
    _processType = r?['processType'] as String? ?? 'bw_neg';
    if (r != null && r.containsKey('baseTemp')) {
      _baseTemp = (r['baseTemp'] as num?)?.toDouble();
    }
    _redSafelight = r?['redSafelight'] as bool? ?? false;
    if (r != null && r['steps'] != null) {
      _steps = (r['steps'] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
    } else {
      _steps = [];
    }
  }

  @override
  void dispose() {
    _filmStockCtrl.dispose();
    _developerCtrl.dispose();
    _dilutionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addStep(String type) {
    setState(() {
      final step = <String, dynamic>{'type': type, 'time': 60};
      if (type == 'develop' || type == 'custom') {
        step['label'] = '';
        step['agitation'] = <String, dynamic>{
          'method': 'hand',
          'initialDuration': 30,
          'period': 60,
          'duration': 10,
        };
      }
      if (type == 'wash') step['speedWash'] = false;
      _steps.add(step);
    });
  }

  void _removeStep(int index) {
    setState(() => _steps.removeAt(index));
  }

  void _showAddStepSheet() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.science),
              title: Text(l.t('recipe_step_develop')),
              onTap: () { Navigator.pop(ctx); _addStep('develop'); },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(l.t('recipe_step_stop')),
              onTap: () { Navigator.pop(ctx); _addStep('stop'); },
            ),
            ListTile(
              leading: const Icon(Icons.lock_clock),
              title: Text(l.t('recipe_step_fix')),
              onTap: () { Navigator.pop(ctx); _addStep('fix'); },
            ),
            ListTile(
              leading: const Icon(Icons.water_drop),
              title: Text(l.t('recipe_step_wash')),
              onTap: () { Navigator.pop(ctx); _addStep('wash'); },
            ),
            ListTile(
              leading: const Icon(Icons.opacity),
              title: Text(l.t('recipe_step_rinse')),
              onTap: () { Navigator.pop(ctx); _addStep('rinse'); },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.t('recipe_step_custom')),
              onTap: () { Navigator.pop(ctx); _addStep('custom'); },
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final filmStock = _filmStockCtrl.text.trim();
    if (filmStock.isEmpty) return;
    final recipe = <String, dynamic>{
      'id': widget.existingRecipe?['id'] ??
          RecipeStorage.newUuid(),
      'createdAt': widget.existingRecipe?['createdAt'] ??
          DateTime.now().millisecondsSinceEpoch,
      'filmStock': filmStock,
      'developer': _developerCtrl.text.trim(),
      'dilution': _dilutionCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'processType': _processType,
      'baseTemp': _baseTemp,
      'redSafelight': _redSafelight,
      'steps': _steps,
    };
    Navigator.pop(context, recipe);
  }

  Widget _buildTimeInput(int seconds, ValueChanged<int> onChanged) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final minCtrl = TextEditingController(text: m.toString().padLeft(2, '0'));
    final secCtrl = TextEditingController(text: s.toString().padLeft(2, '0'));

    void update() {
      final mins = int.tryParse(minCtrl.text) ?? 0;
      final secs = (int.tryParse(secCtrl.text) ?? 0).clamp(0, 59);
      onChanged(mins * 60 + secs);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          child: TextField(
            controller: minCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'mm',
            ),
            onChanged: (_) => update(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          width: 64,
          child: TextField(
            controller: secCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'ss',
            ),
            onChanged: (_) => update(),
          ),
        ),
      ],
    );
  }

  IconData _stepIcon(String type) {
    switch (type) {
      case 'develop': return Icons.science;
      case 'stop': return Icons.stop_circle_outlined;
      case 'fix': return Icons.lock_clock;
      case 'wash': return Icons.water_drop;
      case 'rinse': return Icons.opacity;
      case 'custom': return Icons.info_outline;
      default: return Icons.help_outline;
    }
  }

  String _stepLabel(String type, AppLocalizations l) {
    switch (type) {
      case 'develop': return l.t('recipe_step_develop');
      case 'stop': return l.t('recipe_step_stop');
      case 'fix': return l.t('recipe_step_fix');
      case 'wash': return l.t('recipe_step_wash');
      case 'rinse': return l.t('recipe_step_rinse');
      case 'custom': return l.t('recipe_step_custom');
      default: return type;
    }
  }

  List<Widget> _buildAgitationUI(
      Map<String, dynamic> step, AppLocalizations l, ColorScheme colorScheme) {
    final agitation = step['agitation'] as Map<String, dynamic>? ??
        <String, dynamic>{
          'method': 'hand',
          'initialDuration': 30,
          'period': 60,
          'duration': 10,
        };
    step['agitation'] = agitation;
    final method = agitation['method'] as String? ?? 'hand';
    final labelStyle =
        TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant);

    return [
      // Agitation method selector
      Text(l.t('recipe_agitation'),
          style: TextStyle(
              fontSize: 12, color: colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      SegmentedButton<String>(
        segments: [
          ButtonSegment<String>(
            value: 'hand',
            label: Text(l.t('recipe_agitation_hand'),
                style: const TextStyle(fontSize: 12)),
            icon: const Icon(Icons.back_hand_outlined, size: 16),
          ),
          ButtonSegment<String>(
            value: 'rolling',
            label: Text(l.t('recipe_agitation_rolling'),
                style: const TextStyle(fontSize: 12)),
            icon: const Icon(Icons.rotate_right, size: 16),
          ),
        ],
        selected: {method},
        onSelectionChanged: (v) =>
            setState(() => agitation['method'] = v.first),
      ),
      const SizedBox(height: 8),
      if (method == 'hand') ...[
        // Initial agitation duration
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.t('recipe_agitation_initial'), style: labelStyle),
                  const SizedBox(height: 4),
                  _buildTimeInput(
                    agitation['initialDuration'] as int? ?? 30,
                    (v) => agitation['initialDuration'] = v,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Period and agitate duration
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.t('recipe_agitation_period'), style: labelStyle),
                  const SizedBox(height: 4),
                  _buildTimeInput(
                    agitation['period'] as int? ?? 60,
                    (v) => agitation['period'] = v,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.t('recipe_agitation_duration'), style: labelStyle),
                  const SizedBox(height: 4),
                  _buildTimeInput(
                    agitation['duration'] as int? ?? 10,
                    (v) => agitation['duration'] = v,
                  ),
                ],
              ),
            ),
          ],
        ),
      ] else ...[
        Row(
          children: [
            Text(l.t('recipe_agitation_speed'), style: labelStyle),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: TextEditingController(
                    text: (agitation['speed'] as int? ?? 60).toString()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  suffixText: l.t('recipe_agitation_rpm'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) =>
                    agitation['speed'] = int.tryParse(v) ?? 60,
              ),
            ),
          ],
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing
            ? l.t('recipe_edit_title')
            : l.t('recipe_new_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _filmStockCtrl.text.trim().isNotEmpty ? _save : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Film stock
            Text(l.t('recipe_film_stock'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _filmStockCtrl,
              decoration: InputDecoration(
                hintText: l.t('recipe_film_stock_hint'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Developer
            Text(l.t('recipe_developer'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _developerCtrl,
              decoration: InputDecoration(
                hintText: l.t('recipe_developer_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Dilution
            Text(l.t('recipe_dilution'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _dilutionCtrl,
              decoration: InputDecoration(
                hintText: l.t('recipe_dilution_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Process type
            Text(l.t('recipe_process_type'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _processType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: 'bw_neg', child: Text(l.t('process_bw_neg'))),
                DropdownMenuItem(value: 'bw_pos', child: Text(l.t('process_bw_pos'))),
                DropdownMenuItem(value: 'color_neg', child: Text(l.t('process_color_neg'))),
                DropdownMenuItem(value: 'color_pos', child: Text(l.t('process_color_pos'))),
              ],
              onChanged: (v) => setState(() => _processType = v ?? 'bw_neg'),
            ),
            const SizedBox(height: 16),

            // Notes
            Text(l.t('recipe_notes'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: l.t('recipe_notes_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Base temperature
            Text(l.t('recipe_base_temp'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            SegmentedButton<double?>(
              segments: [
                ButtonSegment<double?>(
                  value: null,
                  label: Text(l.t('recipe_temp_na')),
                ),
                const ButtonSegment<double?>(
                  value: 20.0,
                  label: Text('20\u00b0C'),
                ),
                const ButtonSegment<double?>(
                  value: 24.0,
                  label: Text('24\u00b0C'),
                ),
              ],
              selected: {_baseTemp},
              onSelectionChanged: (v) =>
                  setState(() => _baseTemp = v.first),
            ),
            const SizedBox(height: 16),

            // Red safelight toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.t('recipe_red_safelight'),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                Switch(
                  value: _redSafelight,
                  onChanged: (v) => setState(() => _redSafelight = v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Steps header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.t('recipe_steps'),
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _showAddStepSheet,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.t('recipe_add_step')),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_steps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(l.t('recipe_no_steps'),
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ),
              ),

            // Step list
            ...List.generate(_steps.length, (i) {
              final step = _steps[i];
              final type = step['type'] as String;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_stepIcon(type),
                              color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('${i + 1}. ${_stepLabel(type, l)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface)),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 20, color: colorScheme.error),
                            onPressed: () => _removeStep(i),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (type == 'develop' || type == 'custom') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(
                              text: step['label'] as String? ?? ''),
                          decoration: InputDecoration(
                            hintText: l.t('recipe_step_label_hint'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => step['label'] = v,
                        ),
                        const SizedBox(height: 8),
                        ..._buildAgitationUI(step, l, colorScheme),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(l.t('recipe_step_time'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 8),
                          _buildTimeInput(
                            step['time'] as int? ?? 60,
                            (v) => step['time'] = v,
                          ),
                        ],
                      ),
                      if (type == 'wash') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(l.t('recipe_speed_wash'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant)),
                            const Spacer(),
                            Switch(
                              value: step['speedWash'] as bool? ?? false,
                              onChanged: (v) =>
                                  setState(() => step['speedWash'] = v),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
