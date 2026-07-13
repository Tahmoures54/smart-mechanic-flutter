import 'package:flutter/material.dart';

/// کلاس کانفیگ برای جداسازی ثابت‌ها (رعایت SRP)
class LocaleConfig {
  static const List<Locale> supportedLocales = [
    Locale('fa', 'IR'), // فارسی
    Locale('ar', 'SA'), // عربی
    Locale('tr', 'TR'), // ترکی
    Locale('ur', 'PK'), // اردو
    Locale('zh', 'CN'), // چینی (Simplified)
    Locale('ja', 'JP'), // ژاپنی
    Locale('ko', 'KR'), // کره‌ای
  ];

  static Locale getDeviceLocale() {
    final deviceLanguageCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    
    // استفاده از firstWhere برای خوانایی و بهینه‌سازی بهتر
    try {
      return supportedLocales.firstWhere(
        (locale) => locale.languageCode == deviceLanguageCode,
      );
    } catch (e) {
      return const Locale('fa', 'IR'); // پیش‌فرض در صورت پشتیبانی نشدن زبان دستگاه
    }
  }
}

/// کلاس مدیریت وضعیت زبان
class LocaleProvider with ChangeNotifier {
  Locale _locale;

  LocaleProvider(this._locale);

  // حذف علامت نال‌پذیری چون در Constructor اجباری است
  Locale get locale => _locale;

  void setLocale(Locale newLocale) {
    // جلوگیری از Rebuild بی‌مورد اگر زبان تکراری انتخاب شود
    if (_locale == newLocale) return;
    
    _locale = newLocale;
    notifyListeners();
  }
}
