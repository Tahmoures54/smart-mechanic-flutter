import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final ApiService apiService;

  AuthProvider(this.apiService);

  String? _token;
  int _credits = 0;
  bool _isGolden = false;
  bool _isLoading = true;
  String? _referralCode;
  int _earnings = 0;
  int _referredCount = 0;
  int _referralPercentage = 10;
  int _minWithdrawal = 50000;

  bool get isAuthenticated => _token != null;
  int get credits => _credits;
  bool get isGolden => _isGolden;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get referralCode => _referralCode;
  int get earnings => _earnings;
  int get referredCount => _referredCount;
  int get referralPercentage => _referralPercentage;
  int get minWithdrawal => _minWithdrawal;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _storage.read(key: 'jwt_token');
      if (_token != null) {
        await fetchProfile();
      }
    } catch (e) {
      debugPrint('خطا در خواندن توکن: $e');
      _token = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfile() async {
    if (_token == null) return;
    try {
      final response = await apiService.getProfile(_token!);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        _credits = data['credits'] ?? 0;
        _isGolden = data['isGolden'] == true || data['is_golden'] == true;
        _referralCode = data['referralCode']?.toString();
        _earnings = (data['earnings'] as num?)?.toInt() ?? 0;
        _referredCount = (data['referredCount'] as num?)?.toInt() ?? 0;
        _referralPercentage =
            (data['referralPercentage'] as num?)?.toInt() ?? 10;
        _minWithdrawal = (data['minWithdrawal'] as num?)?.toInt() ?? 50000;
        notifyListeners();
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        await logout();
      } else {
        debugPrint('خطا در دریافت پروفایل: $e');
      }
    }
  }

  Future<void> sendOtp(String phone) async {
    await apiService.sendOtp(phone);
  }

  Future<void> login(
    String phone,
    String code, {
    String? referralCode,
  }) async {
    final res = await apiService.verifyOtp(
      phone,
      code,
      referralCode: referralCode,
    );

    if (res['success'] == true) {
      _token = res['token'];

      final user = res['user'] ?? {};
      _credits = user['credits'] ?? 0;
      _isGolden = user['isGolden'] == true || user['is_golden'] == true;
      _referralCode = user['referralCode']?.toString();
      _earnings = (user['earnings'] as num?)?.toInt() ?? 0;

      if (_token != null) {
        await _storage.write(key: 'jwt_token', value: _token!);
      }

      // پروفایل کامل (تعداد معرفی‌ها و درصد)
      await fetchProfile();
      notifyListeners();
    } else {
      throw Exception(res['error'] ?? 'خطا در ورود');
    }
  }

  Future<void> logout() async {
    _token = null;
    _credits = 0;
    _isGolden = false;
    _referralCode = null;
    _earnings = 0;
    _referredCount = 0;
    await _storage.delete(key: 'jwt_token');

    try {
      if (Hive.isBoxOpen('diagnostics')) await Hive.box('diagnostics').clear();
      if (Hive.isBoxOpen('history')) await Hive.box('history').clear();
    } catch (e) {
      debugPrint('خطا در پاکسازی کش لوکال: $e');
    }

    notifyListeners();
  }
}
