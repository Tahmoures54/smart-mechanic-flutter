import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class LocaleProvider with ChangeNotifier {
  Locale? _locale;
  Locale get locale => _locale!;

  LocaleProvider(this._locale);

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  static const supportedLocales = [
    Locale('fa', 'IR'), // فارسی
    Locale('ar', 'SA'), // عربی
    Locale('tr', 'TR'), // ترکی
    Locale('ur', 'PK'), // اردو
    Locale('zh', 'CN'), // چینی ( semplified)
    Locale('ja', 'JP'), // ژاپنی
    Locale('ko', 'KR'), // کره‌ای
  ];

  static Locale getDeviceLocale() {
    final deviceLocale = Locale(WidgetsBinding.instance.platformDispatcher.locale.languageCode);
    // بررسی_support locale
    for (var locale in supportedLocales) {
      if (locale.languageCode == deviceLocale.languageCode) {
        return locale;
      }
    }
    return Locale('fa', 'IR'); // پیش‌فرض
  }
}

// استفاده در MaterialApp:
MaterialApp(
  locale: LocaleProvider.getDeviceLocale(),
  supportedLocales: LocaleProvider.supportedLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: HomeScreen(),
);
