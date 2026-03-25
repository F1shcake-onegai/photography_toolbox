import 'package:flutter/material.dart';
import '../services/developer_settings.dart';
import '../services/error_log.dart';
import '../services/app_localizations.dart';

class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key});

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  bool _verbose = DeveloperSettings.verbose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l.t('dev_title')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text(l.t('dev_verbose')),
              subtitle: Text(l.t('dev_verbose_desc'),
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant)),
              value: _verbose,
              onChanged: (v) async {
                await DeveloperSettings.setVerbose(v);
                setState(() => _verbose = v);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(l.t('dev_error_logs')),
              subtitle: Text(
                l.t('dev_error_logs_count',
                    {'count': ErrorLog.entries.length.toString()}),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _ErrorLogListPage()),
              ).then((_) => setState(() {})),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorLogListPage extends StatefulWidget {
  const _ErrorLogListPage();

  @override
  State<_ErrorLogListPage> createState() => _ErrorLogListPageState();
}

class _ErrorLogListPageState extends State<_ErrorLogListPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final entries = ErrorLog.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l.t('dev_error_logs')),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.t('dev_clear_logs')),
                    content: Text(l.t('dev_clear_logs_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.t('cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.t('dev_clear'),
                            style: TextStyle(color: colorScheme.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ErrorLog.clear();
                  setState(() {});
                }
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(l.t('dev_no_logs'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final time =
                    '${entry.timestamp.month}/${entry.timestamp.day} '
                    '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                    '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                    '${entry.timestamp.second.toString().padLeft(2, '0')}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.source,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    entry.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Text(time,
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _ErrorDetailPage(entry: entry)),
                  ),
                );
              },
            ),
    );
  }
}

class _ErrorDetailPage extends StatelessWidget {
  final ErrorEntry entry;

  const _ErrorDetailPage({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final time =
        '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-'
        '${entry.timestamp.day.toString().padLeft(2, '0')} '
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l.t('dev_error_detail')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(l.t('dev_error_time'), time, colorScheme),
            const SizedBox(height: 16),
            _section(l.t('dev_error_source'), entry.source, colorScheme),
            const SizedBox(height: 16),
            _section(l.t('dev_error_message'), entry.message, colorScheme),
            if (entry.stackTrace != null) ...[
              const SizedBox(height: 16),
              _section(
                  l.t('dev_error_stack'), entry.stackTrace!, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String label, String content, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        SelectableText(content,
            style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
