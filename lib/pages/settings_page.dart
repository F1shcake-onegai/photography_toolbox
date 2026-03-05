import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/aperture_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _selectedMaxAperture = ApertureSettings.defaultMaxAperture;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final value = await ApertureSettings.load();
    setState(() {
      _selectedMaxAperture = value;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await ApertureSettings.save(_selectedMaxAperture);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
    }
  }

  void _revoke() {
    setState(() =>
        _selectedMaxAperture = ApertureSettings.defaultMaxAperture);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/'),
        ),
        title: const Text('Settings'),
      ),
      drawer: const AppDrawer(),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Settings',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall),
                  const SizedBox(height: 24),

                  Text('Maximum Aperture',
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
                    'Sets the widest aperture available on '
                    'aperture sliders across the app.',
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
                          child: const Text('Revoke'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
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
