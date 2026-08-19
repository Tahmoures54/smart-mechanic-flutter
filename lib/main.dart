import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'services/audio_service.dart';
import 'services/ai_diagnostic_service.dart';
import 'services/map_service.dart';
import 'services/api_service.dart';
import 'services/sound_analyzer.dart';
import 'screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── Entry Point ──
// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── تنظیم ErrorWidget در ابتدای برنامه (جلوگیری از Side-Effect در Build) ──
  _setupErrorWidget();

  // ── نمایش اطلاعات محیط در debug ──
  Constants.printInfo();

  // ── قفل جهت صفحه ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── استایل نوار وضعیت ──
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ── Hive ──
  await _initHive();

  // ── سرویس‌ها ──
  final services = await _initServices();

  // ── Providers Async ──
  final localeProvider = await LocaleProvider.create();
  // ✅ اصلاح باگ بحرتی: خواندن تم ذخیره شده کاربر
  final themeProvider = await ThemeProvider.create();

  runApp(
    MultiProvider(
      providers: [
        // ── API ──
        Provider<ApiService>.value(value: services.api),

        // ── Auth ──
        ChangeNotifierProvider(
          create: (_) => AuthProvider(services.api)..checkAuthStatus(),
        ),

        // ── Audio ──
        Provider<AudioService>.value(value: services.audio),

        // ── AI Diagnostic ──
        Provider<AIDiagnosticService>(
          create: (_) => AIDiagnosticService(apiService: services.api),
        ),

        // ── Map ──
        Provider<MapService>(
          create: (_) => MapService(),
          dispose: (_, s) => s.dispose(),
        ),

        // ── Sound Analyzer ──
        Provider<SoundAnalyzer>(
          create: (_) => SoundAnalyzer(),
        ),

        // ── Theme (تزریق نمونه ساخته شده) ──
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),

        // ── Locale ──
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: const SmartMechanicApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── تنظیم ErrorWidget ──
// ─────────────────────────────────────────────────────────────────────────────
void _setupErrorWidget() {
  ErrorWidget.builder = (details) {
    debugPrint('[ErrorBoundary] ${details.exception}');
    return Material(
      color: const Color(0xFF0D0D12), // رنگ پس‌زمینه دارک
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              const Text('مشکلی پیش آمد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                'لطفاً اپلیکیشن را مجدداً باز کنید.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ مقداردهی Hive ──
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _initHive() async {
  await Hive.initFlutter();

  final boxNames = [
    Constants.boxDiagnostics,
    Constants.boxHistory,
    Constants.boxUserProfile,
  ];

  for (final name in boxNames) {
    try {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name);
      }
    } catch (e) {
      debugPrint('[Hive] خطا در باز کردن box "$name": $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ نتیجه مقداردهی سرویس‌ها ──
// ─────────────────────────────────────────────────────────────────────────────
class _AppServices {
  final ApiService api;
  final AudioService audio;

  const _AppServices({required this.api, required this.audio});
}

Future<_AppServices> _initServices() async {
  final httpClient = http.Client();
  final api = ApiService(httpClient: httpClient);

  final audio = AudioService();
  try {
    await audio.init();
  } catch (e) {
    debugPrint('[AudioService] خطا در مقداردهی (ادامه بدون صدا): $e');
  }

  return _AppServices(api: api, audio: audio);
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ App اصلی ──
// ─────────────────────────────────────────────────────────────────────────────
class SmartMechanicApp extends StatelessWidget {
  const SmartMechanicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,

      // ── زبان ──
      locale: localeProvider.locale,
      supportedLocales: LocaleConfig.flutterLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── تم ──
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      // ── جهت متن ──
      builder: (context, child) {
        return Directionality(
          textDirection: localeProvider.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },

      // ── صفحه اولیه ──
      home: const _AppEntryPoint(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── نقطه ورود (Auth Check) ──
// ─────────────────────────────────────────────────────────────────────────────
class _AppEntryPoint extends StatelessWidget {
  const _AppEntryPoint();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) return const _SplashScreen();
    return const HomeScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ Splash Screen ──
// ─────────────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.secondary.withOpacity(0.12),
                  ),
                  child: Icon(Icons.directions_car_filled_rounded, size: 72, color: theme.colorScheme.secondary),
                ),
                const SizedBox(height: 20),
                Text(Constants.appName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                const SizedBox(height: 8),
                Text('در حال بارگذاری...', style: TextStyle(fontSize: 13, color: theme.hintColor)),
                const SizedBox(height: 32),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ تم‌های اپ (تکمیل شده برای Material 3) ──
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D0D12),
    colorScheme: const ColorScheme.dark(
      primary: Colors.orange,
      onPrimary: Colors.black, // ✅ متن روی دکمه نارنجی
      secondary: Colors.amber,
      onSecondary: Colors.black, // ✅ متن روی دکمه کهربایی
      surface: Color(0xFF1A1A24),
      onSurface: Colors.white, // ✅ متن روی کارت‌ها
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    cardColor: const Color(0xFF1A1A24),
    dividerColor: const Color(0xFF2A2A36),
    textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D0D12),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A24),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    scaffoldBackgroundColor: const Color(0xFFF5F5FA),
    colorScheme: const ColorScheme.light(
      primary: Colors.orange,
      onPrimary: Colors.white,
      secondary: Colors.amber,
      onSecondary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black87,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
