import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/developer_settings.dart';
import '../services/error_log.dart';
import '../services/film_storage.dart';
import '../services/import_export_service.dart';
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
  late TextEditingController _titleCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _isoCtrl;
  late TextEditingController _commentCtrl;
  Timer? _saveTimer;
  final List<FocusNode> _trimFocusNodes = [];
  late final FocusNode _titleFocus;
  late final FocusNode _brandFocus;
  late final FocusNode _modelFocus;
  late final FocusNode _commentFocus;
  bool _deleted = false;
  int _pushPull = 0;
  String? _imgDir;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _brandCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _isoCtrl = TextEditingController();
    _commentCtrl = TextEditingController();
    _titleFocus = _makeTrimNode(_titleCtrl);
    _brandFocus = _makeTrimNode(_brandCtrl);
    _modelFocus = _makeTrimNode(_modelCtrl);
    _commentFocus = _makeTrimNode(_commentCtrl);
    _loadRoll();
    _loadImgDir();
  }

  Future<void> _loadImgDir() async {
    final dir = await FilmStorage.imageDir();
    if (mounted) setState(() => _imgDir = dir);
  }

  String get _pushPullLabel {
    if (_pushPull == 0) return '0';
    return _pushPull > 0 ? '+$_pushPull' : '$_pushPull';
  }

  Future<void> _loadRoll() async {
    final roll = await FilmStorage.loadRoll(widget.rollId);
    if (roll != null) {
      // Sort shots on load
      final shots = (roll['shots'] as List).cast<Map<String, dynamic>>();
      shots.sort(_compareShots);
      setState(() {
        _roll = roll;
        _titleCtrl.text = roll['title'] as String? ?? '';
        _brandCtrl.text = roll['brand'] as String? ?? '';
        _modelCtrl.text = roll['model'] as String? ?? '';
        _isoCtrl.text = roll['sensitivity'] as String? ?? '';
        _commentCtrl.text = roll['comments'] as String? ?? '';
        _pushPull = (roll['pushPull'] as int?) ??
            (roll['ec'] as num?)?.round() ?? 0;
      });
    }
  }

  void _onFieldChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveRoll();
    });
  }

  void _saveRoll() {
    if (_roll != null && !_deleted) {
      final title = _titleCtrl.text.trim();
      if (title.isNotEmpty) {
        _roll!['title'] = title;
      } else {
        _roll!.remove('title');
      }
      _roll!['brand'] = _brandCtrl.text;
      _roll!['model'] = _modelCtrl.text;
      _roll!['sensitivity'] = _isoCtrl.text;
      _roll!['pushPull'] = _pushPull;
      _roll!['comments'] = _commentCtrl.text;
      FilmStorage.updateRoll(_roll!);
    }
  }

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

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveRoll();
    for (final n in _trimFocusNodes) { n.dispose(); }
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _isoCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _shots {
    if (_roll == null) return [];
    return (_roll!['shots'] as List)
        .cast<Map<String, dynamic>>();
  }

  /// Compare two shots by sequence number, then by createdAt timestamp.
  static int _compareShots(Map<String, dynamic> a, Map<String, dynamic> b) {
    final seqA = a['sequence'] as int? ?? 0;
    final seqB = b['sequence'] as int? ?? 0;
    if (seqA != seqB) return seqA.compareTo(seqB);
    final tsA = a['createdAt'] as int? ?? 0;
    final tsB = b['createdAt'] as int? ?? 0;
    return tsA.compareTo(tsB);
  }

  /// Move a single shot to its sorted position (efficient single-element reposition).
  void _repositionShot(Map<String, dynamic> shot) {
    final shots = _shots;
    shots.remove(shot);
    // Find insertion point
    int insertAt = shots.length;
    for (int i = 0; i < shots.length; i++) {
      if (_compareShots(shot, shots[i]) <= 0) {
        insertAt = i;
        break;
      }
    }
    shots.insert(insertAt, shot);
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
      _repositionShot(result);
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
      _repositionShot(result);
      await FilmStorage.updateRoll(_roll!);
      setState(() {});
    }
  }


  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    return origin & size;
  }

  Future<void> _shareRoll() async {
    if (_roll == null) return;
    final l = AppLocalizations.of(context);
    final shareOrigin = _shareOrigin();
    final shots = _shots;
    if (shots.isEmpty) {
      // No shots — export roll without shot selection
      try {
        final path = await FilmStorage.exportRoll(_roll!);
        final name = '${_roll!['brand']} ${_roll!['model']}'.trim();
        await ImportExportService.shareFile(path, name, sharePositionOrigin: shareOrigin);
      } catch (e, stack) {
        ErrorLog.log('Roll Export', e, stack);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DeveloperSettings.verbose
                ? '${l.t('export_error')}: $e'
                : l.t('export_error'))),
          );
        }
      }
      return;
    }

    // Shot selection dialog
    final selected = Set<String>.from(
        shots.map((s) => s['uuid'] as String));
    final confirmed = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                return SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(l.t('share_select_shots'),
                                  style: Theme.of(ctx).textTheme.titleMedium),
                            ),
                            TextButton(
                              onPressed: () => setSheetState(() {
                                selected.addAll(
                                    shots.map((s) => s['uuid'] as String));
                              }),
                              child: Text(l.t('share_select_all')),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setSheetState(() => selected.clear()),
                              child: Text(l.t('share_select_none')),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: shots.length,
                          itemBuilder: (_, i) {
                            final shot = shots[i];
                            final uuid = shot['uuid'] as String;
                            final seq = shot['sequence'] as int;
                            final comment =
                                shot['comment'] as String? ?? '';
                            return CheckboxListTile(
                              value: selected.contains(uuid),
                              onChanged: (v) => setSheetState(() {
                                if (v == true) {
                                  selected.add(uuid);
                                } else {
                                  selected.remove(uuid);
                                }
                              }),
                              title: Text('#$seq'),
                              subtitle: comment.isNotEmpty
                                  ? Text(comment,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)
                                  : null,
                              dense: true,
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.t('share_shot_count',
                                  {'count': selected.length.toString()}),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () => Navigator.pop(ctx, selected),
                              child: Text(l.t('share_share')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (confirmed == null || confirmed.isEmpty || !mounted) return;

    try {
      final path = await FilmStorage.exportRoll(_roll!,
          selectedShotUuids: confirmed.toList());
      final name = '${_roll!['brand']} ${_roll!['model']}'.trim();
      await ImportExportService.shareFile(path, name, sharePositionOrigin: shareOrigin);
    } catch (e, stack) {
      ErrorLog.log('Roll Export', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DeveloperSettings.verbose
              ? '${l.t('export_error')}: $e'
              : l.t('export_error'))),
        );
      }
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
        title: Text('${_roll!['brand']} ${_roll!['model']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareRoll,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteRoll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addShot,
        child: const Icon(Icons.add_a_photo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Roll title
            Text(l.t('film_roll_title'),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _onFieldChanged(),
              decoration: InputDecoration(
                hintText: l.t('film_roll_title_hint'),
              ),
            ),
            const SizedBox(height: 16),

            // Roll info fields — Brand + Model (1:2 ratio)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('film_brand'),
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _brandCtrl,
                        focusNode: _brandFocus,
                        onChanged: (_) => _onFieldChanged(),
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
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _modelCtrl,
                        focusNode: _modelFocus,
                        onChanged: (_) => _onFieldChanged(),
                        decoration: InputDecoration(
                          hintText: l.t('film_model_hint'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ISO & Exposure Compensation side by side (1:3 ratio)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ISO (1/4 width)
                Flexible(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('film_sensitivity'),
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _isoCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _onFieldChanged(),
                        decoration: InputDecoration(
                          hintText: l.t('film_sensitivity_hint'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Push / Pull (3/4 width)
                Flexible(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('roll_push_pull'),
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          GestureDetector(
                            onDoubleTap: () {
                              setState(() => _pushPull = 0);
                              _onFieldChanged();
                            },
                            child: SizedBox(
                              width: 40,
                              child: Text(_pushPullLabel,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Slider(
                              value: _pushPull.toDouble(),
                              min: -3.0,
                              max: 3.0,
                              divisions: 6,
                              label: _pushPullLabel,
                              onChanged: (v) {
                                setState(() => _pushPull = v.round());
                                _onFieldChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
              focusNode: _commentFocus,
              maxLines: 3,
              onChanged: (_) => _onFieldChanged(),
              decoration: InputDecoration(
                hintText: l.t('roll_comments_hint'),
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900 ? 6
                          : constraints.maxWidth > 700 ? 5
                          : constraints.maxWidth > 500 ? 4 : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _shots.length,
                        itemBuilder: (context, index) {
                          return _shotTile(index);
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _shotTile(int index) {
    final shot = _shots[index];
    final storedPath = shot['imagePath'] as String? ?? '';
    final seq = shot['sequence'] as int;
    final colorScheme = Theme.of(context).colorScheme;

    // Resolve relative filename to absolute path
    String fullPath = storedPath;
    if (storedPath.isNotEmpty &&
        !storedPath.contains('/') &&
        !storedPath.contains('\\') &&
        _imgDir != null) {
      fullPath = '$_imgDir/$storedPath';
    }

    final hasImage = fullPath.isNotEmpty && File(fullPath).existsSync();

    Widget imageWidget;
    if (hasImage) {
      imageWidget = Image.file(
        File(fullPath),
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
              if (shot['latitude'] != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withAlpha(200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.location_on,
                        size: 12, color: colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
