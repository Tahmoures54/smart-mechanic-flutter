import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
  final Duration _timeout = const Duration(seconds: 20);
  final Duration _diagnoseTimeout = const Duration(seconds: 45);

  ApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Map<String, String> _getHeaders([String? token]) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _parseResponseBody(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(
        response.statusCode,
        'خطا در پردازش پاسخ سرور. لطفاً دوباره تلاش کنید.',
      );
    }
  }

  void _ensureSuccess(http.Response response, {String? defaultError}) {
    final data = _parseResponseBody(response);

    if (response.statusCode >= 400 ||
        (data is Map && data['success'] == false)) {
      final errorMessage = data is Map
          ? (data['error'] ??
              data['message'] ??
              defaultError ??
              'خطای سرور')
          : (defaultError ?? 'خطای ناشناخته از سمت سرور');
      throw ApiException(response.statusCode, errorMessage.toString());
    }
  }

  Future<http.Response> _safeApiCall(
    Future<http.Response> Function() apiCall, {
    Duration? timeout,
  }) async {
    try {
      return await apiCall().timeout(timeout ?? _timeout);
    } on SocketException {
      throw ApiException(
        0,
        'عدم اتصال به اینترنت. لطفاً شبکه خود را بررسی کنید.',
      );
    } on TimeoutException {
      throw ApiException(
        408,
        'زمان درخواست پایان یافت. سرور پاسخگو نبود.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(500, 'خطای نامشخص در برقراری ارتباط با سرور.');
    }
  }

  Future<List<Car>> getCars() async {
    final publicBaseUrl = Constants.baseUrl.replaceAll('/api', '');

    final response = await _safeApiCall(
      () => _httpClient.get(
        Uri.parse('$publicBaseUrl/cars.json'),
        headers: {'Accept': 'application/json'},
      ),
    );

    _ensureSuccess(response, defaultError: 'خطا در دریافت لیست خودروها');

    final decoded = _parseResponseBody(response);
    final List<dynamic> data = decoded is Map && decoded.containsKey('cars')
        ? decoded['cars']
        : decoded;

    return data
        .map((json) => Car.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendOtp(String phone) async {
    final response = await _safeApiCall(
      () => _httpClient.post(
        Uri.parse(Constants.account),
        headers: _getHeaders(),
        body: jsonEncode({'action': 'send', 'phone': phone}),
      ),
    );

    _ensureSuccess(response, defaultError: 'خطا در ارسال پیامک');
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    String? referralCode,
  }) async {
    final body = <String, dynamic>{
      'action': 'verify',
      'phone': phone,
      'code': code,
    };
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      body['referralCode'] = referralCode.trim();
    }

    final response = await _safeApiCall(
      () => _httpClient.post(
        Uri.parse(Constants.account),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
    );

    _ensureSuccess(response, defaultError: 'خطا در ورود');
    return _parseResponseBody(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _safeApiCall(
      () => _httpClient.get(
        Uri.parse(Constants.credits),
        headers: _getHeaders(token),
      ),
    );

    _ensureSuccess(response, defaultError: 'خطا در دریافت اطلاعات کاربری');
    return _parseResponseBody(response) as Map<String, dynamic>;
  }

  Future<String> diagnose(
    String token,
    String carId,
    String description, {
    required String year,
    String? carName,
  }) async {
    final body = <String, dynamic>{
      'carId': carId,
      'year': year,
      'description': description,
    };
    if (carName != null && carName.trim().isNotEmpty) {
      body['carName'] = carName.trim();
    }

    final response = await _safeApiCall(
      () => _httpClient.post(
        Uri.parse(Constants.diagnose),
        headers: _getHeaders(token),
        body: jsonEncode(body),
      ),
      timeout: _diagnoseTimeout,
    );

    _ensureSuccess(response, defaultError: 'خطا در عیب‌یابی ماشین');

    final data = _parseResponseBody(response) as Map<String, dynamic>;

    if (data['data'] != null && data['data']['result'] != null) {
      return data['data']['result'].toString();
    }

    throw ApiException(500, 'سرور نتیجه عیب‌یابی را برنگرداند.');
  }

  Future<List<Diagnostic>> getHistory(String token) async {
    final uri = Uri.parse(Constants.diagnose)
        .replace(queryParameters: {'history': 'true'});

    final response = await _safeApiCall(
      () => _httpClient.get(uri, headers: _getHeaders(token)),
    );

    _ensureSuccess(response, defaultError: 'خطا در دریافت تاریخچه');
    final parsed = _parseResponseBody(response);
    final List<dynamic> data = parsed is List ? parsed : [];
    return data
        .map((json) => Diagnostic.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<String> getPaymentUrl(String token, String productId) async {
    final response = await _safeApiCall(
      () => _httpClient.post(
        Uri.parse(Constants.purchase),
        headers: _getHeaders(token),
        body: jsonEncode({'productId': productId}),
      ),
    );

    _ensureSuccess(response, defaultError: 'خطا در ایجاد درگاه پرداخت');

    final data = _parseResponseBody(response) as Map<String, dynamic>;
    if (data['paymentUrl'] == null) {
      throw ApiException(500, 'لینک پرداخت از سرور دریافت نشد.');
    }
    return data['paymentUrl'].toString();
  }
}
