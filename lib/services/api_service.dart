import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/car.dart';
import '../models/diagnostic.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  Future<List<Car>> getCars() async {
    final response = await http.get(Uri.parse('${Constants.baseUrl}/cars.json'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Car.fromJson(json)).toList();
    }
    throw ApiException(response.statusCode, 'خطا در دریافت لیست خودروها');
  }

  Future<void> sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/api/account'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'send', 'phone': phone}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, 'خطا در ارسال پیامک');
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/api/account'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'verify', 'phone': phone, 'code': code}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw ApiException(res.statusCode, data['error'] ?? 'خطا در ورود');
    return data;
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/api/account/credits'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw ApiException(res.statusCode, data['error'] ?? 'خطا در دریافت اطلاعات');
    return data;
  }

  Future<String> diagnose(String token, String carId, String description) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/api/diagnose'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'carId': carId, 'description': description}),
    );
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) throw ApiException(res.statusCode, data['error'] ?? 'خطا در عیب‌یابی');
    return data['result'];
  }

  Future<List<Diagnostic>> getHistory(String token) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/api/diagnose?history=true'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => Diagnostic.fromJson(json)).toList();
    }
    throw ApiException(res.statusCode, 'خطا در دریافت تاریخچه');
  }

  Future<String> getPaymentUrl(String token, String productId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/api/purchase'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'productId': productId}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw ApiException(res.statusCode, data['error'] ?? 'خطا در ایجاد پرداخت');
    return data['paymentUrl'];
  }
}