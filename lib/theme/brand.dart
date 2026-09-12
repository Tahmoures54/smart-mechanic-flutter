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

/// پالت کارگاه مکانیکی — نارنجی ابزار، زنگ فلز، نور لامپ سقفی
class BrandColors {
  BrandColors._();

  static const Color gold = Color(0xFFFFB300);
  static const Color goldLight = Color(0xFFFFE082);
  static const Color goldDark = Color(0xFFFF8F00);
  static const Color orange = Color(0xFFFF7A1A);
  static const Color orangeDeep = Color(0xFFE65100);
  static const Color orangeLight = Color(0xFFFFCC80);
  static const Color rust = Color(0xFFBF360C);

  static const Color darkBackground = Color(0xFF140C08);
  static const Color darkSurface = Color(0xFF241610);
  static const Color lightBackground = Color(0xFFFFF3E6);

  static const Color textOnDark = Colors.white;
  static const Color textOnLight = Color(0xFF2A140A);
  static const Color textSecondaryOnDark = Color(0xFFE0C8B0);
  static const Color textSecondaryOnLight = Color(0xFF6D4C3D);

  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
}
