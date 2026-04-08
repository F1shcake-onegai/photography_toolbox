import 'package:flutter/material.dart';
import '../services/app_localizations.dart';
import '../services/import_settings.dart';

Future<DuplicateAction?> showDuplicateImportSheet(
    BuildContext context, AppLocalizations l) {
  return showModalBottomSheet<DuplicateAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.t('import_duplicate_title'),
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l.t('import_duplicate_message'),
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, DuplicateAction.replace),
              child: Text(l.t('import_duplicate_replace')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, DuplicateAction.duplicate),
              child: Text(l.t('import_duplicate_copy')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, DuplicateAction.skip),
              child: Text(l.t('import_duplicate_skip')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.t('import_cancel')),
            ),
          ],
        ),
      ),
    ),
  );
}
