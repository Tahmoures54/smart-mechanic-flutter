import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'screens/notification_settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _setupErrorWidget();
  Constants.printInfo();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await _initHive();

  final services = await _initServices();
  final localeProvider = await LocaleProvider.create();
  final themeProvider = await ThemeProvider.create();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => services.api, dispose: (_, api) => api.dispose()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(services.api)..checkAuthStatus(),
        ),
        Provider<AudioService>(
          create: (_) => services.audio,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<AIDiagnosticService>(
          create: (_) => AIDiagnosticService(apiService: services.api),
        ),
        Provider<MapService>(
          create: (_) => MapService(),
          dispose: (_, s) => s.dispose(),
        ),
        Provider<SoundAnalyzer>(create: (_) => SoundAnalyzer()),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: const SmartMechanicApp(),
    ),
  );
}

void _setupErrorWidget() {
  ErrorWidget.builder = (details) {
    debugPrint('[ErrorBoundary] ${details.exception}');
    return Material(
      color: const Color(0xFF0D0D12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              const Text('مشکلی پیش آمد',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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

class _AppServices {
  final ApiService api;
  final AudioService audio;
  const _AppServices({required this.api, required this.audio});
}

Future<_AppServices> _initServices() async {
  final httpClient = http.Client();
  final api = ApiService(httpClient: httpClient);
  // IMPORTANT: do not initialize native audio plugins during application startup.
  // Some Android devices/ROMs can crash the process when the recorder is opened
  // before the first Flutter frame. AudioService now initializes lazily when the
  // user actually opens the recording screen.
  final audio = AudioService();
  return _AppServices(api: api, audio: audio);
}

class SmartMechanicApp extends StatelessWidget {
  const SmartMechanicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      supportedLocales: LocaleConfig.flutterLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return Directionality(
          textDirection: localeProvider.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AppEntryPoint(),
      routes: {
        '/notification-settings': (_) => const NotificationSettingsScreen(),
      },
    );
  }
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) return const _SplashScreen();
    return const HomeScreen();
  }
}

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
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
                Text(
                  Constants.appName,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
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
