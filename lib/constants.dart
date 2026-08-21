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

  static EnvironmentConfig get current {
    if (kDebugMode) return development;
    if (kProfileMode) return staging;
    return production;
  }
}

class Constants {
  Constants._();

  static final EnvironmentConfig env = EnvironmentConfig.current;

  static const String _apiVersion = 'v1';

  static String get baseUrl => env.baseUrl;
  static String get apiUrl => '$baseUrl/$_apiVersion';

  // Account
  static String get account => '$apiUrl/account';
  static String get sendOtp => '$apiUrl/account';
  static String get verifyOtp => '$apiUrl/account';
  static String get credits => '$apiUrl/account/credits';
  static String get profile => '$apiUrl/account/credits';
  static String get withdraw => '$apiUrl/account/withdraw';

  // Diagnose
  static String get diagnose => '$apiUrl/diagnose';
  static String get diagnoseHistory => '$apiUrl/diagnose';
  static String get diagnoseAudio => '$apiUrl/diagnose/audio';
  static String deleteDiagnose(String id) => '$apiUrl/diagnose/$id';

  // Feedback & Analytics (هم‌تراز با بک‌اند)
  static String get feedback => '$apiUrl/feedback';
  static String get events => '$apiUrl/events';
  static String get products => '$apiUrl/products';
  static String get carsApi => '$apiUrl/cars';

  // Purchase
  static String get purchase => '$apiUrl/purchase';
  static String get verifyPurchase => '$apiUrl/purchase/verify';

  // Static fallback
  static String get carsJson {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '/cars.json').toString();
  }

  static String get health => '$apiUrl/health';

  static const Duration defaultTimeout = Duration(seconds: 20);
  static const Duration diagnoseTimeout = Duration(seconds: 60);
  static const Duration uploadTimeout = Duration(seconds: 90);
  static const Duration longPollTimeout = Duration(minutes: 2);

  static const Duration carsCacheDuration = Duration(hours: 6);
  static const Duration profileCacheDuration = Duration(seconds: 30);
  static const Duration placesCacheDuration = Duration(minutes: 10);

  static const String appName = 'مکانیک هوشمند';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;
  static const String packageName = 'ir.smartmec.app';
  static const String supportEmail = 'support@smart-mec.ir';

  static const String keyJwtToken = 'jwt_token';
  static const String keySelectedLocale = 'selected_locale';
  static const String keyLastCarId = 'last_car_id';
  static const String keyLastCustomCar = 'last_custom_car_name';
  static const String keyLastYear = 'last_year';
  static const String keyThemeMode = 'theme_mode';

  static const String boxDiagnostics = 'diagnostics';
  static const String boxHistory = 'history';
  static const String boxUserProfile = 'user_profile';

  // هم‌تراز با validation بک‌اند
  static const int maxDescriptionLength = 2000;
  static const int minDescriptionLength = 10;
  static const int maxRecordingSeconds = 30;
  static const int minRecordingSeconds = 3;
  static const int maxChatMessages = 50;
  static const int otpLength = 6;
  static const int phoneLength = 11;

  static const bool featureAudioDiagnosis = true;
  static const bool featureGarageMap = true;
  static const bool featureReferral = true;
  static const bool featureWithdraw = true;
  static const bool featureObdDiagnosis = false;
  static const bool featureAnalytics = true;
  static const bool featureFeedback = true;

  static const Duration minRequestInterval = Duration(milliseconds: 500);
  static const Duration otpResendCooldown = Duration(seconds: 60);

  static void printInfo() {
    if (!env.enableLogging) return;
    debugPrint('════════════════════════════════');
    debugPrint('🚗 $appName v$appVersion+$appBuildNumber');
    debugPrint('🌐 Env: ${env.environment.label}');
    debugPrint('🔗 BaseUrl: $baseUrl');
    debugPrint('🔗 ApiUrl: $apiUrl');
    debugPrint('════════════════════════════════');
  }
}
