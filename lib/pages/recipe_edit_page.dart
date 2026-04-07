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
  final Set<int> _expandedAgitation = {};
  bool _redSafelight = false;

  final List<FocusNode> _trimFocusNodes = [];
  FocusNode _makeTrimNode(TextEditingController ctrl) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) {
        final trimmed = ctrl.text.trim();
        if (trimmed != ctrl.text) ctrl.text = trimmed;
      }
    });
    _trimFocusNodes.add(node);
    return node;
  }
  late final FocusNode _filmStockFocus;
  late final FocusNode _developerFocus;
  late final FocusNode _dilutionFocus;
  late final FocusNode _notesFocus;

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
    _filmStockFocus = _makeTrimNode(_filmStockCtrl);
    _developerFocus = _makeTrimNode(_developerCtrl);
    _dilutionFocus = _makeTrimNode(_dilutionCtrl);
    _notesFocus = _makeTrimNode(_notesCtrl);
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
    for (final n in _trimFocusNodes) { n.dispose(); }
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
      if (type == 'develop' || type == 'custom') {
        _expandedAgitation.add(_steps.length - 1);
      }
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      _expandedAgitation.clear();
    });
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

  List<String> _validate(AppLocalizations l) {
    final errors = <String>[];
    if (_filmStockCtrl.text.trim().isEmpty) {
      errors.add(l.t('recipe_valid_film_stock'));
    }
    if (_developerCtrl.text.trim().isEmpty) {
      errors.add(l.t('recipe_valid_developer'));
    }
    if (_dilutionCtrl.text.trim().isEmpty) {
      errors.add(l.t('recipe_valid_dilution'));
    }
    if (_steps.isEmpty) {
      errors.add(l.t('recipe_valid_steps'));
    }
    for (int i = 0; i < _steps.length; i++) {
      final t = _steps[i]['time'] as int? ?? 0;
      if (t <= 0) {
        errors.add(l.t('recipe_valid_step_time_zero',
            {'step': (i + 1).toString()}));
      }
    }
    return errors;
  }

  Map<String, dynamic> _buildRecipe() {
    return <String, dynamic>{
      'id': widget.existingRecipe?['id'] ??
          RecipeStorage.newUuid(),
      'createdAt': widget.existingRecipe?['createdAt'] ??
          DateTime.now().millisecondsSinceEpoch,
      'filmStock': _filmStockCtrl.text.trim(),
      'developer': _developerCtrl.text.trim(),
      'dilution': _dilutionCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'processType': _processType,
      'baseTemp': _baseTemp,
      'redSafelight': _redSafelight,
      'steps': _steps,
    };
  }

  void _showValidationErrors(List<String> errors) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.t('recipe_valid_title'),
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              ...errors.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('\u2022 ', style: TextStyle(fontSize: 14)),
                        Expanded(child: Text(e)),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.t('recipe_valid_ok')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _autoSaveAndPop() {
    final l = AppLocalizations.of(context);
    final errors = _validate(l);
    if (errors.isNotEmpty) {
      _showValidationErrors(errors);
      return;
    }
    Navigator.pop(context, _buildRecipe());
  }

  void _saveNewAndPop() {
    final l = AppLocalizations.of(context);
    final errors = _validate(l);
    if (errors.isNotEmpty) {
      _showValidationErrors(errors);
      return;
    }
    Navigator.pop(context, _buildRecipe());
  }

  Future<void> _confirmDiscardAndPop() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('recipe_discard_title')),
        content: Text(l.t('recipe_discard_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('recipe_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('recipe_discard')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteRecipe() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('recipe_delete_title')),
        content: Text(l.t('recipe_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('recipe_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('recipe_delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, {'_deleted': true, 'id': widget.existingRecipe?['id']});
    }
  }

  Widget _buildTimeField(TextEditingController controller,
      {String hint = '00', int max = 99, VoidCallback? onCommit}) {
    final cs = Theme.of(context).colorScheme;
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        final v = (int.tryParse(controller.text) ?? 0).clamp(0, max);
        controller.text = v.toString().padLeft(2, '0');
        onCommit?.call();
      }
    });
    return SizedBox(
      width: 36,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 2,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
          height: 1,
        ),
        decoration: InputDecoration(
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
          isDense: true,
          counterText: '',
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(100)),
        ),
      ),
    );
  }

  Widget _buildNumericField(String initialValue,
      {int max = 999, String? suffix, ValueChanged<int>? onCommit}) {
    final cs = Theme.of(context).colorScheme;
    final maxDigits = max.toString().length;
    final ctrl = TextEditingController(text: initialValue);
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        final v = (int.tryParse(ctrl.text) ?? 0).clamp(0, max);
        ctrl.text = v.toString();
        onCommit?.call(v);
      }
    });
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: maxDigits * 12.0 + 4,
          child: TextField(
            controller: ctrl,
            focusNode: focusNode,
            maxLength: maxDigits,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxDigits),
            ],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              height: 1,
            ),
            decoration: InputDecoration(
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              isDense: true,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 4),
          Text(suffix, style: TextStyle(
              fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _buildTimeInput(int seconds, ValueChanged<int> onChanged) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final minCtrl = TextEditingController(text: m.toString().padLeft(2, '0'));
    final secCtrl = TextEditingController(text: s.toString().padLeft(2, '0'));
    final cs = Theme.of(context).colorScheme;

    void commit() {
      final mins = (int.tryParse(minCtrl.text) ?? 0).clamp(0, 99);
      final secs = (int.tryParse(secCtrl.text) ?? 0).clamp(0, 59);
      onChanged(mins * 60 + secs);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildTimeField(minCtrl, hint: 'mm', max: 99, onCommit: commit),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(':', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              height: 1, color: cs.onSurface)),
        ),
        _buildTimeField(secCtrl, hint: 'ss', max: 59, onCommit: commit),
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

  Color _stepColor(String type) {
    switch (type) {
      case 'develop': return Theme.of(context).colorScheme.primary;
      case 'stop': return Colors.amber;
      case 'fix': return Colors.teal;
      case 'wash': return Colors.blue;
      case 'rinse': return Colors.lightBlue;
      case 'custom': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _agitationSummary(Map<String, dynamic> step) {
    final agitation = step['agitation'] as Map<String, dynamic>?;
    if (agitation == null) return '';
    final method = agitation['method'] as String? ?? 'hand';
    if (method == 'hand') {
      final initial = agitation['initialDuration'] as int? ?? 30;
      final period = agitation['period'] as int? ?? 60;
      final duration = agitation['duration'] as int? ?? 10;
      return 'Hand: ${_formatSec(initial)} initial, every ${_formatSec(period)} for ${_formatSec(duration)}';
    } else if (method == 'stand') {
      final initial = agitation['initialDuration'] as int? ?? 30;
      return 'Stand: ${_formatSec(initial)} initial';
    } else if (method == 'disable') {
      return 'Agitation: Disabled';
    } else {
      final speed = agitation['speed'] as int? ?? 60;
      return 'Rolling: $speed RPM';
    }
  }

  static String _formatSec(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m${s}s';
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
          ButtonSegment<String>(
            value: 'stand',
            label: Text(l.t('recipe_agitation_stand'),
                style: const TextStyle(fontSize: 12)),
            icon: const Icon(Icons.hourglass_bottom, size: 16),
          ),
          ButtonSegment<String>(
            value: 'disable',
            label: Text(l.t('recipe_agitation_disable'),
                style: const TextStyle(fontSize: 12)),
            icon: const Icon(Icons.block, size: 16),
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
      ] else if (method == 'stand') ...[
        // Stand: only initial agitation
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
      ] else if (method == 'rolling') ...[
        Row(
          children: [
            Text(l.t('recipe_agitation_speed'), style: labelStyle),
            const SizedBox(width: 8),
            _buildNumericField(
              (agitation['speed'] as int? ?? 60).toString(),
              max: 999,
              suffix: l.t('recipe_agitation_rpm'),
              onCommit: (v) => agitation['speed'] = v,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isEditing) {
          _autoSaveAndPop();
        } else {
          _confirmDiscardAndPop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isEditing ? _autoSaveAndPop : _confirmDiscardAndPop,
        ),
        title: Text(_isEditing
            ? l.t('recipe_edit_title')
            : l.t('recipe_new_title')),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: _deleteRecipe,
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _filmStockCtrl.text.trim().isNotEmpty ? _saveNewAndPop : null,
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
              focusNode: _filmStockFocus,
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
              focusNode: _developerFocus,
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
              focusNode: _dilutionFocus,
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
                DropdownMenuItem(value: 'paper', child: Text(l.t('process_paper'))),
              ],
              onChanged: (v) => setState(() {
                _processType = v ?? 'bw_neg';
                _redSafelight = _processType == 'paper';
              }),
            ),
            const SizedBox(height: 16),

            // Notes
            Text(l.t('recipe_notes'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              focusNode: _notesFocus,
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
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final step = _steps.removeAt(oldIndex);
                  _steps.insert(newIndex, step);
                  _expandedAgitation.clear();
                });
              },
              itemCount: _steps.length,
              itemBuilder: (context, i) {
                final step = _steps[i];
                final type = step['type'] as String;

                final stepColor = _stepColor(type);
                final isExpanded = _expandedAgitation.contains(i);

                return Dismissible(
                  key: ValueKey(step),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.t('recipe_delete_step_title')),
                        content: Text(l.t('recipe_delete_step_message')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l.t('recipe_cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l.t('recipe_delete'),
                                style: TextStyle(color: colorScheme.error)),
                          ),
                        ],
                      ),
                    );
                    return confirmed == true;
                  },
                  onDismissed: (_) => _removeStep(i),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: colorScheme.onErrorContainer),
                  ),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: stepColor, width: 4),
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(_stepIcon(type),
                                  color: stepColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${i + 1}. ${_stepLabel(type, l)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface)),
                              ),
                              _buildTimeInput(
                                step['time'] as int? ?? 60,
                                (val) => setState(() => step['time'] = val),
                              ),
                              const SizedBox(width: 8),
                              ReorderableDragStartListener(
                                index: i,
                                child: Icon(Icons.drag_handle,
                                    size: 20,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (type == 'develop' || type == 'custom') ...[
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final ctrl = TextEditingController(
                                  text: step['label'] as String? ?? '');
                              final fn = _makeTrimNode(ctrl);
                              return TextField(
                                controller: ctrl,
                                focusNode: fn,
                                decoration: InputDecoration(
                                  hintText: l.t('recipe_step_label_hint'),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => step['label'] = v,
                              );
                            }),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expandedAgitation.remove(i);
                                } else {
                                  _expandedAgitation.add(i);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        isExpanded
                                            ? l.t('recipe_agitation')
                                            : _agitationSummary(step),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded) ...[
                              const SizedBox(height: 4),
                              ..._buildAgitationUI(step, l, colorScheme),
                            ],
                          ],
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
    );
  }
}
