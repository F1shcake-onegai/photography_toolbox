import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/film_storage.dart';
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
  late TextEditingController _commentCtrl;
  Timer? _saveTimer;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
    _loadRoll();
  }

  Future<void> _loadRoll() async {
    final roll = await FilmStorage.loadRoll(widget.rollId);
    if (roll != null) {
      setState(() {
        _roll = roll;
        _commentCtrl.text = roll['comments'] as String? ?? '';
      });
    }
  }

  void _onCommentChanged(String value) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_roll != null && !_deleted) {
        _roll!['comments'] = value;
        FilmStorage.updateRoll(_roll!);
      }
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // final save
    if (_roll != null && !_deleted) {
      _roll!['comments'] = _commentCtrl.text;
      FilmStorage.updateRoll(_roll!);
    }
    _commentCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _shots {
    if (_roll == null) return [];
    return (_roll!['shots'] as List)
        .cast<Map<String, dynamic>>();
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
      await FilmStorage.updateRoll(_roll!);
      setState(() {});
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
        title: Text(            '${_roll!['brand']} ${_roll!['model']}'),        actions: [          IconButton(            icon: const Icon(Icons.delete, color: Colors.red),            onPressed: _deleteRoll,          ),        ],      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addShot,
        child: const Icon(Icons.add_a_photo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Roll info
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${_roll!['brand']} ${_roll!['model']}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight:
                                    FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        'ISO ${_roll!['sensitivity']}',
                        style: TextStyle(
                            color: colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
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
              onChanged: _onCommentChanged,
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

    Widget imageWidget;
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync()) {
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
