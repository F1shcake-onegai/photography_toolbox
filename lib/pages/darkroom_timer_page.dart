import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/import_dialogs.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/list_search_bar.dart';
import '../services/app_localizations.dart';
import '../services/developer_settings.dart';
import '../services/error_log.dart';
import '../services/file_intent_service.dart';
import '../services/import_export_service.dart';
import '../services/import_settings.dart';
import '../services/recipe_storage.dart';
import 'recipe_edit_page.dart';
import 'timer_running_page.dart';

enum _RecipeSortField { dateCreated, dateModified }

class DarkroomTimerPage extends StatefulWidget {
  const DarkroomTimerPage({super.key});

  @override
  State<DarkroomTimerPage> createState() => _DarkroomTimerPageState();
}

class _DarkroomTimerPageState extends State<DarkroomTimerPage> {
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _filteredRecipes = [];
  bool _loading = true;
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Set<String> _activeFilters = {};
  _RecipeSortField _sortField = _RecipeSortField.dateCreated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final recipes = await RecipeStorage.loadRecipes();
    _recipes = recipes;
    _loading = false;
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

  static Map<String, String> _generateTags(Map<String, dynamic> recipe) {
    final tags = <String, String>{};
    final filmStock = recipe['filmStock'] as String? ?? '';
    final developer = recipe['developer'] as String? ?? '';
    final dilution = recipe['dilution'] as String? ?? '';
    final processType = recipe['processType'] as String? ?? 'bw_neg';

    tags['process'] = _processLabel(processType);
    if (developer.isNotEmpty) tags['developer'] = developer;
    if (filmStock.isNotEmpty) tags['film'] = filmStock;
    if (dilution.isNotEmpty) {
      // Extract numeric pattern like 1+50 or 1 + 50 or 1:25 (same logic as chemical mixer)
      final plusMatch = RegExp(r'(\d+(?:\s*\+\s*\d+)+)').firstMatch(dilution);
      final colonMatch = RegExp(r'(\d+(?:\s*:\s*\d+)+)').firstMatch(dilution);
      if (plusMatch != null) {
        tags['dilution'] = plusMatch.group(1)!.replaceAll(' ', '');
      } else if (colonMatch != null) {
        tags['dilution'] = colonMatch.group(1)!.replaceAll(' ', '');
      } else {
        tags['dilution'] = dilution;
      }
    }
    return tags;
  }

  static String _processLabel(String type) {
    return switch (type) {
      'bw_neg' => 'B&W Neg',
      'bw_pos' => 'B&W Rev',
      'color_neg' => 'Color Neg',
      'color_pos' => 'Color Rev',
      'paper' => 'Paper',
      _ => 'B&W Neg',
    };
  }

  // --- Filter / sort ---

  /// Items matching all active filters EXCEPT the given category.
  List<Map<String, dynamic>> _itemsExcludingCategory(String excludeCat) {
    if (_activeFilters.isEmpty) return _recipes;
    final byCategory = <String, Set<String>>{};
    for (final f in _activeFilters) {
      final sep = f.indexOf(':');
      final cat = f.substring(0, sep);
      if (cat == excludeCat) continue;
      final val = f.substring(sep + 1);
      byCategory.putIfAbsent(cat, () => {}).add(val);
    }
    if (byCategory.isEmpty) return _recipes;
    return _recipes.where((r) {
      final tags = _generateTags(r);
      return byCategory.entries.every((entry) {
        final tagVal = tags[entry.key];
        if (tagVal == null) return false;
        return entry.value.contains(tagVal);
      });
    }).toList();
  }

  List<FilterField> _buildFilterFields(AppLocalizations l) {
    final categories = ['process', 'developer', 'film', 'dilution'];
    final labels = {
      'process': l.t('tag_process'),
      'developer': l.t('tag_developer'),
      'film': l.t('tag_film'),
      'dilution': l.t('tag_dilution'),
    };
    return categories.map((cat) {
      final candidates = _itemsExcludingCategory(cat);
      final values = <String>{};
      for (final r in candidates) {
        final tags = _generateTags(r);
        if (tags.containsKey(cat)) values.add(tags[cat]!);
      }
      return FilterField(
          category: cat, label: labels[cat]!, values: values.toList()..sort());
    }).toList();
  }

  /// Check if a date (from createdAt ms) matches a user query string.
  static bool _dateMatches(int? ms, String query) {
    if (ms == null) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final representations = [
      '$y-$m-$d', '$y/$m/$d', '$y-$m', '$y/$m',
      '$d/$m/$y', '$d-$m-$y', '$m/$d/$y', y,
      _monthName(dt.month), _monthAbbr(dt.month),
      '${_monthAbbr(dt.month)} $y', '${_monthName(dt.month)} $y',
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
    var list = List<Map<String, dynamic>>.from(_recipes);
    final query = _searchCtrl.text.toLowerCase().trim();

    // Text search
    if (query.isNotEmpty) {
      list = list.where((r) {
        final filmStock = (r['filmStock'] as String? ?? '').toLowerCase();
        final developer = (r['developer'] as String? ?? '').toLowerCase();
        final dilution = (r['dilution'] as String? ?? '').toLowerCase();
        final notes = (r['notes'] as String? ?? '').toLowerCase();
        if (filmStock.contains(query) || developer.contains(query) ||
            dilution.contains(query) || notes.contains(query)) {
          return true;
        }
        if (_generateTags(r).values.any(
            (v) => v.toLowerCase().contains(query))) {
          return true;
        }
        // Date search
        final createdAt = r['createdAt'] as int?;
        if (_dateMatches(createdAt, query)) return true;
        return false;
      }).toList();
    }

    // Filter dropdowns (AND across categories, OR within same category)
    if (_activeFilters.isNotEmpty) {
      final byCategory = <String, Set<String>>{};
      for (final f in _activeFilters) {
        final sep = f.indexOf(':');
        final cat = f.substring(0, sep);
        final val = f.substring(sep + 1);
        byCategory.putIfAbsent(cat, () => {}).add(val);
      }
      list = list.where((r) {
        final tags = _generateTags(r);
        return byCategory.entries.every((entry) {
          final tagVal = tags[entry.key];
          if (tagVal == null) return false;
          return entry.value.contains(tagVal);
        });
      }).toList();
    }

    // Sort
    switch (_sortField) {
      case _RecipeSortField.dateCreated:
        list.sort((a, b) => (b['createdAt'] as int? ?? 0)
            .compareTo(a['createdAt'] as int? ?? 0));
      case _RecipeSortField.dateModified:
        list.sort((a, b) {
          final modA = (a['modifiedAt'] as int?) ?? (a['createdAt'] as int? ?? 0);
          final modB = (b['modifiedAt'] as int?) ?? (b['createdAt'] as int? ?? 0);
          return modB.compareTo(modA);
        });
    }

    setState(() => _filteredRecipes = list);
  }

  Future<void> _createRecipe() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const RecipeEditPage()),
    );
    if (result != null) {
      await RecipeStorage.updateRecipe(result);
      await _load();
    }
  }

  Future<void> _editRecipe(Map<String, dynamic> recipe) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => RecipeEditPage(existingRecipe: recipe)),
    );
    if (result != null) {
      if (result['_deleted'] == true) {
        await RecipeStorage.deleteRecipe(result['id'] as String);
      } else {
        await RecipeStorage.updateRecipe(result);
      }
      await _load();
    }
  }

  Future<void> _duplicateRecipe(Map<String, dynamic> recipe) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('recipe_duplicate')),
        content: Text(l.t('recipe_duplicate_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('recipe_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('recipe_duplicate')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final copy = Map<String, dynamic>.from(recipe);
    copy['id'] = RecipeStorage.newUuid();
    copy['steps'] = (recipe['steps'] as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    await RecipeStorage.updateRecipe(copy);
    await _load();
  }


  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    return origin & size;
  }

  Future<void> _shareRecipe(Map<String, dynamic> recipe) async {
    final l = AppLocalizations.of(context);
    try {
      final path = await RecipeStorage.exportRecipe(recipe);
      final shareText = recipe['filmStock'] as String? ?? 'Recipe';
      await ImportExportService.shareFile(path, shareText, sharePositionOrigin: _shareOrigin());
    } catch (e, stack) {
      ErrorLog.log('Recipe Export', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DeveloperSettings.verbose
              ? '${l.t('export_error')}: $e'
              : l.t('export_error'))),
        );
      }
    }
  }

  Future<void> _importRecipe() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ptrecipe', 'json'],
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

      if (parsed.type != ExportFileType.recipe) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('import_invalid_file'))),
          );
        }
        return;
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
                Text(l.t('import_preview_recipe_title'),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text(l.t('import_preview_recipe_film',
                    {'value': summary['filmStock']!})),
                Text(l.t('import_preview_recipe_developer',
                    {'value': summary['developer']!})),
                Text(l.t('import_preview_recipe_steps',
                    {'value': summary['steps']!})),
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
      if (confirmed != true || !mounted) return;

      // Determine duplicate action
      var action = await ImportSettings.load();
      final uuid = parsed.data['id'] as String?;
      if (action == DuplicateAction.ask && uuid != null) {
        final existing = await RecipeStorage.findByUuid(uuid);
        if (existing != null) {
          if (!mounted) return;
          final chosen = await _showDuplicateDialog(l);
          if (chosen == null) return;
          action = chosen;
        }
      }

      // Import
      final outcome =
          await RecipeStorage.importRecipeData(parsed.data, action);
      await _load();
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
      ErrorLog.log('Recipe Import', e, stack);
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

  void _startTimer(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TimerRunningPage(recipe: recipe)),
    );
  }

  Widget _buildRecipeTitles(
      BuildContext context, Map<String, dynamic> recipe, ColorScheme cs) {
    final filmStock = recipe['filmStock'] as String? ?? '';
    final developer = recipe['developer'] as String? ?? '';
    final dilution = recipe['dilution'] as String? ?? '';
    final baseTemp = recipe['baseTemp'] as num?;
    final titleStyle = Theme.of(context).textTheme.titleSmall!;
    const iconSize = 16.0;
    final iconColor = cs.onSurfaceVariant;

    String developerLine = developer;
    if (developer.isNotEmpty && baseTemp != null) {
      developerLine = '$developer @ ${baseTemp.toStringAsFixed(1)}\u00b0C';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_roll_outlined, size: iconSize, color: iconColor),
            const SizedBox(width: 6),
            Expanded(child: Text(
              filmStock.isNotEmpty ? filmStock : '—',
              style: titleStyle,
            )),
          ],
        ),
        if (developerLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.science_outlined, size: iconSize, color: iconColor),
              const SizedBox(width: 6),
              Expanded(child: Text(developerLine, style: titleStyle)),
            ],
          ),
        ],
        if (dilution.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.water_drop_outlined, size: iconSize, color: iconColor),
              const SizedBox(width: 6),
              Expanded(child: Text(dilution, style: titleStyle)),
            ],
          ),
        ],
      ],
    );
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
        title: Text(l.t('darkroom_title')),
        actions: [
          if (_recipes.isNotEmpty)
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
          if (_recipes.isNotEmpty)
            PopupMenuButton<_RecipeSortField>(
              icon: const Icon(Icons.sort),
              tooltip: l.t('sort_title'),
              onSelected: (field) {
                _sortField = field;
                _applyFilters();
              },
              itemBuilder: (_) => [
                _sortMenuItem(_RecipeSortField.dateCreated,
                    l.t('sort_date_created')),
                _sortMenuItem(_RecipeSortField.dateModified,
                    l.t('sort_date_modified')),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l.t('recipe_import'),
            onPressed: _importRecipe,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRecipe,
        icon: const Icon(Icons.add),
        label: Text(l.t('recipe_new')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 64, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(l.t('recipe_no_recipes'),
                          style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(l.t('recipe_add_hint'),
                          style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_showSearch)
                      ListSearchBar(
                        controller: _searchCtrl,
                        hintText: l.t('search_hint_recipes'),
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
                      child: _filteredRecipes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 64,
                                      color: colorScheme.onSurfaceVariant),
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
                              items: _filteredRecipes,
                              itemBuilder: (recipe) =>
                                  _buildRecipeCard(recipe, colorScheme, l),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, ColorScheme colorScheme, AppLocalizations l) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _startTimer(recipe),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildRecipeTitles(context, recipe, colorScheme),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editRecipe(recipe),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    tooltip: l.t('recipe_duplicate'),
                    onPressed: () => _duplicateRecipe(recipe),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    onPressed: () => _shareRecipe(recipe),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if ((recipe['notes'] as String? ?? '').isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Divider(height: 1, color: colorScheme.outlineVariant),
                ),
                Text(
                  recipe['notes'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<_RecipeSortField> _sortMenuItem(
      _RecipeSortField field, String label) {
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
}
