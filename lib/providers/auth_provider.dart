import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final ApiService apiService; // تزریق وابستگی به جای ساخت نمونه جدید

  AuthProvider(this.apiService);

  String? _token;
  int _credits = 0;
  bool _isGolden = false;
  
  // اضافه شد: برای مدیریت وضعیت لودینگ اولیه اپلیکیشن
  bool _isLoading = true; 

  bool get isAuthenticated => _token != null;
  int get credits => _credits;
  bool get isGolden => _isGolden;
  String? get token => _token;
  bool get isLoading => _isLoading; // متصل به main.dart

  /// بررسی وضعیت ورود در هنگام باز شدن اپلیکیشن
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners(); // نمایش اسپینر در UI

    try {
      _token = await _storage.read(key: 'jwt_token');
      if (_token != null) {
        await fetchProfile();
      }
    } catch (e) {
      debugPrint('خطا در خواندن توکن: $e');
    } finally {
      _isLoading = false;
      notifyListeners(); // مخفی کردن اسپینر و هدایت به صفحه مناسب
    }
  }

  /// دریافت اطلاعات پروفایل (موجودی و وضعیت کاربری)
  Future<void> fetchProfile() async {
    if (_token == null) return;
    try {
      final profile = await apiService.getProfile(_token!);
      _credits = profile['credits'] ?? 0;
      // ایمن‌سازی نام کلید بین کمل‌کیس و اسنیک‌کیس
      _isGolden = profile['isGolden'] == true || profile['is_golden'] == true;
      notifyListeners();
    } catch (e) {
      // اگر توکن منقضی شده بود (خطای 401)، کاربر خودکار خارج می‌شود
      if (e.toString().contains('401')) {
        await logout();
      }
    }
  }

  /// متد ارسال کد تایید (جهت یکپارچگی ارتباط با UI)
  Future<void> sendOtp(String phone) async {
    await apiService.sendOtp(phone);
  }

  /// ورود، دریافت توکن و ذخیره امن آن
  Future<void> login(String phone, String code) async {
    final res = await apiService.verifyOtp(phone, code);
    
    _token = res['token'];
    _credits = res['credits'] ?? 0;
    _isGolden = res['isGolden'] == true || res['is_golden'] == true;
    
    if (_token != null) {
      await _storage.write(key: 'jwt_token', value: _token!);
    }
    notifyListeners();
  }

  /// خروج از حساب و پاکسازی کامل ردپای کاربر
  Future<void> logout() async {
    _token = null;
    _credits = 0;
    _isGolden = false;
    await _storage.delete(key: 'jwt_token');
    
    // پاک کردن دیتای آفلاین کاربر قبلی (بسیار مهم برای امنیت)
    try {
      // اضافه شد: بررسی باز بودن باکس قبل از پاک کردن برای جلوگیری از کرش
      if (Hive.isBoxOpen('diagnostics')) {
        await Hive.box('diagnostics').clear();
      }
      if (Hive.isBoxOpen('history')) {
        await Hive.box('history').clear();
      }
    } catch (e) {
      debugPrint('خطا در پاکسازی کش لوکال: $e');
    }
    
    notifyListeners();
  }
}
