class Constants {
  // ==========================================
  // Base URLs (آدرس‌های پایه)
  // ==========================================
  
  // برای تست روی شبیه‌ساز اندروید (Emulator)
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; 
  
  // برای تست روی آیفون یا مرورگر وب
  // static const String baseUrl = 'http://localhost:3000/api'; 
  
  // برای تست با گوشی واقعی متصل به یک وای‌فای (IP کامپیوتر خودتان را بگذارید)
  // static const String baseUrl = 'http://192.168.1.X:3000/api';

  // آدرس اصلی سرور (Production)
  static const String baseUrl = 'https://smart-mec.liara.run/api'; 

  // ==========================================
  // Endpoints (مسیرهای اختصاصی بک‌اند)
  // ==========================================
  
  static const String account = '$baseUrl/account';
  static const String credits = '$baseUrl/account/credits';
  static const String diagnose = '$baseUrl/diagnose';
  static const String health = '$baseUrl/health';
  static const String purchase = '$baseUrl/purchase';
  static const String verifyPurchase = '$baseUrl/purchase/verify';
}
