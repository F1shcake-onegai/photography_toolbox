import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, String> _strings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const supportedLocales = [
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  Future<void> load() async {
    final code = locale.languageCode;
    final supported = supportedLocales.map((l) => l.languageCode).toSet();
    final file = supported.contains(code) ? code : 'en';
    final jsonStr = await rootBundle.loadString('assets/i18n/$file.json');
    final Map<String, dynamic> map = json.decode(jsonStr);
    _strings = map.map((k, v) => MapEntry(k, v.toString()));
  }

  String t(String key, [Map<String, String>? params]) {
    var str = _strings[key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        str = str.replaceAll('{$k}', v);
      });
    }
    return str;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ja', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
