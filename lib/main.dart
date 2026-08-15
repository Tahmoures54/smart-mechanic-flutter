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
import 'screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── Entry Point ──
// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // ── LocaleProvider ──
  final localeProvider = await LocaleProvider.create();

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

        // ── Theme ──
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),

        // ── Locale ──
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      child: const SmartMechanicApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── مقداردهی Hive ──
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
// ── نتیجه مقداردهی سرویس‌ها ──
// ─────────────────────────────────────────────────────────────────────────────
class _AppServices {
  final ApiService api;
  final AudioService audio;

  const _AppServices({required this.api, required this.audio});
}

Future<_AppServices> _initServices() async {
  final httpClient = http.Client();
  final api = ApiService(httpClient: httpClient);

  // ── AudioService با مدیریت خطا ──
  final audio = AudioService();
  try {
    await audio.init();
  } catch (e) {
    debugPrint('[AudioService] خطا در مقداردهی (ادامه بدون صدا): $e');
    // اپ بدون AudioService هم کار می‌کند
  }

  return _AppServices(api: api, audio: audio);
}

// ─────────────────────────────────────────────────────────────────────────────
// ── App اصلی ──
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
          child: _ErrorBoundary(child: child ?? const SizedBox.shrink()),
        );
      },

      // ── صفحه اولیه ──
      home: const _AppEntryPoint(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── نقطه ورود (Splash + Auth Check) ──
// ─────────────────────────────────────────────────────────────────────────────
class _AppEntryPoint extends StatelessWidget {
  const _AppEntryPoint();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // ── در حال بارگذاری ──
    if (auth.isLoading) {
      return const _SplashScreen();
    }

    // ── رفتن به خانه (لاگین یا نه) ──
    return const HomeScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Splash Screen ──
// ─────────────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
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
                // ── آیکون ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.secondary.withOpacity(0.12),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 72,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 20),

                // ── نام اپ ──
                Text(
                  Constants.appName,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'در حال بارگذاری...',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 32),

                // ── loading ──
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor:
                        theme.colorScheme.secondary.withOpacity(0.15),
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
// ── Error Boundary ──
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBoundary extends StatelessWidget {
  final Widget child;
  const _ErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ErrorWidget.builder = (details) {
      debugPrint('[ErrorBoundary] ${details.exception}');
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'مشکلی پیش آمد',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لطفاً اپلیکیشن را مجدداً باز کنید.',
                  style: TextStyle(color: theme.hintColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    };
    return child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── تم‌های اپ ──
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: Colors.orange,
    scaffoldBackgroundColor: const Color(0xFF0D0D12),
    colorScheme: const ColorScheme.dark(
      primary: Colors.orange,
      secondary: Colors.amber,
      surface: Color(0xFF1A1A24),
      error: Colors.redAccent,
    ),
    cardColor: const Color(0xFF1A1A24),
    dividerColor: const Color(0xFF2A2A36),
    textTheme: GoogleFonts.vazirmatnTextTheme().apply(
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
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
    primaryColor: Colors.orange,
    scaffoldBackgroundColor: const Color(0xFFF5F5FA),
    colorScheme: const ColorScheme.light(
      primary: Colors.orange,
      secondary: Colors.amber,
      surface: Colors.white,
      error: Colors.redAccent,
    ),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    textTheme: GoogleFonts.vazirmatnTextTheme().apply(
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── ThemeProvider ──
// ─────────────────────────────────────────────────────────────────────────────
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    // ذخیره در SharedPreferences
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString(Constants.keyThemeMode, mode.name);
  }

  void toggleTheme() {
    setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
