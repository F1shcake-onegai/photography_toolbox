import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_drawer.dart';
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

enum _RecipeSortField { filmStock, dateCreated, developer }

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
    if (dilution.isNotEmpty) tags['dilution'] = dilution;
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
      case _RecipeSortField.filmStock:
        list.sort((a, b) => (a['filmStock'] as String? ?? '')
            .compareTo(b['filmStock'] as String? ?? ''));
      case _RecipeSortField.dateCreated:
        list.sort((a, b) => (b['createdAt'] as int? ?? 0)
            .compareTo(a['createdAt'] as int? ?? 0));
      case _RecipeSortField.developer:
        list.sort((a, b) => (a['developer'] as String? ?? '')
            .compareTo(b['developer'] as String? ?? ''));
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


  Future<void> _shareRecipe(Map<String, dynamic> recipe) async {
    final l = AppLocalizations.of(context);
    try {
      final path = await RecipeStorage.exportRecipe(recipe);
      final shareText = recipe['filmStock'] as String? ?? 'Recipe';
      await ImportExportService.shareFile(path, shareText);
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
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.t('import_error')),
              content: Text(e.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (parsed.type != ExportFileType.recipe) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.t('import_error')),
              content: Text(l.t('import_invalid_file')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Show preview confirmation
      if (!mounted) return;
      final summary = ImportExportService.previewSummary(parsed);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.t('import_preview_recipe_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.t('import_preview_recipe_film',
                  {'value': summary['filmStock']!})),
              Text(l.t('import_preview_recipe_developer',
                  {'value': summary['developer']!})),
              Text(l.t('import_preview_recipe_steps',
                  {'value': summary['steps']!})),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.t('import_cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.t('import_confirm')),
            ),
          ],
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
    return showDialog<DuplicateAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('import_duplicate_title')),
        content: Text(l.t('import_duplicate_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('import_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, DuplicateAction.skip),
            child: Text(l.t('import_duplicate_skip')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, DuplicateAction.duplicate),
            child: Text(l.t('import_duplicate_copy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, DuplicateAction.replace),
            child: Text(l.t('import_duplicate_replace')),
          ),
        ],
      ),
    );
  }

  void _startTimer(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TimerRunningPage(recipe: recipe)),
    );
  }

  String _recipeTitle(Map<String, dynamic> recipe) {
    final filmStock = recipe['filmStock'] as String? ?? '';
    final developer = recipe['developer'] as String? ?? '';
    final dilution = recipe['dilution'] as String? ?? '';
    final parts = <String>[filmStock];
    if (developer.isNotEmpty) parts.add(developer);
    if (dilution.isNotEmpty) parts.add(dilution);
    return parts.join(' \u2022 ');
  }

  String _recipeSubtitle(Map<String, dynamic> recipe, AppLocalizations l) {
    final baseTemp = recipe['baseTemp'] as num?;
    final notes = recipe['notes'] as String? ?? '';
    final parts = <String>[];
    if (baseTemp != null) {
      parts.add('${baseTemp.toStringAsFixed(1)}\u00b0C');
    }
    if (notes.isNotEmpty) parts.add(notes);
    return parts.join(' \u2022 ');
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
                _sortMenuItem(_RecipeSortField.filmStock,
                    l.t('sort_film_stock')),
                _sortMenuItem(_RecipeSortField.developer,
                    l.t('sort_developer')),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l.t('recipe_import'),
            onPressed: _importRecipe,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: false,
      floatingActionButton: FloatingActionButton(
        onPressed: _createRecipe,
        child: const Icon(Icons.add),
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
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredRecipes.length,
                              itemBuilder: (context, index) {
                                final recipe = _filteredRecipes[index];
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: colorScheme.outlineVariant),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _startTimer(recipe),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _recipeTitle(recipe),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _recipeSubtitle(
                                                      recipe, l),
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: colorScheme
                                                          .onSurfaceVariant),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 20),
                                            onPressed: () =>
                                                _editRecipe(recipe),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.copy_outlined,
                                                size: 20),
                                            tooltip:
                                                l.t('recipe_duplicate'),
                                            onPressed: () =>
                                                _duplicateRecipe(recipe),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.share_outlined,
                                                size: 20),
                                            onPressed: () =>
                                                _shareRecipe(recipe),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
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
