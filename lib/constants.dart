import 'package:flutter/foundation.dart';

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
// ── کانفیگ محیط ──
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

  // ── تعریف هر محیط (اصلاح شده با آدرس Vercel) ──
  // نکته: اگر بک‌اند شما مسیر /api را ندارد، آن را از انتهای آدرس‌ها حذف کنید
  static const development = EnvironmentConfig(
    environment: AppEnvironment.development,
    baseUrl: 'https://smart-mec-backend-zeta.vercel.app/api',
    enableLogging: true,
    enableCrashReporting: false,
  );

  static const staging = EnvironmentConfig(
    environment: AppEnvironment.staging,
    baseUrl: 'https://smart-mec-backend-zeta.vercel.app/api',
    enableLogging: true,
    enableCrashReporting: true,
  );

  static const production = EnvironmentConfig(
    environment: AppEnvironment.production,
    baseUrl: 'https://smart-mec-backend-zeta.vercel.app/api',
    enableLogging: false,
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
// ── ثابت‌های اصلی ──
// ─────────────────────────────────────────────────────────────────────────────
class Constants {
  Constants._();

  // ── محیط فعال ──
  static final EnvironmentConfig env = EnvironmentConfig.current;

  // ── نسخه API ──
  static const String _apiVersion = 'v1';

  // ── آدرس پایه با version ──
  static String get baseUrl => env.baseUrl;
  static String get apiUrl => '${env.baseUrl}/$_apiVersion';

  // ─────────────────────────────────────────
  // ── Endpoints: Account ──
  // ─────────────────────────────────────────
  // نکته: در کد قبلی endpoints از baseUrl استفاده میکردند. اگر بک‌اند شما v1 را نیاز دارد،
  // بهتر است از apiUrl استفاده کنند. فعلا برای جلوگیری از تغییر ناگهانی، روی baseUrl نگه داشته‌ام.
  static String get account => '$baseUrl/account';
  static String get sendOtp => '$baseUrl/account';          // POST {action: send}
  static String get verifyOtp => '$baseUrl/account';        // POST {action: verify}
  static String get credits => '$baseUrl/account/credits';  // GET
  static String get profile => '$baseUrl/account/credits';  // alias
  static String get withdraw => '$baseUrl/account/withdraw'; // POST

  // ─────────────────────────────────────────
  // ── Endpoints: Diagnose ──
  // ─────────────────────────────────────────
  static String get diagnose => '$baseUrl/diagnose';
  static String get diagnoseHistory => '$baseUrl/diagnose';  // GET ?history=true
  static String get diagnoseAudio => '$baseUrl/diagnose/audio'; // POST multipart
  static String deleteDiagnose(String id) => '$baseUrl/diagnose/$id'; // DELETE

  // ─────────────────────────────────────────
  // ── Endpoints: Purchase ──
  // ─────────────────────────────────────────
  static String get purchase => '$baseUrl/purchase';
  static String get verifyPurchase => '$baseUrl/purchase/verify';

  // ─────────────────────────────────────────
  // ── Endpoints: Static ──
  // ─────────────────────────────────────────
  static String get carsJson {
    // حذف /api از انتهای آدرس برای دسترسی به فایل‌های استاتیک در ریشه دامنه
    final publicBase = baseUrl.replaceAll('/api', '');
    return '$publicBase/cars.json';
  }

  static String get health => '$baseUrl/health';

  // ─────────────────────────────────────────
  // ── Timeouts ──
  // ─────────────────────────────────────────
  static const Duration defaultTimeout = Duration(seconds: 20);
  static const Duration diagnoseTimeout = Duration(seconds: 60);
  static const Duration uploadTimeout = Duration(seconds: 90);
  static const Duration longPollTimeout = Duration(minutes: 2);

  // ─────────────────────────────────────────
  // ── Cache ──
  // ─────────────────────────────────────────
  static const Duration carsCacheDuration = Duration(hours: 6);
  static const Duration profileCacheDuration = Duration(seconds: 30);
  static const Duration placesCacheDuration = Duration(minutes: 10);

  // ─────────────────────────────────────────
  // ── App Info ──
  // ─────────────────────────────────────────
  static const String appName = 'مکانیک هوشمند';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;
  static const String packageName = 'ir.smartmec.app';
  static const String supportEmail = 'support@smart-mec.ir';

  // ─────────────────────────────────────────
  // ── Storage Keys ──
  // ─────────────────────────────────────────
  static const String keyJwtToken = 'jwt_token';
  static const String keySelectedLocale = 'selected_locale';
  static const String keyLastCarId = 'last_car_id';
  static const String keyLastCustomCar = 'last_custom_car_name';
  static const String keyLastYear = 'last_year';
  static const String keyThemeMode = 'theme_mode';

  // ─────────────────────────────────────────
  // ── Hive Box Names ──
  // ─────────────────────────────────────────
  static const String boxDiagnostics = 'diagnostics';
  static const String boxHistory = 'history';
  static const String boxUserProfile = 'user_profile';

  // ─────────────────────────────────────────
  // ── Limits ──
  // ─────────────────────────────────────────
  static const int maxDescriptionLength = 300;
  static const int minDescriptionLength = 5;
  static const int maxRecordingSeconds = 30;
  static const int minRecordingSeconds = 3;
  static const int maxChatMessages = 50;
  static const int otpLength = 6;
  static const int phoneLength = 11;

  // ─────────────────────────────────────────
  // ── Feature Flags ──
  // ─────────────────────────────────────────
  static const bool featureAudioDiagnosis = true;
  static const bool featureGarageMap = true;
  static const bool featureReferral = true;
  static const bool featureWithdraw = true;
  static const bool featureObdDiagnosis = false;  // هنوز آماده نیست

  // ─────────────────────────────────────────
  // ── Rate Limiting ──
  // ─────────────────────────────────────────
  static const Duration minRequestInterval = Duration(milliseconds: 500);
  static const Duration otpResendCooldown = Duration(seconds: 60);

  // ─────────────────────────────────────────
  // ── دیباگ ──
  // ─────────────────────────────────────────
  static void printInfo() {
    if (!env.enableLogging) return;
    debugPrint('════════════════════════════════');
    debugPrint('🚗 $appName v$appVersion+$appBuildNumber');
    debugPrint('🌐 Env: ${env.environment.label}');
    debugPrint('🔗 BaseUrl: $baseUrl');
    debugPrint('📝 Logging: ${env.enableLogging}');
    debugPrint('════════════════════════════════');
  }
}
