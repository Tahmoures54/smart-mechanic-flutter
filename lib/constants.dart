import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── محیط اجرا ──
// ─────────────────────────────────────────────────────────────────────────────
enum AppEnvironment {
  development,
  staging,
  production;

  bool get isDev => this == development;
  bool get isStaging => this == staging;
  bool get isProd => this == production;

  String get label => switch (this) {
        AppEnvironment.development => 'Development',
        AppEnvironment.staging => 'Staging',
        AppEnvironment.production => 'Production',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ کانفیگ محیط ──
// ─────────────────────────────────────────────────────────────────────────────
class EnvironmentConfig {
  final AppEnvironment environment;
  final String baseUrl;
  final bool enableLogging;
  final bool enableCrashReporting;

  const EnvironmentConfig({
    required this.environment,
    required this.baseUrl,
    this.enableLogging = false,
    this.enableCrashReporting = true,
  });

  /// مقدار پیش‌فرض اگر .env لود نشده باشد
  static const String _defaultBaseUrl =
      'https://smart-mec-backend-zeta.vercel.app/api';

  static String get _baseUrlFromEnv {
    try {
      final v = dotenv.env['API_BASE_URL']?.trim();
      if (v != null && v.isNotEmpty) return v.replaceAll(RegExp(r'/+$'), '');
    } catch (_) {}
    return _defaultBaseUrl;
  }

  static bool get _loggingFromEnv {
    try {
      final v = dotenv.env['ENABLE_API_LOGGING']?.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    } catch (_) {}
    return kDebugMode;
  }

  // ── تعریف هر محیط (baseUrl از .env خوانده می‌شود) ──
  static EnvironmentConfig get development => EnvironmentConfig(
        environment: AppEnvironment.development,
        baseUrl: _baseUrlFromEnv,
        enableLogging: true,
        enableCrashReporting: false,
      );

  static EnvironmentConfig get staging => EnvironmentConfig(
        environment: AppEnvironment.staging,
        baseUrl: _baseUrlFromEnv,
        enableLogging: true,
        enableCrashReporting: true,
      );

  static EnvironmentConfig get production => EnvironmentConfig(
        environment: AppEnvironment.production,
        baseUrl: _baseUrlFromEnv,
        enableLogging: _loggingFromEnv,
        enableCrashReporting: true,
      );

  // ── انتخاب خودکار بر اساس build mode ──
  static EnvironmentConfig get current {
    if (kDebugMode) return development;
    if (kProfileMode) return staging;
    return production;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ ثابت‌های اصلی ──
// ─────────────────────────────────────────────────────────────────────────────
class Constants {
  Constants._();

  // ── محیط فعال ──
  static EnvironmentConfig get env => EnvironmentConfig.current;

  // ── نسخه API ──
  static String get _apiVersion {
    try {
      final v = dotenv.env['API_VERSION']?.trim();
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return 'v1';
  }

  // ── آدرس پایه با version ──
  static String get baseUrl => env.baseUrl;
  // ✅ ترکیب ایمن آدرس پایه و نسخه API
  static String get apiUrl => '$baseUrl/$_apiVersion';

  // ─────────────────────────────────────────
  // ─ـ Endpoints: Account ──
  // ─────────────────────────────────────────
  static String get account => '$apiUrl/account';
  static String get sendOtp => '$apiUrl/account'; // POST {action: send}
  static String get verifyOtp => '$apiUrl/account'; // POST {action: verify}
  static String get credits => '$apiUrl/account/credits'; // GET
  static String get profile => '$apiUrl/account/credits'; // alias
  static String get withdraw => '$apiUrl/account/withdraw'; // POST

  // ─────────────────────────────────────────
  // ─ـ Endpoints: Diagnose ──
  // ─────────────────────────────────────────
  static String get diagnose => '$apiUrl/diagnose';
  static String get diagnoseHistory => '$apiUrl/diagnose'; // GET ?history=true
  static String get diagnoseAudio => '$apiUrl/diagnose/audio'; // POST multipart
  static String deleteDiagnose(String id) => '$apiUrl/diagnose/$id'; // DELETE

  // ─────────────────────────────────────────
  // ─ـ Endpoints: Purchase ──
  // ─────────────────────────────────────────
  static String get purchase => '$apiUrl/purchase';
  static String get verifyPurchase => '$apiUrl/purchase/verify';

  // ─────────────────────────────────────────
  // ─ـ Endpoints: Static ──
  // ─────────────────────────────────────────
  static String get carsJson {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '/cars.json').toString();
  }

  static String get health => '$apiUrl/health';

  // ─────────────────────────────────────────
  // ─ـ Timeouts ──
  // ─────────────────────────────────────────
  static const Duration defaultTimeout = Duration(seconds: 20);
  static const Duration diagnoseTimeout = Duration(seconds: 60);
  static const Duration uploadTimeout = Duration(seconds: 90);
  static const Duration longPollTimeout = Duration(minutes: 2);

  // ─────────────────────────────────────────
  // ─ـ Cache ──
  // ─────────────────────────────────────────
  static const Duration carsCacheDuration = Duration(hours: 6);
  static const Duration profileCacheDuration = Duration(seconds: 30);
  static const Duration placesCacheDuration = Duration(minutes: 10);

  // ─────────────────────────────────────────
  // ─ـ App Info ──
  // ─────────────────────────────────────────
  static const String appName = 'مکانیک هوشمند';
  static const String appVersion = '1.2.0';
  static const int appBuildNumber = 3;
  static const String packageName = 'ir.smartmec.app';
  static const String supportEmail = 'support@smart-mec.ir';

  // ─────────────────────────────────────────
  // ─ـ Storage Keys ──
  // ─────────────────────────────────────────
  static const String keyJwtToken = 'jwt_token';
  static const String keySelectedLocale = 'selected_locale';
  static const String keyLastCarId = 'last_car_id';
  static const String keyLastCustomCar = 'last_custom_car_name';
  static const String keyLastYear = 'last_year';
  static const String keyThemeMode = 'theme_mode';

  // ─────────────────────────────────────────
  // ─ـ Hive Box Names ──
  // ─────────────────────────────────────────
  static const String boxDiagnostics = 'diagnostics';
  static const String boxHistory = 'history';
  static const String boxUserProfile = 'user_profile';

  // ─────────────────────────────────────────
  // ─ـ Limits ──
  // ─────────────────────────────────────────
  static const int maxDescriptionLength = 300;
  static const int minDescriptionLength = 5;
  static const int maxRecordingSeconds = 30;
  static const int minRecordingSeconds = 3;
  static const int maxChatMessages = 50;
  static const int otpLength = 6;
  static const int phoneLength = 11;

  // ─────────────────────────────────────────
  // ─ـ Feature Flags ──
  // ─────────────────────────────────────────
  static const bool featureAudioDiagnosis = true;
  static const bool featureGarageMap = true;
  static const bool featureReferral = true;
  static const bool featureWithdraw = true;
  static const bool featureObdDiagnosis = false; // هنوز آماده نیست

  // ─────────────────────────────────────────
  // ─ـ Rate Limiting ──
  // ─────────────────────────────────────────
  static const Duration minRequestInterval = Duration(milliseconds: 500);
  static const Duration otpResendCooldown = Duration(seconds: 60);

  // ─────────────────────────────────────────
  // ─ـ دیباگ ──
  // ─────────────────────────────────────────
  static void printInfo() {
    if (!env.enableLogging) return;
    debugPrint('════════════════════════════════');
    debugPrint('🚗 $appName v$appVersion+$appBuildNumber');
    debugPrint('🌐 Env: ${env.environment.label}');
    debugPrint('🔗 BaseUrl: $baseUrl');
    debugPrint('🔗 ApiUrl: $apiUrl');
    debugPrint('📝 Logging: ${env.enableLogging}');
    debugPrint('════════════════════════════════');
  }
}
