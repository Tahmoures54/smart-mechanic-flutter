import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _storage;
  final ApiService apiService;

  AuthProvider(
    this.apiService, {
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  String? _token;
  bool _isLoading = true;
  bool _isProfileLoaded = false;

  String? _userId;
  String? _userName;
  String? _phone;

  int _credits = 0;
  bool _isGolden = false;
  DateTime? _goldenExpiry;

  int _remainingFree = 2;
  int _monthlyFreeLimit = 2;
  int _usedFree = 0;

  String? _referralCode;
  int _earnings = 0;
  int _referredCount = 0;
  int _referralPercentage = 10;
  int _minWithdrawal = 50000;

  DateTime? _profileLastFetched;
  static const _profileCacheDuration = Duration(seconds: 30);
  bool _isFetchingProfile = false;

  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  bool get isProfileLoaded => _isProfileLoaded;

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get phone => _phone;

  /// اعتبار خریداری‌شده (واقعی)
  int get paidCredits => _credits;

  /// سازگار با UI قدیمی: اگر اعتبار پولی صفر باشد ولی رایگان مانده، همان را نشان بده
  int get credits =>
      _credits > 0 ? _credits : (_remainingFree > 0 ? _remainingFree : 0);

  bool get isGolden => _isGolden;
  DateTime? get goldenExpiry => _goldenExpiry;

  int get remainingFree => _remainingFree;
  int get monthlyFreeLimit => _monthlyFreeLimit;
  int get usedFree => _usedFree;

  String? get referralCode => _referralCode;
  int get earnings => _earnings;
  int get referredCount => _referredCount;
  int get referralPercentage => _referralPercentage;
  int get minWithdrawal => _minWithdrawal;

  bool get isGoldenActive {
    if (!_isGolden) return false;
    if (_goldenExpiry == null) return true;
    return _goldenExpiry!.isAfter(DateTime.now());
  }

  int? get goldenDaysLeft {
    if (!isGoldenActive || _goldenExpiry == null) return null;
    return _goldenExpiry!.difference(DateTime.now()).inDays;
  }

  String get displayName {
    if (_userName != null && _userName!.isNotEmpty) return _userName!;
    if (_phone != null && _phone!.isNotEmpty) return _phone!;
    return 'کاربر';
  }

  bool get canDiagnose =>
      isAuthenticated && (isGoldenActive || _credits > 0 || _remainingFree > 0);

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    try {
      _token = await _storage.read(key: 'jwt_token');
      if (_token != null) {
        if (!Hive.isBoxOpen('user_profile')) {
          await Hive.openBox('user_profile');
        }
        await _loadCachedProfile();
        await fetchProfile(force: true);
      }
    } catch (e) {
      debugPrint('خطا در بررسی وضعیت: $e');
      _token = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedProfile() async {
    try {
      if (!Hive.isBoxOpen('user_profile')) return;
      final box = Hive.box('user_profile');
      _userId = box.get('userId') as String?;
      _userName = box.get('userName') as String?;
      _phone = box.get('phone') as String?;
      _credits = box.get('credits', defaultValue: 0) as int? ?? 0;
      _isGolden = box.get('isGolden', defaultValue: false) as bool? ?? false;
      _remainingFree = box.get('remainingFree', defaultValue: 2) as int? ?? 2;
      _monthlyFreeLimit =
          box.get('monthlyFreeLimit', defaultValue: 2) as int? ?? 2;
      _usedFree = box.get('usedFree', defaultValue: 0) as int? ?? 0;
      _referralCode = box.get('referralCode') as String?;
      _earnings = box.get('earnings', defaultValue: 0) as int? ?? 0;
      _referredCount = box.get('referredCount', defaultValue: 0) as int? ?? 0;
      _referralPercentage =
          box.get('referralPercentage', defaultValue: 10) as int? ?? 10;
      _minWithdrawal =
          box.get('minWithdrawal', defaultValue: 50000) as int? ?? 50000;
      final expiryStr = box.get('goldenExpiry') as String?;
      if (expiryStr != null) {
        _goldenExpiry = DateTime.tryParse(expiryStr);
      }
      if (_credits > 0 || _isGolden || _referralCode != null || _remainingFree > 0) {
        _isProfileLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری cache: $e');
    }
  }

  Future<void> _saveCachedProfile() async {
    try {
      late final Box box;
      if (Hive.isBoxOpen('user_profile')) {
        box = Hive.box('user_profile');
      } else {
        box = await Hive.openBox('user_profile');
      }
      await box.putAll({
        if (_userId != null) 'userId': _userId,
        if (_userName != null) 'userName': _userName,
        if (_phone != null) 'phone': _phone,
        'credits': _credits,
        'isGolden': _isGolden,
        'remainingFree': _remainingFree,
        'monthlyFreeLimit': _monthlyFreeLimit,
        'usedFree': _usedFree,
        if (_referralCode != null) 'referralCode': _referralCode,
        'earnings': _earnings,
        'referredCount': _referredCount,
        'referralPercentage': _referralPercentage,
        'minWithdrawal': _minWithdrawal,
        if (_goldenExpiry != null) 'goldenExpiry': _goldenExpiry!.toIso8601String(),
      });
    } catch (e) {
      debugPrint('خطا در ذخیره cache: $e');
    }
  }

  Future<void> fetchProfile({bool force = false}) async {
    if (_token == null) return;
    if (!force && _isFetchingProfile) return;
    if (!force && _profileLastFetched != null) {
      final elapsed = DateTime.now().difference(_profileLastFetched!);
      if (elapsed < _profileCacheDuration) return;
    }
    _isFetchingProfile = true;
    try {
      final response = await apiService.getProfile(_token!);
      if (response['success'] == true && response['data'] != null) {
        _updateProfileFromData(response['data'] as Map<String, dynamic>);
        _profileLastFetched = DateTime.now();
        _isProfileLoaded = true;
        await _saveCachedProfile();
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout();
      } else {
        debugPrint('خطای API در دریافت پروفایل: ${e.message}');
      }
    } catch (e) {
      debugPrint('خطا در دریافت پروفایل: $e');
    } finally {
      _isFetchingProfile = false;
    }
  }

  void _updateProfileFromData(Map<String, dynamic> data) {
    _userId = data['id']?.toString() ?? data['userId']?.toString() ?? _userId;
    _userName = data['name']?.toString() ??
        data['userName']?.toString() ??
        data['username']?.toString();
    _phone = data['phone']?.toString() ?? _phone;
    _credits = (data['credits'] as num?)?.toInt() ?? _credits;
    _isGolden = data['isGolden'] == true || data['is_golden'] == true;
    _referralCode = data['referralCode']?.toString() ?? _referralCode;
    _earnings = (data['earnings'] as num?)?.toInt() ?? _earnings;
    _referredCount = (data['referredCount'] as num?)?.toInt() ?? _referredCount;
    _referralPercentage =
        (data['referralPercentage'] as num?)?.toInt() ?? _referralPercentage;
    _minWithdrawal = (data['minWithdrawal'] as num?)?.toInt() ?? _minWithdrawal;
    _remainingFree = (data['remainingFree'] as num?)?.toInt() ?? _remainingFree;
    _monthlyFreeLimit =
        (data['monthlyFreeLimit'] as num?)?.toInt() ?? _monthlyFreeLimit;
    _usedFree = (data['usedFree'] as num?)?.toInt() ?? _usedFree;
    final expiryStr =
        data['goldenExpiry']?.toString() ?? data['golden_expiry']?.toString();
    if (expiryStr != null) {
      _goldenExpiry = DateTime.tryParse(expiryStr);
    }
  }

  Future<void> sendOtp(String phone) async {
    await apiService.sendOtp(phone);
  }

  Future<void> login(String phone, String code, {String? referralCode}) async {
    final res =
        await apiService.verifyOtp(phone, code, referralCode: referralCode);
    if (res['success'] == true) {
      _token = res['token'] as String?;
      if (_token == null) {
        throw Exception('توکن دریافت نشد. لطفاً دوباره تلاش کنید.');
      }
      await _storage.write(key: 'jwt_token', value: _token!);
      final user = res['user'];
      if (user is Map<String, dynamic>) {
        _phone = phone;
        _updateProfileFromData(user);
      }
      await fetchProfile(force: true);
      notifyListeners();
    } else {
      throw Exception(res['error'] ?? res['message'] ?? 'خطا در ورود');
    }
  }

  void updateCredits(int newCredits) {
    _credits = newCredits;
    notifyListeners();
    _saveCachedProfile();
  }

  void addCredits(int amount) {
    _credits += amount;
    notifyListeners();
    _saveCachedProfile();
  }

  void consumeCredit() {
    if (_credits > 0) {
      _credits--;
    } else if (_remainingFree > 0) {
      _remainingFree--;
      _usedFree++;
    }
    notifyListeners();
    _saveCachedProfile();
  }

  void applyDiagnoseQuota({
    int? remainingCredits,
    int? remainingFreeQuestions,
  }) {
    if (remainingCredits != null) _credits = remainingCredits;
    if (remainingFreeQuestions != null) _remainingFree = remainingFreeQuestions;
    notifyListeners();
    _saveCachedProfile();
  }

  void activateGolden({DateTime? expiry}) {
    _isGolden = true;
    _goldenExpiry = expiry;
    notifyListeners();
    _saveCachedProfile();
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _userName = null;
    _phone = null;
    _credits = 0;
    _isGolden = false;
    _goldenExpiry = null;
    _remainingFree = 2;
    _monthlyFreeLimit = 2;
    _usedFree = 0;
    _referralCode = null;
    _earnings = 0;
    _referredCount = 0;
    _referralPercentage = 10;
    _minWithdrawal = 50000;
    _isProfileLoaded = false;
    _profileLastFetched = null;
    _isFetchingProfile = false;
    await _storage.delete(key: 'jwt_token');
    await _clearLocalCache();
    notifyListeners();
  }

  Future<void> _clearLocalCache() async {
    final boxNames = ['diagnostics', 'history', 'user_profile'];
    for (final name in boxNames) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
          await Hive.box(name).close();
        } else {
          final box = await Hive.openBox(name);
          await box.clear();
          await box.close();
        }
      } catch (e) {
        debugPrint('خطا در پاکسازی box "$name": $e');
      }
    }
  }

  Future<bool> validateToken() async {
    if (_token == null) return false;
    try {
      await fetchProfile(force: true);
      return isAuthenticated;
    } catch (_) {
      return false;
    }
  }
}
