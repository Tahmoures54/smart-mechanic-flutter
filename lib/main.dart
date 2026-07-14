import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http; // برای http.Client
import 'providers/auth_provider.dart';
// حذف import های diagnostic_provider و locale_provider (فایل ندارند)
import 'services/audio_service.dart';
import 'services/ai_diagnostic_service.dart';
import 'services/map_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // راه‌اندازی Hive
  await Hive.initFlutter();
  await Hive.openBox('diagnostics');
  await Hive.openBox('history');

  // راه‌اندازی سرویس صوتی
  final audioService = AudioService();
  await audioService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        // حذف LocaleProvider و DiagnosticProvider
        Provider<AudioService>.value(value: audioService),
        Provider<AIDiagnosticService>(
          // تأمین httpClient مورد نیاز
          create: (_) => AIDiagnosticService(httpClient: http.Client()),
        ),
        Provider<MapService>(
          // ارسال null برای کنترلر نقشه (تا زمان دریافت واقعی)
          create: (_) => MapService(null),
        ),
      ],
      child: const SmartMechanicApp(),
    ),
  );
}

class SmartMechanicApp extends StatelessWidget {
  const SmartMechanicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // تنظیمات مستقیم بومی‌سازی به‌جای LocaleProvider
    const Locale defaultLocale = Locale('fa', 'IR');
    const List<Locale> supportedLocales = [
      Locale('fa', 'IR'),
      Locale('en', 'US'),
    ];

    return MaterialApp(
      title: 'مکانیک هوشمند',
      locale: defaultLocale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.amber,
        ),
        textTheme: GoogleFonts.vazirmatnTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
