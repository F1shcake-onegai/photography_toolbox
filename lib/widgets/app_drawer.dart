import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Text(
              'Photography\nToolbox',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _DrawerItem(
            icon: Icons.note_alt_outlined,
            title: 'Film Quick Note',
            route: '/film_quick_note',
            selected: currentRoute == '/film_quick_note',
          ),
          _DrawerItem(
            icon: Icons.timer_outlined,
            title: 'Darkroom Clock',
            route: '/darkroom_clock',
            selected: currentRoute == '/darkroom_clock',
          ),
          _DrawerItem(
            icon: Icons.flash_on_outlined,
            title: 'Flash Calculator',
            route: '/flash_calculator',
            selected: currentRoute == '/flash_calculator',
          ),
          _DrawerItem(
            icon: Icons.camera_outlined,
            title: 'Depth of Field',
            route: '/dof_calculator',
            selected: currentRoute == '/dof_calculator',
          ),
          _DrawerItem(
            icon: Icons.lightbulb_outlined,
            title: 'Lightpad',
            route: '/lightpad',
            selected: currentRoute == '/lightpad',
          ),
          const Divider(),
          _DrawerItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            route: '/settings',
            selected: currentRoute == '/settings',
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final bool selected;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        if (!selected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
