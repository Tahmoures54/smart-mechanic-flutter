import 'dart:math';

/// ویژگی‌های استخراج‌شده از صدای موتور خودرو
class AudioFeatures {
  /// قدرت سیگنال (Root Mean Square)
  /// مقادیر معمول: 0.01 (خیلی آرام) تا 0.5+ (بسیار بلند/ناقوبی)
  final double rms;
  
  /// فرکانس غالب (دور موتور)
  /// واحد: هرتز (Hz)
  final double dominantFrequency;
  
  /// مرکز طیف (میانگین وزنی فرکانس‌ها)
  /// نشان‌دهنده «روشنایی» یا «تاریکی» صدا است
  final double spectralCentroid;
  
  /// نرخ فرکانس طیفی (Spectral Rolloff)
  /// فرکانسی که 85% یا 95% انرژی سیگنال زیر آن است
  final double spectralRolloff;
  
  /// نرخ عبور از صفر (Zero Crossing Rate)
  /// نشان‌دهنده میزان نویز یا ریزش صدا است
  final double zeroCrossingRate;
  
  /// طیف فرکانسی (برای رسم نمودار)
  /// ⚠️ هشدار: این لیست ممکن است بسیار بزرگ باشد (مثلاً 2048 نقطه)
  final List<double> frequencySpectrum;

  AudioFeatures({
    required this.rms,
    required this.dominantFrequency,
    required this.spectralCentroid,
    required this.spectralRolloff,
    required this.zeroCrossingRate,
    required this.frequencySpectrum,
  });

  // ─────────────────────────────────────────────
  // متدهای کمکی و تفسیر داده
  // ─────────────────────────────────────────────

  /// سطح صدای موتور بر اساس RMS
  EngineNoiseLevel get noiseLevel {
    if (rms < 0.05) return EngineNoiseLevel.quiet;
    if (rms < 0.15) return EngineNoiseLevel.normal;
    if (rms < 0.30) return EngineNoiseLevel.loud;
    return EngineNoiseLevel.critical;
  }

  /// تفسیر فرکانس غالب (دور موتور)
  String get frequencyInterpretation {
    if (dominantFrequency < 100) return 'بسیار پایین (ارتعاش)';
    if (dominantFrequency < 500) return 'پایین (دور آرام)';
    if (dominantFrequency < 2000) return 'متوسط (دور معمول)';
    if (dominantFrequency < 5000) return 'بالا (دور زیاد)';
    return 'بسیار بالا (ناکوبی احتمالی)';
  }

  /// کاهش حجم نقاط نمودار برای جلوگیری از Lag در UI
  /// [maxPoints] حداکثر نقاطی که برمی‌گرداند (پیش‌فرض 200)
  List<double> downsampleSpectrum({int maxPoints = 200}) {
    if (frequencySpectrum.length <= maxPoints) {
      return frequencySpectrum;
    }

    final step = frequencySpectrum.length / maxPoints;
    final downsampled = <double>[];
    
    for (var i = 0.0; i < frequencySpectrum.length; i += step) {
      downsampled.add(frequencySpectrum[i.round()]);
    }
    
    return downsampled;
  }

  // ─────────────────────────────────────────────
  // Serialization
  // ─────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'rms': rms,
        'dominant_frequency': dominantFrequency,
        'spectral_centroid': spectralCentroid,
        'spectral_rolloff': spectralRolloff,
        'zero_crossing_rate': zeroCrossingRate,
        'frequency_spectrum': frequencySpectrum,
      };

  /// ✅ اصلاح شده: جلوگیری از TypeError اگر API عدد صحیح بفرستد
  factory AudioFeatures.fromJson(Map<String, dynamic> json) {
    return AudioFeatures(
      rms: _toDouble(json['rms']),
      dominantFrequency: _toDouble(json['dominant_frequency']),
      spectralCentroid: _toDouble(json['spectral_centroid']),
      spectralRolloff: _toDouble(json['spectral_rolloff']),
      zeroCrossingRate: _toDouble(json['zero_crossing_rate']),
      frequencySpectrum: _toDoubleList(json['frequency_spectrum']),
    );
  }

  /// تبدیل ایمن num به double
  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return 0.0;
  }

  /// تبدیل ایمن List<dynamic> به List<double>
  /// (جلوگیری از خطای cast<double>() اگر لیست حاوی int باشد)
  static List<double> _toDoubleList(dynamic value) {
    if (value is List) {
      return value.map((e) => _toDouble(e)).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────
  // ابزارهای Dart
  // ─────────────────────────────────────────────

  /// کپی آبجکت با امکان تغییر فیلدهای خاص
  AudioFeatures copyWith({
    double? rms,
    double? dominantFrequency,
    double? spectralCentroid,
    double? spectralRolloff,
    double? zeroCrossingRate,
    List<double>? frequencySpectrum,
  }) {
    return AudioFeatures(
      rms: rms ?? this.rms,
      dominantFrequency: dominantFrequency ?? this.dominantFrequency,
      spectralCentroid: spectralCentroid ?? this.spectralCentroid,
      spectralRolloff: spectralRolloff ?? this.spectralRolloff,
      zeroCrossingRate: zeroCrossingRate ?? this.zeroCrossingRate,
      frequencySpectrum: frequencySpectrum ?? this.frequencySpectrum,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AudioFeatures) return false;
    // برای مقایسه لیست، از listEquals استفاده می‌کنیم
    return other.rms == rms &&
        other.dominantFrequency == dominantFrequency &&
        other.spectralCentroid == spectralCentroid &&
        other.spectralRolloff == spectralRolloff &&
        other.zeroCrossingRate == zeroCrossingRate &&
        _listEquals(other.frequencySpectrum, frequencySpectrum);
  }

  @override
  int get hashCode => Object.hash(
        rms,
        dominantFrequency,
        spectralCentroid,
        spectralRolloff,
        zeroCrossingRate,
        Object.hashAll(frequencySpectrum),
      );

  /// مقایسه دو لیست
  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'AudioFeatures(rms: ${rms.toStringAsFixed(3)}, '
        'dominantFreq: ${dominantFrequency.toStringAsFixed(1)}Hz, '
        'centroid: ${spectralCentroid.toStringAsFixed(1)}, '
        'rolloff: ${spectralRolloff.toStringAsFixed(1)}, '
        'zcr: ${zeroCrossingRate.toStringAsFixed(3)}, '
        'spectrumPoints: ${frequencySpectrum.length})';
  }
}

// ─────────────────────────────────────────────
// Enum برای سطح صدا
// ─────────────────────────────────────────────

enum EngineNoiseLevel {
  quiet,
  normal,
  loud,
  critical;

  String get label => switch (this) {
        EngineNoiseLevel.quiet => 'خیلی آرام',
        EngineNoiseLevel.normal => 'نرمال',
        EngineNoiseLevel.loud => 'بلند',
        EngineNoiseLevel.critical => 'بحرانی',
      };

  Color get color => switch (this) {
        EngineNoiseLevel.quiet => Colors.blueAccent,
        EngineNoiseLevel.normal => Colors.green,
        EngineNoiseLevel.loud => Colors.orange,
        EngineNoiseLevel.critical => Colors.redAccent,
      };

  IconData get icon => switch (this) {
        EngineNoiseLevel.quiet => Icons.volume_off_rounded,
        EngineNoiseLevel.normal => Icons.volume_down_rounded,
        EngineNoiseLevel.loud => Icons.volume_up_rounded,
        EngineNoiseLevel.critical => Icons.volume_up_rounded,
      };
}
