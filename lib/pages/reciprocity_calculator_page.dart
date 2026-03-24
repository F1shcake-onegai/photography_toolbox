import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../widgets/app_drawer.dart';
import '../services/app_localizations.dart';
import '../services/reciprocity_storage.dart';

class ReciprocityCalculatorPage extends StatefulWidget {
  const ReciprocityCalculatorPage({super.key});

  @override
  State<ReciprocityCalculatorPage> createState() =>
      _ReciprocityCalculatorPageState();
}

class _ReciprocityCalculatorPageState
    extends State<ReciprocityCalculatorPage> {
  List<Map<String, dynamic>> _customProfiles = [];
  List<Map<String, dynamic>> _allProfiles = [];
  String? _selectedProfileId;

  // Metered time: discrete slider values (seconds)
  static const List<double> _meteredTimes = [
    0.5, 1, 2, 4, 8, 15, 30, 60, 120, 240, 480, 960,
  ];
  int _meteredTimeIndex = 5; // default 15s

  // Optional exact time override
  final TextEditingController _exactTimeCtrl = TextEditingController();

  // Results
  List<(String, String)> _resultItems = [];
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _exactTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final custom = await ReciprocityStorage.loadProfiles();
    setState(() {
      _customProfiles = custom;
      _allProfiles = ReciprocityStorage.allProfiles(custom);
      _selectedProfileId ??= _allProfiles.first['id'] as String;
    });
  }

  double _getMeteredTime() {
    final exact = double.tryParse(_exactTimeCtrl.text);
    if (exact != null && exact > 0) return exact;
    return _meteredTimes[_meteredTimeIndex];
  }

  void _compute() {
    final l = AppLocalizations.of(context);
    if (_selectedProfileId == null) {
      setState(() {
        _resultItems = [];
        _errorText = l.t('reciprocity_no_result');
      });
      return;
    }

    final profile = _allProfiles.firstWhere(
      (p) => p['id'] == _selectedProfileId,
      orElse: () => _allProfiles.first,
    );

    final p = (profile['exponent'] as num).toDouble();
    final threshold =
        (profile['thresholdSeconds'] as num?)?.toDouble() ?? 0.0;
    final metered = _getMeteredTime();

    if (metered <= threshold) {
      setState(() {
        _errorText = '';
        _resultItems = [
          (l.t('reciprocity_corrected_label'), _formatTime(metered)),
          (l.t('reciprocity_extra_stops_label'), '+0'),
        ];
      });
      return;
    }

    final corrected = math.pow(metered, p).toDouble();
    final extraStops = math.log(corrected / metered) / math.ln2;

    setState(() {
      _errorText = '';
      _resultItems = [
        (l.t('reciprocity_corrected_label'), _formatTime(corrected)),
        (l.t('reciprocity_extra_stops_label'),
            '+${extraStops.toStringAsFixed(1)}'),
      ];
    });
  }

  static String _formatTime(double seconds) {
    if (seconds < 60) {
      return seconds == seconds.roundToDouble()
          ? '${seconds.toInt()}s'
          : '${seconds.toStringAsFixed(1)}s';
    }
    final totalSecs = seconds.round();
    if (totalSecs >= 3600) {
      final h = totalSecs ~/ 3600;
      final m = (totalSecs % 3600) ~/ 60;
      final s = totalSecs % 60;
      if (s == 0 && m == 0) return '${h}h';
      if (s == 0) return '${h}h ${m}m';
      return '${h}h ${m}m ${s}s';
    }
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  static String _formatSliderTime(double seconds) {
    if (seconds < 60) {
      return seconds == seconds.roundToDouble()
          ? '${seconds.toInt()}s'
          : '${seconds.toStringAsFixed(1)}s';
    }
    final m = (seconds / 60).floor();
    final s = (seconds % 60).round();
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  // ───── Custom Profile Management ─────

  void _showManageCustom() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomFilmSheet(
        profiles: _customProfiles,
        onChanged: () => _loadProfiles(),
      ),
    );
  }

  // ───── Build ─────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    if (_allProfiles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.t('reciprocity_title'))),
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
        title: Text(l.t('reciprocity_title')),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.t('reciprocity_heading'),
                      style:
                          Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),

                  // Film stock dropdown
                  Text(l.t('reciprocity_film_stock'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  _buildFilmDropdown(colorScheme, l),
                  const SizedBox(height: 8),
                  _buildProfileInfo(colorScheme),
                  const SizedBox(height: 16),

                  // Metered time slider
                  Text(l.t('reciprocity_metered_time'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          _formatSliderTime(
                              _meteredTimes[_meteredTimeIndex]),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _meteredTimeIndex.toDouble(),
                          min: 0,
                          max: (_meteredTimes.length - 1).toDouble(),
                          divisions: _meteredTimes.length - 1,
                          label: _formatSliderTime(
                              _meteredTimes[_meteredTimeIndex]),
                          onChanged: (v) => setState(() {
                            _meteredTimeIndex = v.round();
                            _exactTimeCtrl.clear();
                          }),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            _formatSliderTime(_meteredTimes.first),
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                    colorScheme.onSurfaceVariant)),
                        Text(_formatSliderTime(_meteredTimes.last),
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                    colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Exact time text field
                  Text(l.t('reciprocity_metered_time_seconds'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _exactTimeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(
                      hintText: _formatSliderTime(
                          _meteredTimes[_meteredTimeIndex]),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _compute,
                    icon: const Icon(Icons.calculate),
                    label: Text(l.t('reciprocity_compute')),
                  ),
                ],
              ),
            ),
          ),
          _buildResultArea(colorScheme, l),
        ],
      ),
    );
  }

  Widget _buildFilmDropdown(ColorScheme colorScheme, AppLocalizations l) {
    // Build grouped dropdown items
    final items = <DropdownMenuItem<String>>[];
    String? lastBrand;

    for (final profile in _allProfiles) {
      final brand = profile['brand'] as String? ?? '';
      final isPreset = profile['isPreset'] == true;

      // Add brand header when brand changes (presets only)
      if (isPreset && brand != lastBrand) {
        if (lastBrand != null) {
          // Separator between brands
          items.add(DropdownMenuItem<String>(
            enabled: false,
            value: '_divider_$brand',
            child: Divider(color: colorScheme.outlineVariant),
          ));
        }
        items.add(DropdownMenuItem<String>(
          enabled: false,
          value: '_header_$brand',
          child: Text(
            brand,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ));
        lastBrand = brand;
      }

      // Non-preset: mark as custom section header once
      if (!isPreset && lastBrand != '_custom') {
        items.add(DropdownMenuItem<String>(
          enabled: false,
          value: '_divider_custom',
          child: Divider(color: colorScheme.outlineVariant),
        ));
        items.add(DropdownMenuItem<String>(
          enabled: false,
          value: '_header_custom',
          child: Text(
            l.t('reciprocity_manage_custom'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ));
        lastBrand = '_custom';
      }

      final id = profile['id'] as String;
      final name = profile['name'] as String;

      items.add(DropdownMenuItem<String>(
        value: id,
        child: Text(isPreset ? '$brand $name' : name),
      ));
    }

    // "Manage Custom Films..." action item
    items.add(DropdownMenuItem<String>(
      enabled: false,
      value: '_divider_manage',
      child: Divider(color: colorScheme.outlineVariant),
    ));
    items.add(DropdownMenuItem<String>(
      value: '_manage',
      child: Row(
        children: [
          Icon(Icons.settings, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            l.t('reciprocity_manage_custom'),
            style: TextStyle(color: colorScheme.primary),
          ),
        ],
      ),
    ));

    return DropdownButtonFormField<String>(
      initialValue: _selectedProfileId,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      isExpanded: true,
      items: items,
      onChanged: (v) {
        if (v == '_manage') {
          _showManageCustom();
          return;
        }
        if (v == null || v.startsWith('_')) return;
        setState(() => _selectedProfileId = v);
        _compute();
      },
    );
  }

  Widget _buildProfileInfo(ColorScheme colorScheme) {
    if (_selectedProfileId == null) return const SizedBox.shrink();
    final profile = _allProfiles.firstWhere(
      (p) => p['id'] == _selectedProfileId,
      orElse: () => _allProfiles.first,
    );
    final p = (profile['exponent'] as num).toDouble();
    final threshold =
        (profile['thresholdSeconds'] as num?)?.toDouble() ?? 0.0;
    return Text(
      "t' = t^$p${threshold > 0 ? '  (threshold: ${_formatSliderTime(threshold)})' : ''}",
      style: TextStyle(
        fontSize: 12,
        color: colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildResultArea(
      ColorScheme colorScheme, AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
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
                  _errorText.isNotEmpty
                      ? _errorText
                      : l.t('reciprocity_no_result'),
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
}

// ───── Custom Film Management Bottom Sheet ─────

class _CustomFilmSheet extends StatefulWidget {
  final List<Map<String, dynamic>> profiles;
  final VoidCallback onChanged;

  const _CustomFilmSheet({
    required this.profiles,
    required this.onChanged,
  });

  @override
  State<_CustomFilmSheet> createState() => _CustomFilmSheetState();
}

class _CustomFilmSheetState extends State<_CustomFilmSheet> {
  late List<Map<String, dynamic>> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = List.from(widget.profiles);
  }

  Future<void> _reload() async {
    final loaded = await ReciprocityStorage.loadProfiles();
    setState(() => _profiles = loaded);
    widget.onChanged();
  }

  void _showEditDialog({Map<String, dynamic>? existing}) {
    final l = AppLocalizations.of(context);
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final expCtrl = TextEditingController(
        text: existing != null
            ? (existing['exponent'] as num).toString()
            : '1.3');
    final threshCtrl = TextEditingController(
        text: existing != null
            ? (existing['thresholdSeconds'] as num).toString()
            : '1.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null
            ? l.t('reciprocity_edit_custom')
            : l.t('reciprocity_add_custom')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l.t('reciprocity_custom_name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: l.t('reciprocity_custom_exponent'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: threshCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: l.t('reciprocity_custom_threshold'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('reciprocity_cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final exp = double.tryParse(expCtrl.text);
              final thresh = double.tryParse(threshCtrl.text) ?? 1.0;
              if (name.isEmpty || exp == null || exp <= 1.0) return;

              final profile = <String, dynamic>{
                'id': existing?['id'] ??
                    const Uuid().v4(),
                'name': name,
                'brand': '',
                'exponent': exp,
                'thresholdSeconds': thresh,
                'isPreset': false,
              };
              await ReciprocityStorage.updateProfile(profile);
              if (ctx.mounted) Navigator.pop(ctx);
              await _reload();
            },
            child: Text(l.t('reciprocity_save')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> profile) {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('reciprocity_delete_custom')),
        content: Text(l.t('reciprocity_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('reciprocity_cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await ReciprocityStorage.deleteProfile(
                  profile['id'] as String);
              if (ctx.mounted) Navigator.pop(ctx);
              await _reload();
            },
            child: Text(l.t('reciprocity_delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.t('reciprocity_manage_custom'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showEditDialog(),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _profiles.isEmpty
                ? Center(
                    child: Text(
                      l.t('reciprocity_no_custom'),
                      style: TextStyle(
                          color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final p = _profiles[index];
                      return ListTile(
                        title: Text(p['name'] as String),
                        subtitle: Text(
                            'p=${p['exponent']}  threshold=${p['thresholdSeconds']}s'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showEditDialog(existing: p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  _confirmDelete(p),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
