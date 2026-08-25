import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// پالت رنگ برند مکانیک هوشمند
class AppColors {
  AppColors._();

  // پالت اصلی
  static const Color amber = Color(0xFFFFC107);
  static const Color orange = Color(0xFFFF9800);
  static const Color amberLight = Color(0xFFFFD54F);

  // پس‌زمینه و سطح
  static const Color darkBackground = Color(0xFF0D0D12);
  static const Color darkSurface = Color(0xFF1A1A24);
  static const Color lightBackground = Color(0xFFF5F5FA);

  // متن
  static const Color textOnDark = Colors.white;
  static const Color textOnLight = Color(0xFF1C1E21);
  static const Color textSecondaryOnDark = Color(0xFFB0B0C0);
  static const Color textSecondaryOnLight = Color(0xFF5A6472);

  // وضعیت‌ها
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
}

/// تم‌های روشن و تاریک برنامه
class AppTheme {
  AppTheme._();

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.orange,
      onPrimary: Colors.black,
      secondary: AppColors.amber,
      onSecondary: Colors.black,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textOnDark,
      error: AppColors.error,
      onError: Colors.white,
    ),
    cardColor: AppColors.darkSurface,
    dividerColor: const Color(0xFF2A2A36),
    textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppColors.textOnDark,
      displayColor: AppColors.textOnDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.textOnDark,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.amber, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.orange,
      onPrimary: Colors.white,
      secondary: AppColors.amber,
      onSecondary: Colors.black,
      surface: Colors.white,
      onSurface: AppColors.textOnLight,
      error: AppColors.error,
      onError: Colors.white,
    ),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: AppColors.textOnLight,
      displayColor: AppColors.textOnLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textOnLight,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.amber, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
