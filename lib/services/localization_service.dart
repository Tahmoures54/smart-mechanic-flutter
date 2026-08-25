import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── مدل اطلاعات یک زبان ──
// ─────────────────────────────────────────────────────────────────────────────
class AppLocale {
  final Locale locale;
  final String nativeName;    // نام زبان به خود آن زبان
  final String englishName;   // نام زبان به انگلیسی
  final String flag;          // ایموجی پرچم
  final TextDirection direction;

  const AppLocale({
    required this.locale,
    required this.nativeName,
    required this.englishName,
    required this.flag,
    required this.direction,
  });

  bool get isRTL => direction == TextDirection.rtl;
  String get languageCode => locale.languageCode;
  String get countryCode => locale.countryCode ?? '';

  /// کلید یکتا برای SharedPreferences
  String get storageKey => '${locale.languageCode}_${locale.countryCode}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppLocale && other.locale == locale);

  @override
  int get hashCode => locale.hashCode;

  @override
  String toString() => 'AppLocale($languageCode, $nativeName)';
}

// ─────────────────────────────────────────────────────────────────────────────
// ── کانفیگ زبان‌های پشتیبانی‌شده ──
// ─────────────────────────────────────────────────────────────────────────────
class LocaleConfig {
  LocaleConfig._(); // جلوگیری از نمونه‌سازی

  // ── زبان پیش‌فرض ──
  static const AppLocale defaultLocale = _persian;

  // ── کلید ذخیره‌سازی ──
  static const String _storageKey = 'selected_locale';

  // ── تعریف زبان‌ها ──
  static const AppLocale _persian = AppLocale(
    locale: Locale('fa', 'IR'),
    nativeName: 'فارسی',
    englishName: 'Persian',
    flag: '🇮🇷',
    direction: TextDirection.rtl,
  );

  static const AppLocale _arabic = AppLocale(
    locale: Locale('ar', 'SA'),
    nativeName: 'العربية',
    englishName: 'Arabic',
    flag: '🇸🇦',
    direction: TextDirection.rtl,
  );

  static const AppLocale _turkish = AppLocale(
    locale: Locale('tr', 'TR'),
    nativeName: 'Türkçe',
    englishName: 'Turkish',
    flag: '🇹🇷',
    direction: TextDirection.ltr,
  );

  static const AppLocale _urdu = AppLocale(
    locale: Locale('ur', 'PK'),
    nativeName: 'اردو',
    englishName: 'Urdu',
    flag: '🇵🇰',
    direction: TextDirection.rtl,
  );

  static const AppLocale _chinese = AppLocale(
    locale: Locale('zh', 'CN'),
    nativeName: '中文',
    englishName: 'Chinese',
    flag: '🇨🇳',
    direction: TextDirection.ltr,
  );

  static const AppLocale _japanese = AppLocale(
    locale: Locale('ja', 'JP'),
    nativeName: '日本語',
    englishName: 'Japanese',
    flag: '🇯🇵',
    direction: TextDirection.ltr,
  );

  static const AppLocale _korean = AppLocale(
    locale: Locale('ko', 'KR'),
    nativeName: '한국어',
    englishName: 'Korean',
    flag: '🇰🇷',
    direction: TextDirection.ltr,
  );

  static const AppLocale _english = AppLocale(
    locale: Locale('en', 'US'),
    nativeName: 'English',
    englishName: 'English',
    flag: '🇺🇸',
    direction: TextDirection.ltr,
  );

  // ── لیست تمام زبان‌های پشتیبانی‌شده ──
  static const List<AppLocale> supportedLocales = [
    _persian,
    _arabic,
    _urdu,
    _turkish,
    _english,
    _chinese,
    _japanese,
    _korean,
  ];

  /// فقط Locale برای MaterialApp
  static List<Locale> get flutterLocales =>
      supportedLocales.map((l) => l.locale).toList();

  // ─────────────────────────────────────────
  // ─ـ پیدا کردن زبان ──
  // ─────────────────────────────────────────

  static AppLocale? findByLocale(Locale locale) {
    for (final l in supportedLocales) {
      if (l.locale == locale) return l;
    }
    return null;
  }

  static AppLocale? findByLanguageCode(String code) {
    for (final l in supportedLocales) {
      if (l.languageCode == code) return l;
    }
    return null;
  }

  static AppLocale? findByStorageKey(String key) {
    for (final l in supportedLocales) {
      if (l.storageKey == key) return l;
    }
    return null;
  }

  // ─────────────────────────────────────────
  // ─ـ تشخیص زبان دستگاه ──
  // ─────────────────────────────────────────
  static AppLocale getDeviceLocale() {
    final deviceLang = 
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return findByLanguageCode(deviceLang) ?? defaultLocale;
  }

  // ─────────────────────────────────────────
  // ─ـ ذخیره‌سازی و بارگذاری ──
  // ─────────────────────────────────────────
  static Future<void> saveLocale(AppLocale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, locale.storageKey);
    } catch (e) {
      debugPrint('[LocaleConfig] خطا در ذخیره زبان: $e');
    }
  }

  static Future<AppLocale> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        final found = findByStorageKey(saved);
        if (found != null) return found;
      }
    } catch (e) {
      debugPrint('[LocaleConfig] خطا در بارگذاری زبان: $e');
    }
    // اگر چیزی ذخیره نشده بود، زبان دستگاه را بگیر
    return getDeviceLocale();
  }

  static Future<void> clearSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('[LocaleConfig] خطا در حذف زبان ذخیره‌شده: $e');
    }
  }

  // ─────────────────────────────────────────
  // ─ـ اطلاعات RTL ──
  // ─────────────────────────────────────────

  static List<AppLocale> get rtlLocales =>
      supportedLocales.where((l) => l.isRTL).toList();

  static List<AppLocale> get ltrLocales =>
      supportedLocales.where((l) => !l.isRTL).toList();

  static bool isRTLLocale(Locale locale) {
    return findByLocale(locale)?.isRTL ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ Provider مدیریت زبان ──
// ─────────────────────────────────────────────────────────────────────────────
class LocaleProvider with ChangeNotifier {
  AppLocale _currentLocale;
  bool _isLoading = false;

  LocaleProvider(AppLocale initialLocale) : _currentLocale = initialLocale;

  // ─────────────────────────────────────────
  // ─ـ Getters ──
  // ─────────────────────────────────────────
  AppLocale get currentLocale => _currentLocale;
  Locale get locale => _currentLocale.locale;
  TextDirection get textDirection => _currentLocale.direction;
  bool get isRTL => _currentLocale.isRTL;
  bool get isLoading => _isLoading;
  String get languageCode => _currentLocale.languageCode;

  /// لیست تمام زبان‌ها برای نمایش در UI
  List<AppLocale> get availableLocales => LocaleConfig.supportedLocales;

  // ─────────────────────────────────────────
  // ─ـ ساخت با بارگذاری از حافظه ──
  // ─────────────────────────────────────────
  static Future<LocaleProvider> create() async {
    final saved = await LocaleConfig.loadSavedLocale();
    return LocaleProvider(saved);
  }

  // ─────────────────────────────────────────
  // ─ـ تغییر زبان ──
  // ─────────────────────────────────────────
  Future<void> setLocale(AppLocale newLocale) async {
    if (_currentLocale == newLocale) return;

    _isLoading = true;
    notifyListeners();

    try {
      _currentLocale = newLocale;
      await LocaleConfig.saveLocale(newLocale);
      debugPrint('[LocaleProvider] زبان تغییر کرد: ${newLocale.nativeName}');
    } catch (e) {
      debugPrint('[LocaleProvider] خطا در تغییر زبان: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تغییر از طریق Locale مستقیم
  Future<void> setLocaleByLocale(Locale locale) async {
    final found = LocaleConfig.findByLocale(locale);
    if (found != null) await setLocale(found);
  }

  /// تغییر از طریق کد زبان
  Future<void> setLocaleByCode(String code) async {
    final found = LocaleConfig.findByLanguageCode(code);
    if (found != null) await setLocale(found);
  }

  // ─────────────────────────────────────────
  // ─ـ بازگشت به پیش‌فرض ──
  // ─────────────────────────────────────────
  Future<void> resetToDefault() async {
    await LocaleConfig.clearSavedLocale();
    await setLocale(LocaleConfig.defaultLocale);
  }

  /// بازگشت به زبان دستگاه
  Future<void> resetToDeviceLocale() async {
    await LocaleConfig.clearSavedLocale();
    await setLocale(LocaleConfig.getDeviceLocale());
  }

  // ─────────────────────────────────────────
  // ─ـ بررسی انتخاب ──
  // ─────────────────────────────────────────
  bool isSelected(AppLocale locale) => _currentLocale == locale;
  bool isSelectedByCode(String code) => _currentLocale.languageCode == code;
}
