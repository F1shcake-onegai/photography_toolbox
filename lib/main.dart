import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/app_localizations.dart';
import 'services/locale_settings.dart';
import 'pages/home_page.dart';
import 'pages/flash_calculator_page.dart';
import 'pages/dof_calculator_page.dart';
import 'pages/film_quick_note_page.dart';
import 'pages/darkroom_timer_page.dart';
import 'pages/lightpad_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(['Photography Toolbox'], license);
  });
  final savedLocale = await LocaleSettings.load();
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

  @override
  void initState() {
    super.initState();
    if (widget.initialLocale != null) {
      _locale = Locale(widget.initialLocale!);
    }
  }

  void _setLocale(String? localeCode) {
    setState(() {
      _locale = localeCode != null ? Locale(localeCode) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photography Toolbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'NotoSans',
        fontFamilyFallback: const ['NotoSansJP', 'NotoSansSC'],
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'NotoSans',
        fontFamilyFallback: const ['NotoSansJP', 'NotoSansSC'],
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
        '/lightpad': (context) => const LightpadPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
