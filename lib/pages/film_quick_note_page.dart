import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/import_dialogs.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/list_search_bar.dart';
import '../services/developer_settings.dart';
import '../services/error_log.dart';
import '../services/file_intent_service.dart';
import '../services/film_storage.dart';
import '../services/import_export_service.dart';
import '../services/import_settings.dart';
import '../services/app_localizations.dart';
import 'package:flutter/services.dart';
import 'roll_detail_page.dart';

enum _RollSortField { dateCreated, dateModified }

class FilmQuickNotePage extends StatefulWidget {
  const FilmQuickNotePage({super.key});

  @override
  State<FilmQuickNotePage> createState() => _FilmQuickNotePageState();
}

class _FilmQuickNotePageState extends State<FilmQuickNotePage> {
  List<Map<String, dynamic>> _rolls = [];
  List<Map<String, dynamic>> _filteredRolls = [];
  bool _loaded = false;
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Set<String> _activeFilters = {};
  _RollSortField _sortField = _RollSortField.dateCreated;

  @override
  void initState() {
    super.initState();
    _loadRolls();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRolls() async {
    final rolls = await FilmStorage.loadRolls();
    _rolls = rolls;
    _loaded = true;
    _applyFilters();
    _checkPendingImport();
  }

  void _checkPendingImport() {
    final pending = FileIntentService.pendingFilePath;
    if (pending != null) {
      FileIntentService.pendingFilePath = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processImportFile(pending);
      });
    }
  }

  // --- Tag generation ---

  static Map<String, String> _generateTags(Map<String, dynamic> roll) {
    final tags = <String, String>{};
    final brand = roll['brand'] as String? ?? '';
    final sensitivity = roll['sensitivity'] as String? ?? '';
    if (brand.isNotEmpty) tags['brand'] = brand;
    if (sensitivity.isNotEmpty) tags['iso'] = 'ISO $sensitivity';
    final pp = (roll['pushPull'] as int?) ??
        (roll['ec'] as num?)?.round() ?? 0;
    tags['push_pull'] = pp != 0 ? 'yes' : 'no';
    return tags;
  }

  // --- Filter / sort ---

  /// Items matching all active filters EXCEPT the given category.
  List<Map<String, dynamic>> _itemsExcludingCategory(String excludeCat) {
    if (_activeFilters.isEmpty) return _rolls;
    // Group active filters by category, excluding the target
    final byCategory = <String, Set<String>>{};
    for (final f in _activeFilters) {
      final sep = f.indexOf(':');
      final cat = f.substring(0, sep);
      if (cat == excludeCat) continue;
      final val = f.substring(sep + 1);
      byCategory.putIfAbsent(cat, () => {}).add(val);
    }
    if (byCategory.isEmpty) return _rolls;
    return _rolls.where((r) {
      final tags = _generateTags(r);
      return byCategory.entries.every((entry) {
        final tagVal = tags[entry.key];
        if (tagVal == null) return false;
        return entry.value.contains(tagVal);
      });
    }).toList();
  }

  List<FilterField> _buildFilterFields(AppLocalizations l) {
    final categories = ['brand', 'iso', 'push_pull'];
    final labels = {
      'brand': l.t('tag_brand'),
      'iso': l.t('tag_iso'),
      'push_pull': l.t('tag_push_pull'),
    };
    final ppDisplayLabels = {
      'yes': l.t('filter_yes'),
      'no': l.t('filter_no'),
    };
    return categories.map((cat) {
      final candidates = _itemsExcludingCategory(cat);
      final values = <String>{};
      for (final r in candidates) {
        final tags = _generateTags(r);
        if (tags.containsKey(cat)) values.add(tags[cat]!);
      }
      var sorted = values.toList();
      if (cat == 'iso') {
        sorted.sort((a, b) {
          final na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return na.compareTo(nb);
        });
      } else if (cat == 'push_pull') {
        sorted.sort((a, b) => a == 'yes' ? -1 : 1);
      } else {
        sorted.sort();
      }
      return FilterField(
        category: cat,
        label: labels[cat]!,
        values: sorted,
        displayLabels: cat == 'push_pull' ? ppDisplayLabels : null,
      );
    }).toList();
  }

  /// Check if a date (from createdAt ms) matches a user query string.
  static bool _dateMatches(int? ms, String query) {
    if (ms == null) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    // Match against multiple date representations
    final representations = [
      '$y-$m-$d',           // 2024-03-15
      '$y/$m/$d',           // 2024/03/15
      '$y-$m',              // 2024-03
      '$y/$m',              // 2024/03
      '$d/$m/$y',           // 15/03/2024
      '$d-$m-$y',           // 15-03-2024
      '$m/$d/$y',           // 03/15/2024
      y,                    // 2024
      _monthName(dt.month), // march
      _monthAbbr(dt.month), // mar
      '${_monthAbbr(dt.month)} $y', // mar 2024
      '${_monthName(dt.month)} $y', // march 2024
    ];
    return representations.any((r) => r.contains(query));
  }

  static String _monthName(int m) {
    const names = ['', 'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'];
    return names[m];
  }

  static String _monthAbbr(int m) {
    const abbrs = ['', 'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    return abbrs[m];
  }

  void _applyFilters() {
    var list = List<Map<String, dynamic>>.from(_rolls);
    final query = _searchCtrl.text.toLowerCase().trim();

    // Text search
    if (query.isNotEmpty) {
      list = list.where((r) {
        final title = (r['title'] as String? ?? '').toLowerCase();
        final brand = (r['brand'] as String? ?? '').toLowerCase();
        final model = (r['model'] as String? ?? '').toLowerCase();
        final sensitivity = (r['sensitivity'] as String? ?? '').toLowerCase();
        final comments = (r['comments'] as String? ?? '').toLowerCase();
        if (title.contains(query) || brand.contains(query) || model.contains(query) ||
            sensitivity.contains(query) || comments.contains(query)) {
          return true;
        }
        if (_generateTags(r).values.any(
            (v) => v.toLowerCase().contains(query))) {
          return true;
        }
        // Date search
        final createdAt = r['createdAt'] as int? ??
            int.tryParse(r['id'] as String? ?? '');
        if (_dateMatches(createdAt, query)) return true;
        return false;
      }).toList();
    }

    // Filter dropdowns (AND across categories, OR within same category)
    if (_activeFilters.isNotEmpty) {
      // Group active filters by category
      final byCategory = <String, Set<String>>{};
      for (final f in _activeFilters) {
        final sep = f.indexOf(':');
        final cat = f.substring(0, sep);
        final val = f.substring(sep + 1);
        byCategory.putIfAbsent(cat, () => {}).add(val);
      }
      list = list.where((r) {
        final tags = _generateTags(r);
        // AND across categories: item must match at least one value in each active category
        return byCategory.entries.every((entry) {
          final tagVal = tags[entry.key];
          if (tagVal == null) return false;
          return entry.value.contains(tagVal);
        });
      }).toList();
    }

    // Sort
    switch (_sortField) {
      case _RollSortField.dateCreated:
        list.sort((a, b) => (b['createdAt'] as int? ?? 0)
            .compareTo(a['createdAt'] as int? ?? 0));
      case _RollSortField.dateModified:
        list.sort((a, b) {
          final modA = (a['modifiedAt'] as int?) ?? (a['createdAt'] as int? ?? 0);
          final modB = (b['modifiedAt'] as int?) ?? (b['createdAt'] as int? ?? 0);
          return modB.compareTo(modA);
        });
    }

    setState(() => _filteredRolls = list);
  }

  Future<void> _addRoll() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NewRollSheet(existingRolls: _rolls),
    );
    if (result == null) return;

    final roll = <String, dynamic>{
      'id': FilmStorage.newUuid(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      if ((result['title'] ?? '').isNotEmpty) 'title': result['title'],
      'brand': result['brand'] ?? '',
      'model': result['model'] ?? '',
      'sensitivity': result['sensitivity'] ?? '',
      'comments': '',
      'shots': <Map<String, dynamic>>[],
    };
    _rolls.add(roll);
    await FilmStorage.saveRolls(_rolls);
    _applyFilters();
  }

  Future<void> _openRoll(Map<String, dynamic> roll) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RollDetailPage(rollId: roll['id'] as String),
      ),
    );
    await _loadRolls();
  }

  Future<void> _importRoll() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ptroll', 'json', 'zip'],
    );
    if (result == null || result.files.single.path == null) return;
    await _processImportFile(result.files.single.path!);
  }

  Future<void> _processImportFile(String filePath) async {
    final l = AppLocalizations.of(context);
    try {
      // Parse and validate the file
      final ImportParseResult parsed;
      try {
        parsed = await ImportExportService.parseImportFile(filePath);
      } on FormatException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l.t('import_error')}: ${e.message}')),
          );
        }
        return;
      }

      if (parsed.type != ExportFileType.roll) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('import_invalid_file'))),
          );
        }
        return;
      }

      // Warn about small images
      if (parsed.smallImages.isNotEmpty && mounted) {
        final list = parsed.smallImages.entries
            .map((e) => '${e.key} (${e.value})')
            .join('\n');
        final cont = await showModalBottomSheet<bool>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.t('import_small_images_title'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(l.t('import_small_images_message', {'list': list})),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.t('import_confirm')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.t('import_cancel')),
                  ),
                ],
              ),
            ),
          ),
        );
        if (cont != true) {
          await ImportExportService.cleanupTempImages(parsed.images);
          return;
        }
      }

      // Show preview confirmation
      if (!mounted) return;
      final summary = ImportExportService.previewSummary(parsed);
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.t('import_preview_roll_title'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text(l.t('import_preview_roll_film',
                    {'value': summary['film']!})),
                Text(l.t('import_preview_roll_shots',
                    {'value': summary['shots']!})),
                Text(l.t('import_preview_roll_images',
                    {'value': summary['images']!})),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.t('import_confirm')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.t('import_cancel')),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true || !mounted) {
        await ImportExportService.cleanupTempImages(parsed.images);
        return;
      }

      // Determine duplicate action
      var action = await ImportSettings.load();
      final uuid = parsed.data['id'] as String?;
      if (action == DuplicateAction.ask && uuid != null) {
        final existing = await FilmStorage.findByUuid(uuid);
        if (existing != null) {
          if (!mounted) return;
          final chosen = await _showDuplicateDialog(l);
          if (chosen == null) {
            await ImportExportService.cleanupTempImages(parsed.images);
            return;
          }
          action = chosen;
        }
      }

      // Import
      final outcome = await FilmStorage.importRollData(
          parsed.data, action, parsed.images, parsed.smallImages);
      await ImportExportService.cleanupTempImages(parsed.images);
      await _loadRolls();
      if (mounted) {
        final msg = switch (outcome) {
          'imported' => l.t('import_success'),
          'replaced' => l.t('import_replaced'),
          'skipped' => l.t('import_skipped'),
          'duplicated' => l.t('import_duplicated'),
          _ => l.t('import_success'),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e, stack) {
      ErrorLog.log('Roll Import', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DeveloperSettings.verbose
              ? '${l.t('import_error')}: $e'
              : l.t('import_error'))),
        );
      }
    }
  }

  Future<DuplicateAction?> _showDuplicateDialog(AppLocalizations l) {
    return showDuplicateImportSheet(context, l);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pop(context),
        ),
        title: Text(l.t('film_title')),
        actions: [
          if (_rolls.isNotEmpty)
            IconButton(
              icon: Icon(_showSearch ? Icons.search_off : Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchCtrl.clear();
                    _activeFilters = {};
                    _applyFilters();
                  }
                });
              },
            ),
          if (_rolls.isNotEmpty)
            PopupMenuButton<_RollSortField>(
              icon: const Icon(Icons.sort),
              tooltip: l.t('sort_title'),
              onSelected: (field) {
                _sortField = field;
                _applyFilters();
              },
              itemBuilder: (_) => [
                _sortMenuItem(
                    _RollSortField.dateCreated, l.t('sort_date_created')),
                _sortMenuItem(
                    _RollSortField.dateModified, l.t('sort_date_modified')),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l.t('roll_import'),
            onPressed: _importRoll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRoll,
        icon: const Icon(Icons.add),
        label: Text(l.t('film_new_roll')),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _rolls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(l.t('film_no_rolls'),
                          style: TextStyle(
                              fontSize: 18,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text(l.t('film_add_hint'),
                          style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_showSearch)
                      ListSearchBar(
                        controller: _searchCtrl,
                        hintText: l.t('search_hint_rolls'),
                        onChanged: (_) => _applyFilters(),
                        onClear: () {
                          _searchCtrl.clear();
                          _applyFilters();
                        },
                        filterFields: _buildFilterFields(l),
                        activeFilters: _activeFilters,
                        onFilterToggled: (f) {
                          if (_activeFilters.contains(f)) {
                            _activeFilters.remove(f);
                          } else {
                            _activeFilters.add(f);
                          }
                          _applyFilters();
                        },
                      ),
                    Expanded(
                      child: _filteredRolls.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 64,
                                      color:
                                          colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 16),
                                  Text(l.t('search_no_results'),
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: colorScheme
                                              .onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Text(l.t('search_no_results_hint'),
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme
                                              .onSurfaceVariant)),
                                ],
                              ),
                            )
                          : MasonryList<Map<String, dynamic>>(
                              items: _filteredRolls,
                              itemBuilder: (roll) =>
                                  _buildRollCard(roll, colorScheme, l),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRollCard(Map<String, dynamic> roll, ColorScheme colorScheme, AppLocalizations l) {
    final shots = (roll['shots'] as List?) ?? [];
    final title = roll['title'] as String? ?? '';
    final filmName = '${roll["brand"]} ${roll["model"]}'.trim();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRoll(roll),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.camera_roll_outlined,
                      size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        title.isNotEmpty ? title : l.t('film_untitled'),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text(_formatDate(roll),
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(filmName,
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(
                    'ISO ${roll["sensitivity"]}'
                    ' \u2022 ${l.t("film_shots_count", {"count": shots.length.toString()})}',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
              ),
              if ((roll["comments"] as String?)?.isNotEmpty == true) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Divider(height: 1, color: colorScheme.outlineVariant),
                ),
                Text(
                    roll["comments"] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<_RollSortField> _sortMenuItem(
      _RollSortField field, String label) {
    return PopupMenuItem(
      value: field,
      child: Row(
        children: [
          if (_sortField == field)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(Map<String, dynamic> roll) {
    final ms = roll['createdAt'] as int? ??
        int.tryParse(roll['id'] as String? ?? '');
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${_months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  }
}

class _FilmStock {
  final String brand;
  final String model;
  final String iso;
  const _FilmStock({required this.brand, required this.model, required this.iso});
}

class _NewRollSheet extends StatefulWidget {
  final List<Map<String, dynamic>> existingRolls;
  const _NewRollSheet({required this.existingRolls});

  @override
  State<_NewRollSheet> createState() => _NewRollSheetState();
}

class _NewRollSheetState extends State<_NewRollSheet> {
  final _titleCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _isoCtrl = TextEditingController();
  bool _isoManuallyEdited = false;
  List<_FilmStock> _recentFilms = [];

  @override
  void initState() {
    super.initState();
    _buildRecentFilms();
    _modelCtrl.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _modelCtrl.removeListener(_onModelChanged);
    _titleCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _isoCtrl.dispose();
    super.dispose();
  }

  void _buildRecentFilms() {
    final seen = <String>{};
    final recent = <_FilmStock>[];
    final sorted = List<Map<String, dynamic>>.from(widget.existingRolls)
      ..sort((a, b) => (b['createdAt'] as int? ?? 0)
          .compareTo(a['createdAt'] as int? ?? 0));
    for (final roll in sorted) {
      final brand = roll['brand'] as String? ?? '';
      final model = roll['model'] as String? ?? '';
      final iso = roll['sensitivity'] as String? ?? '';
      if (brand.isEmpty && model.isEmpty) continue;
      final key = '$brand|$model|$iso'.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      recent.add(_FilmStock(brand: brand, model: model, iso: iso));
      if (recent.length >= 10) break;
    }
    _recentFilms = recent;
  }

  void _onModelChanged() {
    if (_isoManuallyEdited) return;
    final match = RegExp(r'(\d+)\s*$').firstMatch(_modelCtrl.text);
    if (match != null) {
      _isoCtrl.text = match.group(1)!;
    }
  }

  void _selectRecent(_FilmStock film) {
    Navigator.pop(context, {
      'title': _titleCtrl.text.trim(),
      'brand': film.brand,
      'model': film.model,
      'sensitivity': film.iso,
    });
  }

  void _fillFromRecent(_FilmStock film) {
    setState(() {
      _brandCtrl.text = film.brand;
      _modelCtrl.text = film.model;
      _isoCtrl.text = film.iso;
      _isoManuallyEdited = false;
    });
  }

  void _create() {
    final title = _titleCtrl.text.trim();
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final iso = _isoCtrl.text.trim();
    if (brand.isEmpty && model.isEmpty) return;
    Navigator.pop(context, {
      'title': title,
      'brand': brand,
      'model': model,
      'sensitivity': iso,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

                if (_recentFilms.isNotEmpty) ...[
                  Text(l.t('film_recent'),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _recentFilms.map((film) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _selectRecent(film),
                                onLongPress: () => _fillFromRecent(film),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cs.outlineVariant),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(film.brand,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurfaceVariant)),
                                      Text(film.model,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: cs.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l.t('film_or_manual'),
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: cs.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                Text(l.t('film_roll_title'),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l.t('film_roll_title_hint'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.t('film_brand'),
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _brandCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: l.t('film_brand_hint'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.t('film_model'),
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _modelCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: l.t('film_model_hint'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(l.t('film_sensitivity'),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                TextField(
                  controller: _isoCtrl,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    hintText: l.t('film_sensitivity_hint'),
                    counterText: '',
                  ),
                  onTap: () => _isoManuallyEdited = true,
                  onChanged: (_) => _isoManuallyEdited = true,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: Text(l.t('film_create')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
