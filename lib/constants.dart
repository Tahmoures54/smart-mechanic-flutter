class Constants {
  // ==========================================
  // Base URLs (آدرس‌های پایه)
  // ==========================================
  
  // Development URLs (Uncomment for local testing)
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:3000/api'; // iOS simulator/Web

  // Production URL (دامنه فعلی روی لیارا یا دامنه اختصاصی شما)
  static const String baseUrl = 'https://smart-mec.liara.run/api'; 
  // اگر دامنه اختصاصی smart-mec.ir فعال شده است، خط بالا را کامنت کرده و خط زیر را باز کنید:
  // static const String baseUrl = 'https://smart-mec.ir/api';

  // ==========================================
  // Endpoints (مسیرهای اختصاصی بک‌اند)
  // ==========================================
  
  // مسیرهای مربوط به حساب کاربری و موجودی
  static const String account = '$baseUrl/account';
  static const String credits = '$baseUrl/account/credits';

  // مسیر عیب‌یابی و تشخیص خطا
  static const String diagnose = '$baseUrl/diagnose';

  // مسیر بررسی سلامت سرور/اپلیکیشن
  static const String health = '$baseUrl/health';

  // مسیرهای مربوط به درگاه پرداخت و تاییدیه خرید
  static const String purchase = '$baseUrl/purchase';
  static const String verifyPurchase = '$baseUrl/purchase/verify';
}
