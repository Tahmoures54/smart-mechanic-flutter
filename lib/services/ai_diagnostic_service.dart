import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/audio_features.dart';
import 'api_service.dart';

class DiagnosticCode {
  final String code;
  final String description;
  final OBDSeverity severity;
  final String? system;

  const DiagnosticCode({
    required this.code,
    required this.description,
    this.severity = OBDSeverity.unknown,
    this.system,
  });

  factory DiagnosticCode.fromJson(Map<String, dynamic> json) {
    return DiagnosticCode(
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      severity: OBDSeverity.fromString(json['severity']?.toString()),
      system: json['system']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'description': description,
        'severity': severity.name,
        if (system != null) 'system': system,
      };

  @override
  String toString() => '$code: $description';
}

enum OBDSeverity {
  low,
  medium,
  high,
  critical,
  unknown;

  String get label => switch (this) {
        OBDSeverity.low => 'کم‌اهمیت',
        OBDSeverity.medium => 'متوسط',
        OBDSeverity.high => 'مهم',
        OBDSeverity.critical => 'بحرانی',
        OBDSeverity.unknown => 'نامشخص',
      };

  static OBDSeverity fromString(String? value) {
    if (value == null) return OBDSeverity.unknown;
    final lower = value.toLowerCase();
    for (final sev in OBDSeverity.values) {
      if (sev.name == lower) return sev;
    }
    return OBDSeverity.unknown;
  }
}

class DiagnosticResult {
  final String text;
  final String prompt;
  final DateTime timestamp;
  final DiagnosticInputType type;
  final int? diagnosticId;
  final int? remainingCredits;
  final int? remainingFreeQuestions;

  const DiagnosticResult({
    required this.text,
    required this.prompt,
    required this.timestamp,
    required this.type,
    this.diagnosticId,
    this.remainingCredits,
    this.remainingFreeQuestions,
  });

  bool get isEmpty => text.trim().isEmpty;
}

enum DiagnosticInputType {
  textOnly,
  audioOnly,
  obdOnly,
  combined;

  String get label => switch (this) {
        DiagnosticInputType.textOnly => 'متنی',
        DiagnosticInputType.audioOnly => 'صوتی',
        DiagnosticInputType.obdOnly => 'دیاگ OBD',
        DiagnosticInputType.combined => 'ترکیبی',
      };
}

class DiagnosticRequest {
  final String token;
  final String carId;
  final String year;
  final String? carName;
  final String? userDescription;
  final AudioFeatures? audioFeatures;
  final List<DiagnosticCode>? obdCodes;

  const DiagnosticRequest({
    required this.token,
    required this.carId,
    required this.year,
    this.carName,
    this.userDescription,
    this.audioFeatures,
    this.obdCodes,
  });

  DiagnosticInputType get inputType {
    final hasText = userDescription != null && userDescription!.trim().isNotEmpty;
    final hasAudio = audioFeatures != null;
    final hasObd = obdCodes != null && obdCodes!.isNotEmpty;

    if (hasText && (hasAudio || hasObd)) return DiagnosticInputType.combined;
    if (hasAudio && !hasText) return DiagnosticInputType.audioOnly;
    if (hasObd && !hasText) return DiagnosticInputType.obdOnly;
    return DiagnosticInputType.textOnly;
  }

  String? validate() {
    if (token.isEmpty) return 'توکن الزامی است.';
    if (carId.isEmpty) return 'شناسه خودرو الزامی است.';
    if (year.isEmpty) return 'سال ساخت الزامی است.';

    final hasAnyInput = (userDescription?.trim().isNotEmpty ?? false) ||
        audioFeatures != null ||
        (obdCodes?.isNotEmpty ?? false);

    if (!hasAnyInput) {
      return 'حداقل یکی از موارد (متن، صدا، یا کد OBD) الزامی است.';
    }

    return null;
  }
}

class AIDiagnosticService {
  final ApiService _apiService;

  final int _maxRetries;
  final Duration _retryDelay;

  final Map<String, DiagnosticResult> _cache = {};
  static const _cacheMaxSize = 20;

  AIDiagnosticService({
    required ApiService apiService,
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 2),
  })  : _apiService = apiService,
        _maxRetries = maxRetries,
        _retryDelay = retryDelay;

  Future<DiagnosticResult> diagnose(DiagnosticRequest request) async {
    final validationError = request.validate();
    if (validationError != null) {
      throw DiagnosticException(validationError);
    }

    final prompt = _buildPrompt(request);

    final cacheKey = _buildCacheKey(request, prompt);
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[AIDiagnostic] نتیجه از cache برگشت داده شد.');
      return _cache[cacheKey]!;
    }

    unawaited(_apiService.trackEvent(
      'diagnose_start',
      token: request.token,
      properties: {'carId': request.carId, 'type': request.inputType.name},
    ));

    final apiResult = await _sendWithRetry(
      token: request.token,
      carId: request.carId,
      prompt: prompt,
      year: request.year,
      carName: request.carName,
    );

    final result = DiagnosticResult(
      text: apiResult.result,
      prompt: prompt,
      timestamp: DateTime.now(),
      type: request.inputType,
      diagnosticId: apiResult.diagnosticId,
      remainingCredits: apiResult.remainingCredits,
      remainingFreeQuestions: apiResult.remainingFreeQuestions,
    );

    unawaited(_apiService.trackEvent(
      'diagnose_success',
      token: request.token,
      properties: {
        'carId': request.carId,
        'diagnosticId': apiResult.diagnosticId,
      },
    ));

    _saveToCache(cacheKey, result);

    return result;
  }

  Future<String> diagnoseSimple({
    required String token,
    required String carId,
    required String year,
    String? carName,
    String? userDescription,
    AudioFeatures? audioFeatures,
    List<DiagnosticCode>? obdCodes,
  }) async {
    final result = await diagnose(
      DiagnosticRequest(
        token: token,
        carId: carId,
        year: year,
        carName: carName,
        userDescription: userDescription,
        audioFeatures: audioFeatures,
        obdCodes: obdCodes,
      ),
    );
    return result.text;
  }

  Future<DiagnoseApiResult> _sendWithRetry({
    required String token,
    required String carId,
    required String prompt,
    required String year,
    String? carName,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt <= _maxRetries) {
      try {
        debugPrint('[AIDiagnostic] تلاش ${attempt + 1}/${_maxRetries + 1}');

        final response = await _apiService
            .diagnose(token, carId, prompt, year: year, carName: carName)
            .timeout(
              const Duration(seconds: 55),
              onTimeout: () => throw DiagnosticException(
                'زمان پاسخ سرور تمام شد. لطفاً دوباره تلاش کنید.',
              ),
            );

        return response;
      } on DiagnosticException {
        rethrow;
      } on ApiException catch (e) {
        if (e.statusCode == 402 || e.statusCode == 401) {
          rethrow;
        }
        lastError = e;
        debugPrint('[AIDiagnostic] خطای API (${e.statusCode}): ${e.message}');
        unawaited(_apiService.trackEvent(
          'diagnose_error',
          token: token,
          properties: {'status': e.statusCode, 'message': e.message},
        ));
      } catch (e) {
        lastError = e;
        debugPrint('[AIDiagnostic] خطای غیرمنتظره: $e');
      }

      attempt++;
      if (attempt <= _maxRetries) {
        await Future.delayed(_retryDelay);
      }
    }

    throw lastError ?? DiagnosticException('خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.');
  }

  String _buildPrompt(DiagnosticRequest req) {
    final buf = StringBuffer();

    // پرامپت سیستم روی سرور است؛ اینجا فقط شرح مشکل کاربر + داده صوتی
    if (req.userDescription != null && req.userDescription!.trim().isNotEmpty) {
      buf.writeln(req.userDescription!.trim());
      buf.writeln();
    }

    if (req.obdCodes != null && req.obdCodes!.isNotEmpty) {
      buf.writeln('کدهای خطای OBD-II:');
      for (final c in req.obdCodes!) {
        final sevLabel = c.severity != OBDSeverity.unknown ? ' [${c.severity.label}]' : '';
        buf.writeln('• ${c.code}$sevLabel: ${c.description}');
      }
      buf.writeln();
    }

    if (req.audioFeatures != null) {
      final af = req.audioFeatures!;
      buf.writeln('نتایج آنالیز صوتی موتور (ضبط با گوشی):');
      buf.writeln('• بلندی صدا (RMS): ${af.rms.toStringAsFixed(4)}');
      buf.writeln('• فرکانس غالب: ${af.dominantFrequency.toStringAsFixed(1)} Hz');
      buf.writeln('• مرکز طیف: ${af.spectralCentroid.toStringAsFixed(1)} Hz');
      buf.writeln('• نرخ عبور از صفر: ${af.zeroCrossingRate.toStringAsFixed(4)}');
      if (af.spectralRolloff > 0) {
        buf.writeln('• Spectral Rolloff: ${af.spectralRolloff.toStringAsFixed(1)} Hz');
      }
      buf.writeln('(مقادیر تقریبی — جایگزین دیاگ تخصصی نیستند)');
    }

    final text = buf.toString().trim();
    if (text.length < 10) {
      return 'مشکل خودرو را بررسی کن. اطلاعات محدود است؛ راهنمایی کلی بده.';
    }
    return text;
  }

  String _buildCacheKey(DiagnosticRequest req, String prompt) {
    return '${req.carId}_${req.year}_${prompt.hashCode}';
  }

  void _saveToCache(String key, DiagnosticResult result) {
    if (_cache.length >= _cacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  void clearCache() {
    _cache.clear();
  }

  int get cacheSize => _cache.length;
}

class DiagnosticException implements Exception {
  final String message;
  final Object? cause;

  const DiagnosticException(this.message, {this.cause});

  @override
  String toString() => 'DiagnosticException: $message';
}
