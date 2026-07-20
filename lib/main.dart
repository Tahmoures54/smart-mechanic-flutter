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
import 'screens/login_screen.dart'; // فرض بر این است که این صفحه را دارید

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('diagnostics');
  await Hive.openBox('history');

  final audioService = AudioService();
  await audioService.init();

  // ساخت یک نمونه واحد از httpClient برای استفاده مشترک (بهینه‌سازی مصرف حافظه)
  final httpClient = http.Client();

  // ساخت نمونه واحد از ApiService
  final apiService = ApiService(httpClient: httpClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        
        // پاس دادن apiService به AuthProvider و بررسی وضعیت لاگین
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService)..checkAuthStatus(),
        ),
        
        Provider<AudioService>.value(value: audioService),
        
        // نکته مهم: در حالت ایده‌آل این سرویس باید حذف شود و کارهای AI از طریق 
        // بک‌اَند (apiService.diagnose) انجام شود تا امنیت حفظ گردد.
        Provider<AIDiagnosticService>(
          create: (_) => AIDiagnosticService(
            httpClient: httpClient, // استفاده از کلاینت مشترک
            apiKey: '', // به شدت توصیه می‌شود این پردازش به بک‌اَند Next.js منتقل شود
          ),
        ),
        
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
        GlobalCupertinoLocalizations.delegate, // اضافه شد: برای جلوگیری از کرش انتخاب متن
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
        // فونت وزیرمتن برای خوانایی عالی زبان فارسی
        textTheme: GoogleFonts.vazirmatnTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      // منطق مسیریابی بر اساس وضعیت ورود
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // اگر در حال بررسی وضعیت ورود است (مثلا خواندن توکن از حافظه)
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.orange)),
            );
          }
          // اگر لاگین بود به خانه برود، در غیر این صورت به صفحه ورود
          return authProvider.isAuthenticated 
              ? const HomeScreen() 
              : const LoginScreen(); 
        },
      ),
    );
  }
}
