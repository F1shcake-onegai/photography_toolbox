import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/film_storage.dart';
import '../services/app_localizations.dart';
import 'roll_detail_page.dart';

class FilmQuickNotePage extends StatefulWidget {
  const FilmQuickNotePage({super.key});

  @override
  State<FilmQuickNotePage> createState() => _FilmQuickNotePageState();
}

class _FilmQuickNotePageState extends State<FilmQuickNotePage> {
  List<Map<String, dynamic>> _rolls = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadRolls();
  }

  Future<void> _loadRolls() async {
    final rolls = await FilmStorage.loadRolls();
    setState(() {
      _rolls = rolls;
      _loaded = true;
    });
  }

  Future<void> _addRoll() async {
    final l = AppLocalizations.of(context);
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final isoCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('film_new_roll')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: brandCtrl,
              decoration: InputDecoration(
                labelText: l.t('film_brand'),
                hintText: l.t('film_brand_hint'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelCtrl,
              decoration: InputDecoration(
                labelText: l.t('film_model'),
                hintText: l.t('film_model_hint'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: isoCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.t('film_sensitivity'),
                hintText: l.t('film_sensitivity_hint'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('film_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('film_create')),
          ),
        ],
      ),
    );

    if (result == true) {
      final brand = brandCtrl.text.trim();
      final model = modelCtrl.text.trim();
      final iso = isoCtrl.text.trim();
      if (brand.isEmpty && model.isEmpty) return;

      final roll = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'brand': brand,
        'model': model,
        'sensitivity': iso,
        'comments': '',
        'shots': <Map<String, dynamic>>[],
      };
      _rolls.add(roll);
      await FilmStorage.saveRolls(_rolls);
      setState(() {});
    }

    brandCtrl.dispose();
    modelCtrl.dispose();
    isoCtrl.dispose();
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
        title: Text(l.t('film_title')),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoll,
        child: const Icon(Icons.add),
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
                              color:
                                  colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text(l.t('film_add_hint'),
                          style: TextStyle(
                              fontSize: 14,
                              color:
                                  colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rolls.length,
                  itemBuilder: (context, index) {
                    final roll = _rolls[index];
                    final shots = (roll['shots'] as List?) ?? [];
                    return Card(                      elevation: 0,                      shape: RoundedRectangleBorder(                        borderRadius: BorderRadius.circular(12),                        side: BorderSide(                            color: colorScheme.outlineVariant),                      ),                      child: InkWell(                        borderRadius: BorderRadius.circular(12),                        onTap: () => _openRoll(roll),                        child: Padding(                          padding: const EdgeInsets.all(16),                          child: Column(                            crossAxisAlignment:                                CrossAxisAlignment.start,                            children: [                              Row(                                children: [                                  Icon(Icons.camera_roll,                                      color: colorScheme.primary),                                  const SizedBox(width: 12),                                  Expanded(                                    child: Text(                                        '${roll["brand"]} ${roll["model"]}',                                        style: Theme.of(context)                                            .textTheme                                            .titleSmall),                                  ),                                  Text(                                      _formatDate(roll["id"] as String),                                      style: TextStyle(                                          fontSize: 11,                                          color: colorScheme                                              .onSurfaceVariant)),                                ],                              ),                              const SizedBox(height: 4),                              Padding(                                padding:                                    const EdgeInsets.only(left: 36),                                child: Text(                                    'ISO ${roll["sensitivity"]}'                                    ' \u2022 ${l.t("film_shots_count", {"count": shots.length.toString()})}',                                    style: TextStyle(                                        fontSize: 13,                                        color: colorScheme                                            .onSurfaceVariant)),                              ),                              if ((roll["comments"] as String?)                                      ?.isNotEmpty ==                                  true)                                Padding(                                  padding: const EdgeInsets.only(                                      left: 36, top: 4),                                  child: Text(                                      roll["comments"] as String,                                      maxLines: 1,                                      overflow:                                          TextOverflow.ellipsis,                                      style: TextStyle(                                          fontSize: 12,                                          fontStyle:                                              FontStyle.italic,                                          color: colorScheme                                              .onSurfaceVariant)),                                ),                            ],                          ),                        ),                      ),                    );
                  },
                ),
    );
  }
}

extension on _FilmQuickNotePageState {
  String _formatDate(String msString) {
    final ms = int.tryParse(msString);
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
