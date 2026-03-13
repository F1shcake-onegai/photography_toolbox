import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/aperture_settings.dart';
import '../services/app_localizations.dart';
import '../services/locale_settings.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _selectedMaxAperture = ApertureSettings.defaultMaxAperture;
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
    setState(() {
      _selectedMaxAperture = value;
      _selectedLocale = locale;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await ApertureSettings.save(_selectedMaxAperture);
    await LocaleSettings.save(_selectedLocale);
    if (mounted) {
      PhotographyToolboxApp.setLocale(context, _selectedLocale);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('settings_saved'))),
      );
    }
  }

  void _revoke() {
    setState(() {
      _selectedMaxAperture = ApertureSettings.defaultMaxAperture;
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
              Navigator.pushReplacementNamed(context, '/'),
        ),
        title: Text(l.t('settings_title')),
      ),
      drawer: const AppDrawer(),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.t('settings_heading'),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall),
                  const SizedBox(height: 24),

                  Text(l.t('settings_language'),
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLocale ?? '',
                    decoration: const InputDecoration(
                        border: OutlineInputBorder()),
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
                        border: OutlineInputBorder()),
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

                  const Spacer(),

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
