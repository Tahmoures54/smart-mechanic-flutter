import 'package:flutter/material.dart';

/// هویت بصری مکانیک هوشمند — منبع: `logo.png` ریشهٔ پروژه
class Brand {
  Brand._();

  static const String nameFa = 'مکانیک هوشمند';
  static const String nameEn = 'Smart Mechanic';
  static const String shortName = 'Smart Mec';
  static const String tagline = 'عیب‌یابی هوشمند خودرو';
  static const String taglineEn = 'AI car diagnostics you can trust';
}

/// مسیر دارایی‌های برند
class BrandAssets {
  BrandAssets._();

  static const String logo = 'assets/branding/logo.png';
  static const String appIcon = 'assets/branding/app_icon.png';
  static const String splashMark = 'assets/branding/splash_mark.png';
  static const String banner = 'assets/branding/banner.png';
}

/// پالت استخراج‌شده از لوگوی رسمی (چرخ‌دنده + قفل طلایی)
class BrandColors {
  BrandColors._();

  static const Color gold = Color(0xFFE4BA56);
  static const Color goldLight = Color(0xFFF5DFB0);
  static const Color goldDark = Color(0xFFD6A330);
  static const Color orange = Color(0xFFFF9800);

  static const Color darkBackground = Color(0xFF0D0D12);
  static const Color darkSurface = Color(0xFF1A1A24);
  static const Color lightBackground = Color(0xFFF5F5FA);

  static const Color textOnDark = Colors.white;
  static const Color textOnLight = Color(0xFF1C1E21);
  static const Color textSecondaryOnDark = Color(0xFFB0B0C0);
  static const Color textSecondaryOnLight = Color(0xFF5A6472);

  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
}
