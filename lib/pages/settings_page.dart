import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/aperture_settings.dart';
import '../services/app_localizations.dart';
import '../services/import_settings.dart';
import '../services/light_meter_constants.dart';
import '../services/locale_settings.dart';
import '../services/location_settings.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _selectedMaxAperture = ApertureSettings.defaultMaxAperture;
  ExposureStep _selectedExposureStep = ExposureStepSettings.defaultStep;
  DuplicateAction _selectedImportAction = ImportSettings.defaultAction;
  bool _autoLocation = LocationSettings.defaultValue;
  String? _selectedLocale;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final value = await ApertureSettings.load();
    final locale = await LocaleSettings.load();
    final step = await ExposureStepSettings.load();
    final importAction = await ImportSettings.load();
    final autoLoc = await LocationSettings.load();
    setState(() {
      _selectedMaxAperture = value;
      _selectedLocale = locale;
      _selectedExposureStep = step;
      _selectedImportAction = importAction;
      _autoLocation = autoLoc;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await ApertureSettings.save(_selectedMaxAperture);
    await ExposureStepSettings.save(_selectedExposureStep);
    await ImportSettings.save(_selectedImportAction);
    await LocationSettings.save(_autoLocation);
    await LocaleSettings.save(_selectedLocale);
    if (mounted) {
      PhotographyToolboxApp.setLocale(context, _selectedLocale);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('settings_saved'))),
      );
    }
  }

  String _importActionLabel(DuplicateAction action, AppLocalizations l) {
    switch (action) {
      case DuplicateAction.ask:
        return l.t('settings_import_ask');
      case DuplicateAction.replace:
        return l.t('settings_import_replace');
      case DuplicateAction.skip:
        return l.t('settings_import_skip');
      case DuplicateAction.duplicate:
        return l.t('settings_import_duplicate');
    }
  }

  void _revoke() {
    setState(() {
      _selectedMaxAperture = ApertureSettings.defaultMaxAperture;
      _selectedExposureStep = ExposureStepSettings.defaultStep;
      _selectedImportAction = ImportSettings.defaultAction;
      _autoLocation = LocationSettings.defaultValue;
      _selectedLocale = null;
    });
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
        title: Text(l.t('settings_title')),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onLongPress: () => Navigator.pushNamed(context, '/developer'),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('OpenGrains',
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text('1.4.0 (Build Apr 08, 2026)',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text('2026 @f1shcake_onegai\nLicensed under CC0 1.0 Universal',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                            const SizedBox(height: 12),
                            Text(l.t('app_about_description')),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => launchUrl(Uri.parse(
                                  'https://github.com/F1shcake-onegai/opengrains')),
                              child: const Text(
                                'github.com/F1shcake-onegai/opengrains',
                                style: TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => showLicensePage(
                              context: context,
                              applicationName: 'OpenGrains',
                              applicationVersion: '1.4.0 (Build Apr 08, 2026)',
                              applicationLegalese: '2026 @f1shcake_onegai',
                            ),
                            child: Text(MaterialLocalizations.of(context).viewLicensesButtonLabel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                          ),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('OpenGrains',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('1.4.0 (Build Apr 08, 2026)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Icon(Icons.info_outline,
                              size: 20,
                              color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  Text(l.t('settings_language'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLocale ?? '',
                    decoration: const InputDecoration(
),
                    items: [
                      DropdownMenuItem(
                          value: '',
                          child: Text(l.t('settings_follow_system'))),
                      const DropdownMenuItem(
                          value: 'en',
                          child: Text('English')),
                      const DropdownMenuItem(
                          value: 'ja',
                          child: Text('日本語')),
                      const DropdownMenuItem(
                          value: 'zh',
                          child: Text('简体中文')),
                    ],
                    onChanged: (v) {
                      setState(() =>
                          _selectedLocale = (v == null || v.isEmpty) ? null : v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('settings_language_desc'),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  Text(l.t('settings_max_aperture'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<double>(
                    initialValue: _selectedMaxAperture,
                    decoration: const InputDecoration(
),
                    items: ApertureSettings.maxApertureOptions
                        .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text('f/$v')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(
                            () => _selectedMaxAperture = v);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('settings_max_aperture_desc'),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  Text(l.t('settings_exposure_step'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ExposureStep>(
                    initialValue: _selectedExposureStep,
                    decoration: const InputDecoration(
),
                    items: ExposureStep.values
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(ExposureStepSettings.label(s))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedExposureStep = v);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('settings_exposure_step_desc'),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  Text(l.t('settings_import_action'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<DuplicateAction>(
                    initialValue: _selectedImportAction,
                    decoration: const InputDecoration(
),
                    items: DuplicateAction.values
                        .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text(_importActionLabel(a, l))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedImportAction = v);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('settings_import_action_desc'),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.t('settings_auto_location'),
                        style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface)),
                    subtitle: Text(l.t('settings_auto_location_desc'),
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant)),
                    value: _autoLocation,
                    onChanged: (v) => setState(() => _autoLocation = v),
                  ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _revoke,
                          child: Text(l.t('settings_revoke')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: Text(l.t('settings_save')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
