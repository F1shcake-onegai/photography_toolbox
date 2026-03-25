import 'package:flutter/material.dart';
import '../services/app_localizations.dart';

class _Feature {
  final String titleKey;
  final IconData icon;
  final String route;

  const _Feature({required this.titleKey, required this.icon, required this.route});
}

const _features = [
  _Feature(titleKey: 'feature_film_quick_note', icon: Icons.note_alt_outlined, route: '/film_quick_note'),
  _Feature(titleKey: 'feature_darkroom_clock', icon: Icons.timer_outlined, route: '/darkroom_timer'),
  _Feature(titleKey: 'feature_flash_calculator', icon: Icons.flash_on_outlined, route: '/flash_calculator'),
  _Feature(titleKey: 'feature_depth_of_field', icon: Icons.camera_outlined, route: '/dof_calculator'),
  _Feature(titleKey: 'feature_reciprocity', icon: Icons.exposure, route: '/reciprocity_calculator'),
  _Feature(titleKey: 'feature_light_meter', icon: Icons.wb_sunny_outlined, route: '/light_meter'),
  _Feature(titleKey: 'feature_lightpad', icon: Icons.lightbulb_outlined, route: '/lightpad'),
  _Feature(titleKey: 'feature_chemical_mixer', icon: Icons.science_outlined, route: '/chemical_mixer'),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

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
                    l.t('app_title'),
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('app_subtitle'),
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
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.3,
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
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ),          ],
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
    final l = AppLocalizations.of(context);

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
                l.t(feature.titleKey),
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
