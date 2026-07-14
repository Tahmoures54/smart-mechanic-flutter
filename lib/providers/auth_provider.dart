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

  bool get isAuthenticated => _token != null;
  int get credits => _credits;
  bool get isGolden => _isGolden;
  String? get token => _token;

  Future<void> checkAuthStatus() async {
    _token = await _storage.read(key: 'jwt_token');
    if (_token != null) {
      await fetchProfile();
    }
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    if (_token == null) return;
    try {
      final profile = await apiService.getProfile(_token!);
      _credits = profile['credits'] ?? 0;
      // ایمن‌سازی نام کلید بین کمل‌کیس و اسنیک‌کیس
      _isGolden = profile['isGolden'] == true || profile['is_golden'] == true;
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('401')) {
        await logout();
      }
    }
  }

  Future<void> login(String phone, String code) async {
    final res = await apiService.verifyOtp(phone, code);
    _token = res['token'];
    _credits = res['credits'] ?? 0;
    _isGolden = res['isGolden'] == true || res['is_golden'] == true;
    await _storage.write(key: 'jwt_token', value: _token);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _credits = 0;
    _isGolden = false;
    await _storage.delete(key: 'jwt_token');
    
    // پاک کردن دیتای آفلاین کاربر قبلی (بسیار مهم برای امنیت)
    try {
      await Hive.box('diagnostics').clear();
      await Hive.box('history').clear();
    } catch (_) {}
    
    notifyListeners();
  }
}
