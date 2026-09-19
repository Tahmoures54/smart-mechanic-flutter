import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/car.dart';
import '../models/diagnostic.dart';
import '../models/garage_registration.dart';

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

class DiagnosisApiResult {
  final String result;
  final String? diagnosticId;
  final String responseMode;
  final Map<String, dynamic>? structured;

  const DiagnosisApiResult({
    required this.result,
    this.diagnosticId,
    this.responseMode = 'diagnosis',
    this.structured,
  });
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
      };
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
  static const _minRequestInterval = Duration(milliseconds: 800);
  static const _sensitiveRequestInterval = Duration(seconds: 3);

  ApiService({
    http.Client? httpClient,
    Duration defaultTimeout = const Duration(seconds: 20),
    Duration diagnoseTimeout = const Duration(seconds: 60),
    Duration uploadTimeout = const Duration(seconds: 90),
  })  : _httpClient = httpClient ?? http.Client(),
        _defaultTimeout = defaultTimeout,
        _diagnoseTimeout = diagnoseTimeout,
        _uploadTimeout = uploadTimeout;

  Map<String, String> _getHeaders([String? token]) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, String> _getMultipartHeaders(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  dynamic _parseBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};

    final raw = utf8.decode(response.bodyBytes, allowMalformed: true)
        .replaceFirst('\uFEFF', '')
        .trim();
    if (raw.isEmpty) return <String, dynamic>{};

    try {
      return jsonDecode(raw);
    } catch (_) {
      final contentType = response.headers['content-type'] ?? 'unknown';
      debugPrint(
        '[API Error] Invalid JSON: ${response.statusCode}, '
        'content-type=$contentType, body=${_truncate(raw, max: 180)}',
      );
      throw ApiException(
        response.statusCode,
        response.statusCode >= 500
            ? 'سرور موقتاً پاسخ معتبر نداد. لطفاً چند لحظه بعد دوباره تلاش کنید.'
            : 'پاسخ سرور قابل پردازش نیست. لطفاً اتصال اینترنت را بررسی و دوباره تلاش کنید.',
      );
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
    return data is Map<String, dynamic>
        ? data
        : <String, dynamic>{'data': data};
  }

  Future<void> _checkRateLimit(String key) async {
    final last = _lastRequestTime[key];
    final isSensitive = key.startsWith('sendOtp') ||
        key.startsWith('verifyOtp') ||
        key == 'withdraw' ||
        key == 'getPaymentUrl';
    final interval = isSensitive ? _sensitiveRequestInterval : _minRequestInterval;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < interval) await Future.delayed(interval - elapsed);
    }
    _lastRequestTime[key] = DateTime.now();
  }

  Future<http.Response> _safeCall(
    Future<http.Response> Function() call, {
    Duration? timeout,
    String? rateLimitKey,
  }) async {
    if (rateLimitKey != null) await _checkRateLimit(rateLimitKey);

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

  static const _bundledCarsAsset = 'assets/data/cars.json';

  Future<List<Car>> getCars({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _carsCache != null &&
        _carsCacheTime != null &&
        DateTime.now().difference(_carsCacheTime!) < _carsCacheDuration) {
      debugPrint('[API] لیست خودروها از cache برگشت داده شد.');
      return _carsCache!;
    }

    final local = await _loadBundledCars();
    var remote = <Car>[];
    try {
      remote = await _fetchRemoteCars();
    } catch (e) {
      debugPrint('[API] دریافت cars.json سرور ناموفق بود: $e');
      if (local.isEmpty) rethrow;
    }

    final cars = _mergeCars(local, remote);
    if (cars.isEmpty) throw const ApiException(404, 'لیست خودروها خالی است');

    _carsCache = cars;
    _carsCacheTime = DateTime.now();
    debugPrint('[API] ${cars.length} وسیله نقلیه آماده شد (داخلی: ${local.length}، سرور: ${remote.length}).');
    return cars;
  }

  Future<List<Car>> _loadBundledCars() async {
    try {
      final raw = await rootBundle.loadString(_bundledCarsAsset);
      return _parseCarsJson(json.decode(raw));
    } catch (e) {
      debugPrint('[API] خواندن کاتالوگ داخلی ناموفق بود: $e');
      return const [];
    }
  }

  Future<List<Car>> _fetchRemoteCars() async {
    final baseUri = Uri.parse(Constants.baseUrl);
    final carsUri = baseUri.replace(path: '/cars.json', queryParameters: null);
    final response = await _safeCall(
      () => _httpClient.get(carsUri, headers: {'Accept': 'application/json'}),
      rateLimitKey: 'getCars',
    );
    return _parseCarsJson(_parseBody(response));
  }

  List<Car> _parseCarsJson(dynamic body) {
    final List<dynamic> rawList;
    if (body is List<dynamic>) {
      rawList = body;
    } else if (body is Map && body['cars'] is List<dynamic>) {
      rawList = body['cars'] as List<dynamic>;
    } else {
      rawList = const [];
    }
    return rawList
        .whereType<Map>()
        .map((j) => Car.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  List<Car> _mergeCars(List<Car> local, List<Car> remote) {
    final byId = <String>{};
    final byKey = <String>{};
    final out = <Car>[];

    void add(Car car) {
      if (car.id.isEmpty) return;
      final key = '${car.brand.trim().toLowerCase()}|${car.model.trim().toLowerCase()}|${car.engine.trim().toLowerCase()}';
      if (byId.contains(car.id) || byKey.contains(key)) return;
      byId.add(car.id);
      byKey.add(key);
      out.add(car);
    }

    for (final car in local) add(car);
    for (final car in remote) add(car);
    return out;
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

  Future<DiagnosisApiResult> diagnoseDetailed(
    String token,
    String carId,
    String description, {
    required String year,
    String? carName,
    String? previousDiagnosticId,
    double? lat,
    double? lng,
    String? city,
  }) async {
    final body = <String, dynamic>{
      'carId': carId,
      'year': year,
      'description': description,
      if (carName != null && carName.trim().isNotEmpty) 'carName': carName.trim(),
      if (previousDiagnosticId != null && previousDiagnosticId.trim().isNotEmpty)
        'previousDiagnosticId': int.tryParse(previousDiagnosticId.trim()) ?? previousDiagnosticId.trim(),
      if (lat != null && lng != null && lat.isFinite && lng.isFinite) ...{
        'lat': lat,
        'lng': lng,
      },
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
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
    final result = _extractResult(data);
    if (result == null || result.isEmpty) throw const ApiException(500, 'سرور نتیجه‌ای برنگرداند.');
    final inner = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};
    final structuredRaw = data['structured'] is Map
        ? data['structured']
        : inner['structured'];
    final structured = structuredRaw is Map
        ? Map<String, dynamic>.from(structuredRaw)
        : null;
    return DiagnosisApiResult(
      result: result,
      diagnosticId: data['diagnosticId']?.toString() ?? inner['diagnosticId']?.toString(),
      responseMode: structured?['responseMode']?.toString() ?? 'diagnosis',
      structured: structured,
    );
  }

  Future<String> diagnose(String token, String carId, String description, {required String year, String? carName}) async {
    final response = await diagnoseDetailed(token, carId, description, year: year, carName: carName);
    return response.result;
  }

  String? _extractResult(Map<String, dynamic> data) {
    if (data['data'] is Map) {
      final d = data['data'] as Map;
      return d['result']?.toString() ?? d['answer']?.toString() ?? d['text']?.toString();
    }
    return data['result']?.toString() ?? data['answer']?.toString() ?? data['text']?.toString();
  }

  Future<DiagnosisApiResult> uploadAudioAndDiagnoseDetailed(
    String token, {
    required String filePath,
    required String carId,
    required String year,
    String? carName,
    String? audioFeatures,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw const ApiException(0, 'فایل صوتی پیدا نشد.');
    final fileSize = await file.length();
    debugPrint('[API] آپلود فایل صوتی: ${fileSize ~/ 1024} KB');

    final uri = Uri.parse('${Constants.diagnose}/audio');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_getMultipartHeaders(token))
      ..fields['carId'] = carId
      ..fields['year'] = year
      ..files.add(await http.MultipartFile.fromPath(
            'audio',
            filePath,
            filename: filePath.toLowerCase().endsWith('.wav') ? 'engine_sound.wav' : 'engine_sound.m4a',
          ));
    if (carName != null && carName.trim().isNotEmpty) request.fields['carName'] = carName.trim();
    if (audioFeatures != null && audioFeatures.trim().isNotEmpty) {
      request.fields['audioFeatures'] = audioFeatures.trim();
    }

    try {
      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final data = _parseAndEnsure(response, defaultError: 'خطا در آپلود و تحلیل صدا');
      final result = _extractResult(data);
      if (result == null || result.isEmpty) throw const ApiException(500, 'سرور نتیجه تحلیل صدا را برنگرداند.');
      final inner = data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : <String, dynamic>{};
      return DiagnosisApiResult(
        result: result,
        diagnosticId: data['diagnosticId']?.toString() ?? inner['diagnosticId']?.toString(),
        responseMode: inner['structured'] is Map ? (inner['structured']['responseMode']?.toString() ?? 'diagnosis') : 'diagnosis',
        structured: inner['structured'] is Map
            ? Map<String, dynamic>.from(inner['structured'] as Map)
            : null,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(408, 'آپلود فایل بیش از حد طول کشید. لطفاً دوباره تلاش کنید.');
    } catch (e) {
      throw ApiException(500, 'خطا در آپلود فایل: $e');
    }
  }

  Future<String> uploadAudioAndDiagnose(
    String token, {
    required String filePath,
    required String carId,
    required String year,
    String? carName,
    String? audioFeatures,
  }) async {
    final response = await uploadAudioAndDiagnoseDetailed(
      token,
      filePath: filePath,
      carId: carId,
      year: year,
      carName: carName,
      audioFeatures: audioFeatures,
    );
    return response.result;
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
    } else if (data['items'] is List) {
      rawList = data['items'] as List;
    } else {
      rawList = [];
    }
    return rawList.whereType<Map<String, dynamic>>().map(Diagnostic.fromJson).toList();
  }

  Future<void> deleteHistory(String token, String diagnosticId) async {
    if (diagnosticId.isEmpty) throw const ApiException(400, 'شناسه تاریخچه نامعتبر است.');
    final uri = Uri.parse('${Constants.diagnose}/$diagnosticId');
    final response = await _safeCall(
      () => _httpClient.delete(uri, headers: _getHeaders(token)),
      rateLimitKey: 'deleteHistory',
    );
    _parseAndEnsure(response, defaultError: 'خطا در حذف تاریخچه');
  }

  Future<List<OwnedGarage>> getOwnedGarages(String token) async {
    final response = await _safeCall(
      () => _httpClient.get(
        Uri.parse(Constants.garagesRegister),
        headers: _getHeaders(token),
      ),
      rateLimitKey: 'getOwnedGarages',
    );
    final data = _parseAndEnsure(response, defaultError: 'خطا در دریافت تعمیرگاه‌های شما');
    final raw = data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => OwnedGarage.fromJson(Map<String, dynamic>.from(item)))
        .where((garage) => garage.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<OwnedGarage> registerGarage(
    String token, {
    required String name,
    required double lat,
    required double lng,
    String? city,
    String? address,
    String? phone,
    List<String> specialties = const [],
    String? description,
  }) async {
    if (name.trim().length < 2) throw const ApiException(400, 'نام تعمیرگاه الزامی است.');
    if (!lat.isFinite || !lng.isFinite || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw const ApiException(400, 'مختصات تعمیرگاه نامعتبر است.');
    }

    final body = <String, dynamic>{
      'name': name.trim(),
      'lat': lat,
      'lng': lng,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (specialties.isNotEmpty) 'specialties': specialties,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
    };
    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.garagesRegister),
        headers: _getHeaders(token),
        body: jsonEncode(body),
      ),
      rateLimitKey: 'registerGarage',
    );
    final data = _parseAndEnsure(response, defaultError: 'ثبت تعمیرگاه ناموفق بود');
    final raw = data['data'];
    if (raw is! Map) throw const ApiException(500, 'پاسخ ثبت تعمیرگاه نامعتبر است.');
    return OwnedGarage.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<String> getPaymentUrl(String token, String productId, {String? garageId}) async {
    if (productId.isEmpty) throw const ApiException(400, 'شناسه محصول نامعتبر است.');
    final body = <String, dynamic>{
      'productId': productId,
      if (garageId != null && garageId.trim().isNotEmpty)
        'garageId': int.tryParse(garageId.trim()) ?? garageId.trim(),
    };
    final response = await _safeCall(
      () => _httpClient.post(
        Uri.parse(Constants.purchase),
        headers: _getHeaders(token),
        body: jsonEncode(body),
      ),
      rateLimitKey: 'getPaymentUrl',
    );
    final data = _parseAndEnsure(response, defaultError: 'خطا در ایجاد لینک پرداخت');
    // بک‌اند فیلد paymentUrl برمی‌گرداند؛ برای سازگاری url هم پشتیبانی می‌شود.
    String? url = data['paymentUrl']?.toString() ?? data['url']?.toString();
    if ((url == null || url.isEmpty) && data['data'] is Map) {
      final inner = data['data'] as Map;
      url = inner['paymentUrl']?.toString() ?? inner['url']?.toString();
    }
    if (url == null || url.isEmpty) {
      throw const ApiException(500, 'لینک پرداخت از سرور دریافت نشد.');
    }
    return url;
  }
}
