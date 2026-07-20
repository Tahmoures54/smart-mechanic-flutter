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
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('diagnostics');
  await Hive.openBox('history');

  final audioService = AudioService();
  await audioService.init();

  // ساخت یک نمونه واحد از httpClient برای استفاده مشترک
  final httpClient = http.Client();

  // ساخت نمونه واحد از ApiService
  final apiService = ApiService(httpClient: httpClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService)..checkAuthStatus(),
        ),
        
        Provider<AudioService>.value(value: audioService),
        
        // 👇 این بخش اصلاح شد: حالا از معماری کاملا امن و جدید استفاده می‌کند 👇
        Provider<AIDiagnosticService>(
          create: (_) => AIDiagnosticService(
            apiService: apiService, // جایگزین httpClient و apiKey شد
          ),
        ),
        // 👆 پایان اصلاح 👇
        
        Provider<MapService>(
          create: (_) => MapService(null),
        ),
        Provider<SoundAnalyzer>(
          create: (_) => SoundAnalyzer(),
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
        GlobalCupertinoLocalizations.delegate, 
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.amber,
        ),
        textTheme: GoogleFonts.vazirmatnTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.orange)),
            );
          }
          return authProvider.isAuthenticated 
              ? const HomeScreen() 
              : const LoginScreen(); 
        },
      ),
    );
  }
}
