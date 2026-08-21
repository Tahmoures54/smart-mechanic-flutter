import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/car.dart';
import '../models/diagnostic.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  const ApiException(this.statusCode, this.message, {this.details});

  bool get isUnauthorized => statusCode == 401;
  bool get isPaymentRequired => statusCode == 402;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;
  bool get isTimeout => statusCode == 408;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiResponse<T> {
  final T data;
  final int statusCode;
  final Map<String, dynamic>? meta;

  const ApiResponse({required this.data, required this.statusCode, this.meta});
}

class PaginationParams {
  final int page;
  final int limit;

  const PaginationParams({this.page = 1, this.limit = 20});

  Map<String, String> toQueryParams() => {
        'page': page.toString(),
        'limit': limit.toString(),
        // بک‌اند از offset استفاده می‌کند
        'offset': ((page - 1) * limit).toString(),
      };
}

/// نتیجه عیب‌یابی از سرور (شامل diagnosticId برای feedback)
class DiagnoseApiResult {
  final String result;
  final int? diagnosticId;
  final int? remainingCredits;
  final int? remainingFreeQuestions;

  const DiagnoseApiResult({
    required this.result,
    this.diagnosticId,
    this.remainingCredits,
    this.remainingFreeQuestions,
  });
}

class ApiService {
  final http.Client _httpClient;

  final Duration _defaultTimeout;
  final Duration _diagnoseTimeout;
  final Duration _uploadTimeout;

  List<Car>? _carsCache;
  DateTime? _carsCacheTime;
  static const _carsCacheDuration = Duration(hours: 6);

  final Map<String, DateTime> _lastRequestTime = {};
  static const _minRequestInterval = Duration(milliseconds: 500);

  ApiService({
    http.Client? httpClient,
    Duration defaultTimeout = const Duration(seconds: 20),
    Duration diagnoseTimeout = const Duration(seconds: 60),
    Duration uploadTimeout = const Duration(seconds: 90),
  })  : _httpClient = httpClient ?? http.Client(),
        _defaultTimeout = defaultTimeout,
        _diagnoseTimeout = diagnoseTimeout,
        _uploadTimeout = uploadTimeout;

  Map<String, String> _getHeaders([String? token]) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> _getMultipartHeaders(String token) {
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _parseBody(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(response.statusCode, 'خطا در پردازش پاسخ سرور.');
    }
  }

  Map<String, dynamic> _parseAndEnsure(
    http.Response response, {
    String? defaultError,
  }) {
    final data = _parseBody(response);

    if (response.statusCode >= 400 || (data is Map && data['success'] == false)) {
      final msg = data is Map
          ? (data['error'] ?? data['message'] ?? defaultError ?? 'خطای سرور')
          : (defaultError ?? 'خطای ناشناخته');

      final details = data is Map ? Map<String, dynamic>.from(data) : null;

      throw ApiException(response.statusCode, msg.toString(), details: details);
    }

    if (data is List) return {'data': data};
    return data is Map<String, dynamic> ? data : <String, dynamic>{'data': data};
  }

  Future<void> _checkRateLimit(String key) async {
    final last = _lastRequestTime[key];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime[key] = DateTime.now();
  }

  Future<http.Response> _safeCall(
    Future<http.Response> Function() call, {
    Duration? timeout,
    String? rateLimitKey,
  }) async {
    if (rateLimitKey != null) {
      await _checkRateLimit(rateLimitKey);
    }

    try {
      final response = await call().timeout(timeout ?? _defaultTimeout);
      _log('${response.statusCode}', response.request?.url.toString() ?? '');
      return response;
    } on SocketException catch (e) {
      _logError('SocketException', e.message);
      throw const ApiException(0, 'عدم اتصال به اینترنت. لطفاً شبکه خود را بررسی کنید.');
    } on TimeoutException {
      _logError('Timeout', 'درخواست بیش از حد طول کشید.');
      throw const ApiException(408, 'زمان درخواست پایان یافت. لطفاً دوباره تلاش کنید.');
    } on HandshakeException catch (e) {
      _logError('TLS Error', e.message);
      throw const ApiException(0, 'خطا در اتصال امن. لطفاً اینترنت خود را بررسی کنید.');
    } catch (e) {
      if (e is ApiException) rethrow;
      _logError('Unknown', e.toString());
      throw const ApiException(500, 'خطای نامشخص در برقراری ارتباط با سرور.');
    }
  }

  void _log(String status, String url) => debugPrint('[API] $status → ${_truncate(url)}');
  void _logError(String type, String msg) => debugPrint('[API Error] $type: ${_truncate(msg)}');
  String _truncate(String s, {int max = 100}) => s.length > max ? '${s.substring(0, max)}...' : s;

  // ── Cars: اول /api/cars سپس fallback به cars.json ──
  Future<List<Car>> getCars({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _carsCache != null &&
        _carsCacheTime != null &&
        DateTime.now().difference(_carsCacheTime!) < _carsCacheDuration) {
      return _carsCache!;
    }

    try {
      final response = await _safeCall(
        () => _httpClient.get(
          Uri.parse(Constants.carsApi),
          headers: {'Accept': 'application/json'},
        ),
        rateLimitKey: 'getCars',
      );
      final body = _parseBody(response);
      final List<dynamic> rawList = body is Map && body['data'] is List
          ? body['data'] as List
          : (body is List ? body : []);
      final cars = rawList.map((j) => Car.fromJson(j as Map<String, dynamic>)).toList();
      _carsCache = cars;
      _carsCacheTime = DateTime.now();
      return cars;
    } catch (_) {
      // fallback static
      final response = await _safeCall(
        () => _httpClient.get(
          Uri.parse(Constants.carsJson),
          headers: {'Accept': 'application/json'},
        ),
        rateLimitKey: 'getCarsJson',
      );
      final body = _parseBody(response);
      final List<dynamic> rawList = body is Map && body.containsKey('cars')
          ? body['cars'] as List<dynamic>
          : (body is List ? body : []);
      final cars = rawList.map((j) => Car.fromJson(j as Map<String, dynamic>)).toList();
      _carsCache = cars;
      _carsCacheTime = DateTime.now();
      return cars;
    }
  }

  void clearCarsCache() {
    _carsCache = null;
    _carsCacheTime = null;
  }

  Future<void> sendOtp(String phone) async {
    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.account),
        headers: _getHeaders(),
        body: jsonEncode({'action': 'send', 'phone': phone}),
      ),
      rateLimitKey: 'sendOtp_$phone',
    );
    _parseAndEnsure(response, defaultError: 'خطا در ارسال کد تأیید');
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code, {String? referralCode}) async {
    final body = <String, dynamic>{
      'action': 'verify',
      'phone': phone,
      'code': code,
      if (referralCode != null && referralCode.trim().isNotEmpty) 'referralCode': referralCode.trim(),
    };

    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.account),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
      rateLimitKey: 'verifyOtp_$phone',
    );

    return _parseAndEnsure(response, defaultError: 'خطا در ورود');
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _safeCall(
      () => _httpClient.get(Uri.parse(Constants.credits), headers: _getHeaders(token)),
      rateLimitKey: 'getProfile',
    );
    return _parseAndEnsure(response, defaultError: 'خطا در دریافت پروفایل');
  }

  Future<void> requestWithdraw(String token, {required int amount, required String cardNumber, required String fullName}) async {
    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.withdraw),
        headers: _getHeaders(token),
        body: jsonEncode({'amount': amount, 'cardNumber': cardNumber, 'fullName': fullName}),
      ),
      rateLimitKey: 'withdraw',
    );
    _parseAndEnsure(response, defaultError: 'خطا در ثبت درخواست برداشت');
  }

  /// عیب‌یابی — برمی‌گرداند result + diagnosticId
  Future<DiagnoseApiResult> diagnose(
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
      if (carName != null && carName.trim().isNotEmpty) 'carName': carName.trim(),
    };

    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.diagnose),
        headers: _getHeaders(token),
        body: jsonEncode(body),
      ),
      timeout: _diagnoseTimeout,
      rateLimitKey: 'diagnose',
    );

    final data = _parseAndEnsure(response, defaultError: 'خطا در عیب‌یابی');
    final resultText = _extractResult(data);
    if (resultText == null || resultText.isEmpty) {
      throw const ApiException(500, 'سرور نتیجه‌ای برنگرداند.');
    }

    final diagId = data['diagnosticId'] is int
        ? data['diagnosticId'] as int
        : int.tryParse('${data['diagnosticId']}');

    return DiagnoseApiResult(
      result: resultText,
      diagnosticId: diagId,
      remainingCredits: data['remainingCredits'] is int ? data['remainingCredits'] as int : null,
      remainingFreeQuestions:
          data['remainingFreeQuestions'] is int ? data['remainingFreeQuestions'] as int : null,
    );
  }

  String? _extractResult(Map<String, dynamic> data) {
    if (data['data'] is Map) {
      final d = data['data'] as Map;
      return d['result']?.toString() ?? d['answer']?.toString() ?? d['text']?.toString();
    }
    return data['result']?.toString() ?? data['answer']?.toString() ?? data['text']?.toString();
  }

  Future<DiagnoseApiResult> uploadAudioAndDiagnose(
    String token, {
    required String filePath,
    required String carId,
    required String year,
    String? carName,
    String? description,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw const ApiException(0, 'فایل صوتی پیدا نشد.');

    final uri = Uri.parse(Constants.diagnoseAudio);
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_getMultipartHeaders(token))
      ..fields['carId'] = carId
      ..fields['year'] = year
      ..files.add(await http.MultipartFile.fromPath('audio', filePath, filename: 'engine_sound.m4a'));

    if (carName != null && carName.trim().isNotEmpty) {
      request.fields['carName'] = carName.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }

    try {
      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final data = _parseAndEnsure(response, defaultError: 'خطا در آپلود و تحلیل صدا');
      final resultText = _extractResult(data);
      if (resultText == null || resultText.isEmpty) {
        throw const ApiException(500, 'سرور نتیجه تحلیل صدا را برنگرداند.');
      }
      final diagId = data['diagnosticId'] is int
          ? data['diagnosticId'] as int
          : int.tryParse('${data['diagnosticId']}');
      return DiagnoseApiResult(result: resultText, diagnosticId: diagId);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(408, 'آپلود فایل بیش از حد طول کشید. لطفاً دوباره تلاش کنید.');
    } catch (e) {
      throw ApiException(500, 'خطا در آپلود فایل: $e');
    }
  }

  Future<List<Diagnostic>> getHistory(String token, {PaginationParams? pagination}) async {
    final params = {'history': 'true', ...?(pagination?.toQueryParams())};
    final uri = Uri.parse(Constants.diagnose).replace(queryParameters: params);

    final response = await _safeCall(
      () => _httpClient.get(uri, headers: _getHeaders(token)),
      rateLimitKey: 'getHistory',
    );

    final data = _parseAndEnsure(response, defaultError: 'خطا در دریافت تاریخچه');

    final List<dynamic> rawList;
    if (data['data'] is List) {
      rawList = data['data'] as List;
    } else if (data['history'] is List) {
      rawList = data['history'] as List;
    } else {
      rawList = [];
    }

    return rawList.whereType<Map<String, dynamic>>().map(Diagnostic.fromJson).toList();
  }

  Future<void> deleteHistory(String token, String diagnosticId) async {
    if (diagnosticId.isEmpty) throw const ApiException(400, 'شناسه تاریخچه نامعتبر است.');

    final uri = Uri.parse(Constants.deleteDiagnose(diagnosticId));
    final response = await _safeCall(
      () => _httpClient.delete(uri, headers: _getHeaders(token)),
      rateLimitKey: 'deleteHistory',
    );
    _parseAndEnsure(response, defaultError: 'خطا در حذف تاریخچه');
  }

  Future<String> getPaymentUrl(String token, String productId) async {
    if (productId.isEmpty) throw const ApiException(400, 'شناسه محصول نامعتبر است.');

    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.purchase),
        headers: _getHeaders(token),
        body: jsonEncode({'productId': productId}),
      ),
      rateLimitKey: 'getPaymentUrl',
    );

    final data = _parseAndEnsure(response, defaultError: 'خطا در ایجاد درگاه پرداخت');
    final url = data['paymentUrl']?.toString() ?? data['payment_url']?.toString() ?? data['url']?.toString();

    if (url == null || url.isEmpty) throw const ApiException(500, 'لینک پرداخت از سرور دریافت نشد.');
    return url;
  }

  /// امتیاز به نتیجه عیب‌یابی (۱–۵)
  Future<void> submitFeedback(
    String token, {
    required int diagnosticId,
    required int rating,
    String? feedback,
  }) async {
    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.feedback),
        headers: _getHeaders(token),
        body: jsonEncode({
          'diagnosticId': diagnosticId,
          'rating': rating,
          if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
        }),
      ),
      rateLimitKey: 'feedback',
    );
    _parseAndEnsure(response, defaultError: 'خطا در ثبت نظر');
  }

  /// رویداد آنالیتیکس (خطا را می‌بلعد تا UX خراب نشود)
  Future<void> trackEvent(
    String eventName, {
    String? token,
    Map<String, dynamic>? properties,
    String platform = 'android',
  }) async {
    if (!Constants.featureAnalytics) return;
    try {
      await _safeCall(
        () => _httpClient.post(
          Uri.parse(Constants.events),
          headers: _getHeaders(token),
          body: jsonEncode({
            'eventName': eventName,
            'platform': platform,
            'appVersion': Constants.appVersion,
            if (properties != null) 'properties': properties,
          }),
        ),
        rateLimitKey: 'event_$eventName',
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('[Analytics] soft-fail $eventName: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final response = await _safeCall(
      () => _httpClient.get(
        Uri.parse(Constants.products),
        headers: {'Accept': 'application/json'},
      ),
      rateLimitKey: 'products',
    );
    final data = _parseAndEnsure(response);
    final list = data['data'] is List ? data['data'] as List : [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  void dispose() {
    _httpClient.close();
    _lastRequestTime.clear();
  }
}
