import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();

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
      final profile = await _apiService.getProfile(_token!);
      _credits = profile['credits'] ?? 0;
      _isGolden = profile['isGolden'] ?? false;
      notifyListeners();
    } catch (e) {
      // If unauthorized, logout
      if (e.toString().contains('401')) {
        await logout();
      }
    }
  }

  Future<void> login(String phone, String code) async {
    final res = await _apiService.verifyOtp(phone, code);
    _token = res['token'];
    _credits = res['credits'];
    _isGolden = res['isGolden'];
    await _storage.write(key: 'jwt_token', value: _token);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _credits = 0;
    _isGolden = false;
    await _storage.delete(key: 'jwt_token');
    notifyListeners();
  }
}
