import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  // ── وابستگی‌ها ──
  final FlutterSecureStorage _storage;
  final ApiService apiService;

  AuthProvider(
    this.apiService, {
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  // ── وضعیت احراز هویت ──
  String? _token;
  bool _isLoading = true;
  bool _isProfileLoaded = false;

  // ── داده‌های کاربر ──
  String? _userId;
  String? _userName;
  String? _phone;

  // ── اعتبار و اشتراک ──
  int _credits = 0;
  bool _isGolden = false;
  DateTime? _goldenExpiry;

  // ── سیستم معرفی ──
  String? _referralCode;
  int _earnings = 0;
  int _referredCount = 0;
  int _referralPercentage = 10;
  int _minWithdrawal = 50000;

  // ── throttle برای fetchProfile ──
  DateTime? _profileLastFetched;
  static const _profileCacheDuration = Duration(seconds: 30);
  bool _isFetchingProfile = false;

  // ─────────────────────────────────────────
  // ── Getters ──
  // ─────────────────────────────────────────
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  bool get isProfileLoaded => _isProfileLoaded;

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get phone => _phone;

  int get credits => _credits;
  bool get isGolden => _isGolden;
  DateTime? get goldenExpiry => _goldenExpiry;

  String? get referralCode => _referralCode;
  int get earnings => _earnings;
  int get referredCount => _referredCount;
  int get referralPercentage => _referralPercentage;
  int get minWithdrawal => _minWithdrawal;

  /// آیا اشتراک طلایی هنوز معتبر است
  bool get isGoldenActive {
    if (!_isGolden) return false;
    if (_goldenExpiry == null) return true;
    return _goldenExpiry!.isAfter(DateTime.now());
  }

  /// روزهای باقی‌مانده اشتراک طلایی
  int? get goldenDaysLeft {
    if (!isGoldenActive || _goldenExpiry == null) return null;
    return _goldenExpiry!.difference(DateTime.now()).inDays;
  }

  /// نمایش نام کاربر یا شماره
  String get displayName {
    if (_userName != null && _userName!.isNotEmpty) return _userName!;
    if (_phone != null && _phone!.isNotEmpty) return _phone!;
    return 'کاربر';
  }

  /// آیا می‌توان عیب‌یابی انجام داد
  bool get canDiagnose => isAuthenticated && (isGoldenActive || _credits > 0);

  // ─────────────────────────────────────────
  // ── بررسی وضعیت اولیه ──
  // ─────────────────────────────────────────
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _storage.read(key: 'jwt_token');
      if (_token != null) {
        // بارگذاری cache محلی اول (سریع‌تر)
        await _loadCachedProfile();
        // بعد از سرور آپدیت کن
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

  // ─────────────────────────────────────────
  // ── بارگذاری cache محلی ──
  // ─────────────────────────────────────────
  Future<void> _loadCachedProfile() async {
    try {
      if (!Hive.isBoxOpen('user_profile')) return;
      final box = Hive.box('user_profile');

      _userId = box.get('userId') as String?;
      _userName = box.get('userName') as String?;
      _phone = box.get('phone') as String?;
      _credits = box.get('credits', defaultValue: 0) as int;
      _isGolden = box.get('isGolden', defaultValue: false) as bool;
      _referralCode = box.get('referralCode') as String?;
      _earnings = box.get('earnings', defaultValue: 0) as int;
      _referredCount = box.get('referredCount', defaultValue: 0) as int;
      _referralPercentage =
          box.get('referralPercentage', defaultValue: 10) as int;
      _minWithdrawal =
          box.get('minWithdrawal', defaultValue: 50000) as int;

      final expiryStr = box.get('goldenExpiry') as String?;
      if (expiryStr != null) {
        _goldenExpiry = DateTime.tryParse(expiryStr);
      }

      if (_credits > 0 || _isGolden || _referralCode != null) {
        _isProfileLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری cache: $e');
    }
  }

  // ─────────────────────────────────────────
  // ── ذخیره در cache محلی ──
  // ─────────────────────────────────────────
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
        if (_referralCode != null) 'referralCode': _referralCode,
        'earnings': _earnings,
        'referredCount': _referredCount,
        'referralPercentage': _referralPercentage,
        'minWithdrawal': _minWithdrawal,
        if (_goldenExpiry != null)
          'goldenExpiry': _goldenExpiry!.toIso8601String(),
      });
    } catch (e) {
      debugPrint('خطا در ذخیره cache: $e');
    }
  }

  // ─────────────────────────────────────────
  // ── دریافت پروفایل ──
  // ─────────────────────────────────────────
  Future<void> fetchProfile({bool force = false}) async {
    if (_token == null) return;

    // ── throttle: اگر خیلی زود صدا زده شده، رد کن ──
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

  // ─────────────────────────────────────────
  // ── آپدیت فیلدها از response ──
  // ─────────────────────────────────────────
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
    _minWithdrawal =
        (data['minWithdrawal'] as num?)?.toInt() ?? _minWithdrawal;

    // ── تاریخ انقضای اشتراک طلایی ──
    final expiryStr = data['goldenExpiry']?.toString() ??
        data['golden_expiry']?.toString();
    if (expiryStr != null) {
      _goldenExpiry = DateTime.tryParse(expiryStr);
    }
  }

  // ─────────────────────────────────────────
  // ── ارسال OTP ──
  // ─────────────────────────────────────────
  Future<void> sendOtp(String phone) async {
    await apiService.sendOtp(phone);
  }

  // ─────────────────────────────────────────
  // ── ورود ──
  // ─────────────────────────────────────────
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
      _token = res['token'] as String?;

      if (_token == null) {
        throw Exception('توکن دریافت نشد. لطفاً دوباره تلاش کنید.');
      }

      // ── ذخیره token ──
      await _storage.write(key: 'jwt_token', value: _token!);

      // ── آپدیت اولیه از response ورود ──
      final user = res['user'];
      if (user is Map<String, dynamic>) {
        _phone = phone;
        _updateProfileFromData(user);
      }

      // ── دریافت پروفایل کامل ──
      await fetchProfile(force: true);
      notifyListeners();
    } else {
      throw Exception(res['error'] ?? res['message'] ?? 'خطا در ورود');
    }
  }

  // ─────────────────────────────────────────
  // ── آپدیت اعتبار محلی ──
  // (بعد از خرید، بدون نیاز به fetch مجدد)
  // ─────────────────────────────────────────
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
      notifyListeners();
      _saveCachedProfile();
    }
  }

  void activateGolden({DateTime? expiry}) {
    _isGolden = true;
    _goldenExpiry = expiry;
    notifyListeners();
    _saveCachedProfile();
  }

  // ─────────────────────────────────────────
  // ── خروج ──
  // ─────────────────────────────────────────
  Future<void> logout() async {
    // ── ریست تمام فیلدها ──
    _token = null;
    _userId = null;
    _userName = null;
    _phone = null;
    _credits = 0;
    _isGolden = false;
    _goldenExpiry = null;
    _referralCode = null;
    _earnings = 0;
    _referredCount = 0;
    _referralPercentage = 10;
    _minWithdrawal = 50000;
    _isProfileLoaded = false;
    _profileLastFetched = null;
    _isFetchingProfile = false;

    // ── حذف token ──
    await _storage.delete(key: 'jwt_token');

    // ── پاکسازی cache ──
    await _clearLocalCache();

    notifyListeners();
  }

  Future<void> _clearLocalCache() async {
    final boxNames = ['diagnostics', 'history', 'user_profile'];
    for (final name in boxNames) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
        }
      } catch (e) {
        debugPrint('خطا در پاکسازی box "$name": $e');
      }
    }
  }

  // ─────────────────────────────────────────
  // ── اطمینان از اعتبار token ──
  // ─────────────────────────────────────────
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
