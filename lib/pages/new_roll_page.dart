import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_localizations.dart';

class NewRollPage extends StatefulWidget {
  final List<Map<String, dynamic>> existingRolls;

  const NewRollPage({super.key, required this.existingRolls});

  @override
  State<NewRollPage> createState() => _NewRollPageState();
}

class _NewRollPageState extends State<NewRollPage> {
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
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _isoCtrl.dispose();
    super.dispose();
  }

  void _buildRecentFilms() {
    final seen = <String>{};
    final recent = <_FilmStock>[];
    // Most recent rolls first
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
    setState(() {
      _brandCtrl.text = film.brand;
      _modelCtrl.text = film.model;
      _isoCtrl.text = film.iso;
      _isoManuallyEdited = false;
    });
    _create();
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
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final iso = _isoCtrl.text.trim();
    if (brand.isEmpty && model.isEmpty) return;
    Navigator.pop(context, {
      'brand': brand,
      'model': model,
      'sensitivity': iso,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l.t('film_new_roll')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recent films
            if (_recentFilms.isNotEmpty) ...[
              Text(l.t('film_recent'),
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentFilms.map((film) {
                  return GestureDetector(
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
                          if (film.iso.isNotEmpty)
                            Text('ISO ${film.iso}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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

            // Manual entry
            Text(l.t('film_brand'),
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _brandCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l.t('film_brand_hint'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.t('film_model'),
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _modelCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l.t('film_model_hint'),
                border: OutlineInputBorder(),
              ),
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
                border: OutlineInputBorder(),
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

class _FilmStock {
  final String brand;
  final String model;
  final String iso;

  const _FilmStock({
    required this.brand,
    required this.model,
    required this.iso,
  });
}
