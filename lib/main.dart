import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/flash_calculator_page.dart';
import 'pages/dof_calculator_page.dart';
import 'pages/film_quick_note_page.dart';
import 'pages/darkroom_clock_page.dart';
import 'pages/lightpad_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const PhotographyToolboxApp());
}

class PhotographyToolboxApp extends StatelessWidget {
  const PhotographyToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photography Toolbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/flash_calculator': (context) => const FlashCalculatorPage(),
        '/dof_calculator': (context) => const DofCalculatorPage(),
        '/film_quick_note': (context) => const FilmQuickNotePage(),
        '/darkroom_clock': (context) => const DarkroomClockPage(),
        '/lightpad': (context) => const LightpadPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
