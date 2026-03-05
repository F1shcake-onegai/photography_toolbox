import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class _Feature {
  final String title;
  final IconData icon;
  final String route;

  const _Feature({required this.title, required this.icon, required this.route});
}

const _features = [
  _Feature(title: 'Film Quick Note', icon: Icons.note_alt_outlined, route: '/film_quick_note'),
  _Feature(title: 'Darkroom Clock', icon: Icons.timer_outlined, route: '/darkroom_clock'),
  _Feature(title: 'Flash Calculator', icon: Icons.flash_on_outlined, route: '/flash_calculator'),
  _Feature(title: 'Depth of Field', icon: Icons.camera_outlined, route: '/dof_calculator'),
  _Feature(title: 'Lightpad', icon: Icons.lightbulb_outlined, route: '/lightpad'),
  _Feature(title: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Photography\nToolbox',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your analog photography companion',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _features.length,
                      itemBuilder: (context, index) {
                        final feature = _features[index];
                        return _FeatureCard(feature: feature);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'Photography Toolbox',
                  applicationVersion: '1.0.0 (Build Mar 4, 2026)',
                  children: [
                    const Text(
                        'A companion app for analog photography. '
                        'Includes tools for flash calculation, '
                        'depth of field, film notes, and more.'),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(
                          'https://github.com/F1shcake-onegai/photography_toolbox')),
                      child: const Text(
                        'github.com/F1shcake-onegai/photography_toolbox',
                        style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('by @f1shcake_onegai'),
                  ],
                ),              ),            ),          ],
        ),
      ),
    );
  }

}
class _FeatureCard extends StatelessWidget {
  final _Feature feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, feature.route),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(feature.icon, size: 40, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                feature.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
