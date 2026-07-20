import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'providers/auth_provider.dart';
import 'services/audio_service.dart';
import 'services/ai_diagnostic_service.dart';
import 'services/map_service.dart';
import 'services/api_service.dart';
import 'services/sound_analyzer.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('diagnostics');
  await Hive.openBox('history');

  final audioService = AudioService();
  await audioService.init();
  final httpClient = http.Client();
  final apiService = ApiService(httpClient: httpClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)..checkAuthStatus()),
        Provider<AudioService>.value(value: audioService),
        Provider<AIDiagnosticService>(create: (_) => AIDiagnosticService(apiService: apiService)),
        Provider<MapService>(create: (_) => MapService(null)),
        Provider<SoundAnalyzer>(create: (_) => SoundAnalyzer()),
      ],
      child: const SmartMechanicApp(),
    ),
  );
}

class SmartMechanicApp extends StatelessWidget {
  const SmartMechanicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مکانیک هوشمند',
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, 
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF0D0D12), // رنگ پس‌زمینه شیک‌تر
        colorScheme: const ColorScheme.dark(primary: Colors.orange, secondary: Colors.amber),
        textTheme: GoogleFonts.vazirmatnTextTheme().apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      // ورود مستقیم به خانه بدون گیر دادن به لاگین
      home: const HomeScreen(),
    );
  }
}
