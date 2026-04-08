import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/app_localizations.dart';
import 'services/file_intent_service.dart';
import 'services/import_export_service.dart';
import 'services/developer_settings.dart';
import 'services/error_log.dart';
import 'services/locale_settings.dart';
import 'services/location_settings.dart';
import 'pages/developer_page.dart';
import 'pages/home_page.dart';
import 'pages/flash_calculator_page.dart';
import 'pages/dof_calculator_page.dart';
import 'pages/film_quick_note_page.dart';
import 'pages/darkroom_timer_page.dart';
import 'pages/light_meter_page.dart';
import 'pages/lightpad_page.dart';
import 'pages/reciprocity_calculator_page.dart';
import 'pages/settings_page.dart';
import 'pages/chemical_mixer_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(['OpenGrains'], license);
  });
  final savedLocale = await LocaleSettings.load();
  await DeveloperSettings.load();
  await ErrorLog.load();
  await LocationSettings.load();
  runApp(PhotographyToolboxApp(initialLocale: savedLocale));
}

class PhotographyToolboxApp extends StatefulWidget {
  final String? initialLocale;
  const PhotographyToolboxApp({super.key, this.initialLocale});

  static void setLocale(BuildContext context, String? localeCode) {
    final state = context.findAncestorStateOfType<_PhotographyToolboxAppState>();
    state?._setLocale(localeCode);
  }

  @override
  State<PhotographyToolboxApp> createState() => _PhotographyToolboxAppState();
}

class _PhotographyToolboxAppState extends State<PhotographyToolboxApp> {
  Locale? _locale;
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _fileSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocale != null) {
      _locale = Locale(widget.initialLocale!);
    }
    _initFileHandler();
  }

  Future<void> _initFileHandler() async {
    await FileIntentService.init();
    _fileSub = FileIntentService.incomingFiles.listen(_handleIncomingFile);
  }

  void _handleIncomingFile(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.ptrecipe')) {
      _routeToImport(filePath, '/darkroom_timer');
    } else if (lower.endsWith('.ptroll') || lower.endsWith('.zip')) {
      _routeToImport(filePath, '/film_quick_note');
    } else if (lower.endsWith('.json')) {
      _routeJsonFile(filePath);
    }
  }

  Future<void> _routeJsonFile(String filePath) async {
    try {
      final parsed = await ImportExportService.parseImportFile(filePath);
      final route = parsed.type == ExportFileType.recipe
          ? '/darkroom_timer'
          : '/film_quick_note';
      _routeToImport(filePath, route);
    } catch (_) {
      // Not a valid import file — ignore
    }
  }

  void _routeToImport(String filePath, String route) {
    FileIntentService.pendingFilePath = filePath;
    _navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
  }

  @override
  void dispose() {
    _fileSub?.cancel();
    super.dispose();
  }

  void _setLocale(String? localeCode) {
    setState(() {
      _locale = localeCode != null ? Locale(localeCode) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'OpenGrains',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6B5B4B),
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'NotoSans',
        fontFamilyFallback: const ['NotoSansJP', 'NotoSansSC'],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6B5B4B),
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'NotoSans',
        fontFamilyFallback: const ['NotoSansJP', 'NotoSansSC'],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale?.languageCode) {
            return supported;
          }
        }
        return const Locale('en');
      },
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: child,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/flash_calculator': (context) => const FlashCalculatorPage(),
        '/dof_calculator': (context) => const DofCalculatorPage(),
        '/film_quick_note': (context) => const FilmQuickNotePage(),
        '/darkroom_timer': (context) => const DarkroomTimerPage(),
        '/light_meter': (context) => const LightMeterPage(),
        '/reciprocity_calculator': (context) => const ReciprocityCalculatorPage(),
        '/lightpad': (context) => const LightpadPage(),
        '/settings': (context) => const SettingsPage(),
        '/chemical_mixer': (context) => const ChemicalMixerPage(),
        '/developer': (context) => const DeveloperPage(),
      },
    );
  }
}
