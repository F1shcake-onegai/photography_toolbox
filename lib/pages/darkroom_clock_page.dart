import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/app_localizations.dart';

class DarkroomClockPage extends StatelessWidget {
  const DarkroomClockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        title: Text(l.t('darkroom_title')),
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l.t('darkroom_coming_soon'), style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
