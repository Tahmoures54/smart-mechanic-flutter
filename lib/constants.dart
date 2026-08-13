class Constants {
  // ==========================================
  // Base URLs
  // ==========================================

  // شبیه‌ساز اندروید:
  // static const String baseUrl = 'http://10.0.2.2:3000/api';

  // لوکال / وب:
  // static const String baseUrl = 'http://localhost:3000/api';

  // گوشی واقعی در همان شبکه:
  // static const String baseUrl = 'http://192.168.1.X:3000/api';

  // Production — با دامنه نهایی هماهنگ کنید
  static const String baseUrl = 'https://smart-mec.liara.run/api';

  // ==========================================
  // Endpoints
  // ==========================================

  static const String account = '$baseUrl/account';
  static const String credits = '$baseUrl/account/credits';
  static const String diagnose = '$baseUrl/diagnose';
  static const String health = '$baseUrl/health';
  static const String purchase = '$baseUrl/purchase';
  static const String verifyPurchase = '$baseUrl/purchase/verify';
}
