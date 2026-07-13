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
  final http.Client _httpClient;
  final Duration _timeout = const Duration(seconds: 15);

  // تزریق وابستگی: برای تست‌پذیری و استفاده از Connection Pool
  ApiService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  /// متد کمکی برای دیکد کردن ایمن بدنه پاسخ
  dynamic _parseResponseBody(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(
        response.statusCode, 
        'خطا در پردازش پاسخ سرور. فرمت نامعتبر است.'
      );
    }
  }

  /// متد متمرکز برای مدیریت خطاها
  void _ensureSuccess(http.Response response, {String? defaultError}) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _parseResponseBody(response);
      final errorMessage = data is Map ? (data['error'] ?? defaultError ?? 'خطای ناشناخته') : (defaultError ?? 'خطای ناشناخته');
      throw ApiException(response.statusCode, errorMessage.toString());
    }
  }

  /// دریافت لیست خودروها از فایل JSON عمومی سرور
  Future<List<Car>> getCars() async {
    final response = await _httpClient
        .get(Uri.parse('${Constants.baseUrl}/cars.json'))
        .timeout(_timeout);

    _ensureSuccess(response, defaultError: 'خطا در دریافت لیست خودروها');
    final List<dynamic> data = _parseResponseBody(response);
    return data.map((json) => Car.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// ارسال کد یکبارمصرف (OTP) به شماره موبایل
  Future<void> sendOtp(String phone) async {
    final response = await _httpClient
        .post(
          Uri.parse('${Constants.baseUrl}/api/account'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'send', 'phone': phone}),
        )
        .timeout(_timeout);

    _ensureSuccess(response, defaultError: 'خطا در ارسال پیامک');
  }

  /// تأیید کد OTP و دریافت توکن
  /// پیشنهاد: به جای Map، یک Model اختصاصی (مثل AuthModel) برگردانید
  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final response = await _httpClient
        .post(
          Uri.parse('${Constants.baseUrl}/api/account'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'verify', 'phone': phone, 'code': code}),
        )
        .timeout(_timeout);

    _ensureSuccess(response, defaultError: 'خطا در ورود');
    return _parseResponseBody(response) as Map<String, dynamic>;
  }

  /// دریافت پروفایل کاربر (موجودی اعتبار و...)
  /// پیشنهاد: به جای Map، یک UserModel برگردانید
  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _httpClient
        .get(
          Uri.parse('${Constants.baseUrl}/api/account/credits'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    _ensureSuccess(response, defaultError: 'خطا در دریافت اطلاعات');
    return _parseResponseBody(response) as Map<String, dynamic>;
  }

  /// ارسال شرح مشکل و دریافت نتیجهٔ عیب‌یابی
  Future<String> diagnose(String token, String carId, String description) async {
    final response = await _httpClient
        .post(
          Uri.parse('${Constants.baseUrl}/api/diagnose'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'carId': carId, 'description': description}),
        )
        .timeout(_timeout);

    _ensureSuccess(response, defaultError: 'خطا در عیب‌یابی');
    
    final data = _parseResponseBody(response) as Map<String, dynamic>;
    // مدیریت ایمن کلید result
    if (data['result'] == null) {
      throw ApiException(500, 'سرور نتیجه عیب‌یابی را برنگرداند.');
    }
    return data['result'].toString();
  }

  /// دریافت تاریخچهٔ عیب‌یابی‌های کاربر
  Future<List<Diagnostic>> getHistory(String token) async {
    // استفاده صحیح از Uri برای مدیریت کوئری پارامترها
    final uri = Uri.parse('${Constants.baseUrl}/api/diagnose').replace(
      queryParameters: {'history': 'true'},
    );

    final response = await _httpClient
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(_timeout);

    _ensureSuccess(response, defaultError: 'خطا در دریافت تاریخچه');
    final List<dynamic> data = _parseResponseBody(response);
    return data.map((json) => Diagnostic.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// دریافت لینک پرداخت
  Future<String> getPaymentUrl(String token, String productId) async {
    final response = await _httpClient
        .post(
          Uri.parse('${Constants.baseUrl}/api/purchase'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'productId': productId}),
        )
        .timeout(_timeout);

    _ensureSuccess(response, defaultError: 'خطا در ایجاد پرداخت');
    
    final data = _parseResponseBody(response) as Map<String, dynamic>;
    if (data['paymentUrl'] == null) {
      throw ApiException(500, 'لینک پرداخت از سرور دریافت نشد.');
    }
    return data['paymentUrl'].toString();
  }
}﻿
