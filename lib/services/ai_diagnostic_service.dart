import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/audio_features.dart';
import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── مدل کد OBD ──
// ─────────────────────────────────────────────────────────────────────────────
class DiagnosticCode {
  final String code;           // مثال: P0300
  final String description;    // توضیح کد
  final OBDSeverity severity;  // شدت خطا
  final String? system;        // سیستم مربوطه: موتور، گیربکس، ...

  const DiagnosticCode({
    required this.code,
    required this.description,
    this.severity = OBDSeverity.unknown,
    this.system,
  });

  factory DiagnosticCode.fromJson(Map<String, dynamic> json) {
    return DiagnosticCode(
      // ✅ استفاده از ?.toString() برای جلوگیری از کرش
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
  low,      // پایین
  medium,   // متوسط
  high,     // بالا
  critical, // بحرانی
  unknown;  // ناشناخته

  String get label => switch (this) {
        OBDSeverity.low => 'کم‌اهمیت',
        OBDSeverity.medium => 'متوسط',
        OBDSeverity.high => 'مهم',
        OBDSeverity.critical => 'بحرانی',
        OBDSeverity.unknown => 'نامشخص',
      };

  // ✅ استفاده از حلقه for برای ایمنی و پرفورمنس بهتر
  static OBDSeverity fromString(String? value) {
    if (value == null) return OBDSeverity.unknown;
    final lower = value.toLowerCase();
    for (final sev in OBDSeverity.values) {
      if (sev.name == lower) return sev;
    }
    return OBDSeverity.unknown;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── نتیجه عیب‌یابی ──
// ─────────────────────────────────────────────────────────────────────────────
class DiagnosticResult {
  final String text;              // متن پاسخ AI
  final String prompt;            // prompt ارسال‌شده (برای دیباگ)
  final DateTime timestamp;       // زمان دریافت پاسخ
  final DiagnosticInputType type; // نوع ورودی

  const DiagnosticResult({
    required this.text,
    required this.prompt,
    required this.timestamp,
    required this.type,
  });

  bool get isEmpty => text.trim().isEmpty;
}

enum DiagnosticInputType {
  textOnly,     // فقط متن
  audioOnly,    // فقط صدا
  obdOnly,      // فقط OBD
  combined;     // ترکیبی

  String get label => switch (this) {
        DiagnosticInputType.textOnly => 'متنی',
        DiagnosticInputType.audioOnly => 'صوتی',
        DiagnosticInputType.obdOnly => 'دیاگ OBD',
        DiagnosticInputType.combined => 'ترکیبی',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── پارامترهای عیب‌یابی ──
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// ── سرویس اصلی ──
// ─────────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────
  // ── عیب‌یابی اصلی ──
  // ─────────────────────────────────────────
  Future<DiagnosticResult> diagnose(DiagnosticRequest request) async {
    final validationError = request.validate();
    if (validationError != null) {
      throw DiagnosticException(validationError);
    }

    final prompt = _buildPrompt(request);

    // ✅ استفاده از خود متن Prompt به عنوان کلید (جلوگیری از Hash Collision)
    final cacheKey = _buildCacheKey(request, prompt);
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[AIDiagnostic] نتیجه از cache برگشت داده شد.');
      return _cache[cacheKey]!;
    }

    final responseText = await _sendWithRetry(
      token: request.token,
      carId: request.carId,
      prompt: prompt,
      year: request.year,
      carName: request.carName,
    );

    final result = DiagnosticResult(
      text: responseText,
      prompt: prompt,
      timestamp: DateTime.now(),
      type: request.inputType,
    );

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

  // ─────────────────────────────────────────
  // ── ارسال با retry ──
  // ─────────────────────────────────────────
  Future<String> _sendWithRetry({
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
              const Duration(seconds: 45),
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
      } catch (e) {
        lastError = e;
        debugPrint('[AIDiagnostic] خطای غیرمنتظره: $e');
      }

      attempt++;
      if (attempt <= _maxRetries) {
        debugPrint('[AIDiagnostic] ${_retryDelay.inSeconds} ثانیه صبر...');
        await Future.delayed(_retryDelay);
      }
    }

    throw lastError ?? DiagnosticException('خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.');
  }

  // ─────────────────────────────────────────
  // ── ساخت prompt ──
  // ─────────────────────────────────────────
  String _buildPrompt(DiagnosticRequest req) {
    final buf = StringBuffer();

    if (req.userDescription != null && req.userDescription!.trim().isNotEmpty) {
      buf.writeln('📋 شرح مشکل توسط راننده:');
      buf.writeln(req.userDescription!.trim());
      buf.writeln();
    }

    if (req.obdCodes != null && req.obdCodes!.isNotEmpty) {
      buf.writeln('🔌 کدهای خطای OBD-II استخراج‌شده از دستگاه دیاگ:');
      for (final c in req.obdCodes!) {
        final sevLabel = c.severity != OBDSeverity.unknown ? ' [${c.severity.label}]' : '';
        final sysLabel = c.system != null ? ' (سیستم: ${c.system})' : '';
        buf.writeln('  • ${c.code}$sevLabel$sysLabel: ${c.description}');
      }
      buf.writeln();
    }

    if (req.audioFeatures != null) {
      final af = req.audioFeatures!;
      buf.writeln('🎙️ نتایج آنالیز صوتی موتور (ضبط‌شده توسط میکروفون گوشی):');
      buf.writeln('  • بلندی صدا (RMS): ${af.rms.toStringAsFixed(4)} (${_rmsDescription(af.rms)})');
      buf.writeln('  • فرکانس غالب: ${af.dominantFrequency.toStringAsFixed(1)} Hz (${_freqDescription(af.dominantFrequency)})');
      buf.writeln('  • مرکز طیف: ${af.spectralCentroid.toStringAsFixed(1)} Hz');
      buf.writeln('  • نرخ عبور از صفر: ${af.zeroCrossingRate.toStringAsFixed(4)}');
      if (af.spectralRolloff > 0) {
        buf.writeln('  • Spectral Rolloff: ${af.spectralRolloff.toStringAsFixed(1)} Hz');
      }
      buf.writeln();
    }

    buf.writeln('─────────────────────────────');
    buf.writeln(
      'لطفاً با توجه به اطلاعات بالا، به‌صورت دقیق و حرفه‌ای در قالب زیر پاسخ بده:\n'
      '1. تشخیص احتمالی مشکل\n'
      '2. دلیل احتمالی\n'
      '3. راهکار پیشنهادی\n'
      '4. اورژانسی بودن (فوری / غیر فوری)\n\n'
      'پاسخ را به فارسی و ساده بنویس تا راننده بفهمد.',
    );

    return buf.toString().trim();
  }

  String _rmsDescription(double rms) {
    if (rms < 0.05) return 'خیلی آرام';
    if (rms < 0.15) return 'نرمال';
    if (rms < 0.30) return 'بلند';
    return 'بسیار بلند / ناهنجار';
  }

  String _freqDescription(double freq) {
    if (freq < 100) return 'ارتعاش پایین';
    if (freq < 500) return 'دور آرام موتور';
    if (freq < 2000) return 'دور معمول';
    if (freq < 5000) return 'دور بالا';
    return 'بسیار بالا / ناکوبی احتمالی';
  }

  // ─────────────────────────────────────────
  // ── cache ──
  // ─────────────────────────────────────────
  String _buildCacheKey(DiagnosticRequest req, String prompt) {
    // ✅ استفاده از خود Prompt به جای HashCode برای جلوگیری از تصادم
    return '${req.carId}_${req.year}_$prompt';
  }

  void _saveToCache(String key, DiagnosticResult result) {
    if (_cache.length >= _cacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  void clearCache() {
    _cache.clear();
    debugPrint('[AIDiagnostic] cache پاک شد.');
  }

  int get cacheSize => _cache.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// ── خطای اختصاصی ──
// ─────────────────────────────────────────────────────────────────────────────
class DiagnosticException implements Exception {
  final String message;
  final Object? cause;

  const DiagnosticException(this.message, {this.cause});

  @override
  String toString() => 'DiagnosticException: $message';
}
