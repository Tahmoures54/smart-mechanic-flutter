import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _themeMode;

  ThemeProvider._(this._themeMode);

  /// ساخت با بارگذاری از SharedPreferences
  static Future<ThemeProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    ThemeMode mode = ThemeMode.dark;
    if (saved == 'light') mode = ThemeMode.light;
    if (saved == 'system') mode = ThemeMode.system;

    return ThemeProvider._(mode);
  }

  /// ساخت ساده بدون SharedPreferences (برای استفاده در Provider)
  factory ThemeProvider() => ThemeProvider._(ThemeMode.dark);

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e) {
      debugPrint('[ThemeProvider] خطا در ذخیره تم: $e');
    }
  }

  void toggleTheme() {
    setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
