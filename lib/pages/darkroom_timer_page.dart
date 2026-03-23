import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/app_drawer.dart';
import '../services/app_localizations.dart';
import '../services/recipe_storage.dart';
import 'recipe_edit_page.dart';
import 'timer_running_page.dart';

class DarkroomTimerPage extends StatefulWidget {
  const DarkroomTimerPage({super.key});

  @override
  State<DarkroomTimerPage> createState() => _DarkroomTimerPageState();
}

class _DarkroomTimerPageState extends State<DarkroomTimerPage> {
  List<Map<String, dynamic>> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipes = await RecipeStorage.loadRecipes();
    setState(() {
      _recipes = recipes;
      _loading = false;
    });
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
      await RecipeStorage.updateRecipe(result);
      await _load();
    }
  }

  Future<void> _deleteRecipe(Map<String, dynamic> recipe) async {
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
    if (confirmed == true) {
      await RecipeStorage.deleteRecipe(recipe['id'] as String);
      await _load();
    }
  }

  Future<void> _shareRecipe(Map<String, dynamic> recipe) async {
    final path = await RecipeStorage.exportRecipe(recipe);
    final shareText = recipe['filmStock'] as String? ?? 'Recipe';
    await Share.shareXFiles([XFile(path)], text: shareText);
  }

  Future<void> _importRecipe() async {
    final l = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;
      await RecipeStorage.importRecipe(result.files.single.path!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('recipe_imported'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('recipe_import_error'))),
        );
      }
    }
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
    final summary = _stepSummary(recipe, l);
    final baseTemp = recipe['baseTemp'] as num?;
    if (baseTemp != null) {
      return '$summary \u2022 ${baseTemp.toStringAsFixed(1)}\u00b0C';
    }
    return summary;
  }

  String _stepSummary(Map<String, dynamic> recipe, AppLocalizations l) {
    final steps = (recipe['steps'] as List?) ?? [];
    final devCount = steps.where((s) => s['type'] == 'develop').length;
    final stopCount = steps.where((s) => s['type'] == 'stop').length;
    final fixCount = steps.where((s) => s['type'] == 'fix').length;
    final washCount = steps.where((s) => s['type'] == 'wash').length;
    final rinseCount = steps.where((s) => s['type'] == 'rinse').length;
    final parts = <String>[];
    if (devCount > 0) {
      parts.add('${l.t("recipe_step_develop")} \u00d7$devCount');
    }
    if (stopCount > 0) parts.add(l.t('recipe_step_stop'));
    if (fixCount > 0) parts.add(l.t('recipe_step_fix'));
    if (washCount > 1) {
      parts.add('${l.t("recipe_step_wash")} \u00d7$washCount');
    } else if (washCount == 1) {
      parts.add(l.t('recipe_step_wash'));
    }
    if (rinseCount > 1) {
      parts.add('${l.t("recipe_step_rinse")} \u00d7$rinseCount');
    } else if (rinseCount == 1) {
      parts.add(l.t('recipe_step_rinse'));
    }
    final customCount = steps.where((s) => s['type'] == 'custom').length;
    if (customCount > 1) {
      parts.add('${l.t("recipe_step_custom")} \u00d7$customCount');
    } else if (customCount == 1) {
      parts.add(l.t('recipe_step_custom'));
    }
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
              Navigator.pushReplacementNamed(context, '/'),
        ),
        title: Text(l.t('darkroom_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l.t('recipe_import'),
            onPressed: _importRecipe,
          ),
        ],
      ),
      drawer: const AppDrawer(),
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _recipes[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _startTimer(recipe),
                        onLongPress: () => _deleteRecipe(recipe),
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
                                      _recipeSubtitle(recipe, l),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme
                                              .onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20),
                                onPressed: () => _editRecipe(recipe),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined,
                                    size: 20),
                                onPressed: () => _shareRecipe(recipe),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
