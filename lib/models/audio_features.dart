import 'package:flutter/material.dart';

/// ویژگی‌های استخراج‌شده از صدای موتور خودرو
class AudioFeatures {
  final double rms;
  final double dominantFrequency;
  final double spectralCentroid;
  final double spectralRolloff;
  final double zeroCrossingRate;
  final List<double> frequencySpectrum;

  final double spectralFlux;
  final double snr;
  final int sampleRate;
  final int durationMs;

  AudioFeatures({
    required this.rms,
    required this.dominantFrequency,
    required this.spectralCentroid,
    required this.spectralRolloff,
    required this.zeroCrossingRate,
    required this.frequencySpectrum,
    this.spectralFlux = 0.0,
    this.snr = 0.0,
    this.sampleRate = 44100,
    this.durationMs = 0,
  });

  // ─────────────────────────────────────────
  // متدهای کمکی
  // ─────────────────────────────────────────

  EngineNoiseLevel get noiseLevel {
    if (rms < 0.05) return EngineNoiseLevel.quiet;
    if (rms < 0.15) return EngineNoiseLevel.normal;
    if (rms < 0.30) return EngineNoiseLevel.loud;
    return EngineNoiseLevel.critical;
  }

  String get frequencyInterpretation {
    if (dominantFrequency < 100) return 'بسیار پایین (ارتعاش)';
    if (dominantFrequency < 500) return 'پایین (دور آرام)';
    if (dominantFrequency < 2000) return 'متوسط (دور معمول)';
    if (dominantFrequency < 5000) return 'بالا (دور زیاد)';
    return 'بسیار بالا (ناکوبی احتمالی)';
  }

  List<double> downsampleSpectrum({int maxPoints = 200}) {
    if (frequencySpectrum.length <= maxPoints) {
      return frequencySpectrum;
    }
    
    // ✅ الگوریتم بهتر برای Downsample (جلوگیری از تکرار اندیس‌ها)
    final downsampled = <double>[];
    final step = frequencySpectrum.length / maxPoints;
    double currentIndex = 0.0;
    
    while (currentIndex < frequencySpectrum.length) {
      downsampled.add(frequencySpectrum[currentIndex.round()]);
      currentIndex += step;
    }
    return downsampled;
  }

  // ─────────────────────────────────────────
  // Serialization
  // ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'rms': rms,
        'dominant_frequency': dominantFrequency,
        'spectral_centroid': spectralCentroid,
        'spectral_rolloff': spectralRolloff,
        'zero_crossing_rate': zeroCrossingRate,
        'frequency_spectrum': frequencySpectrum,
        'spectral_flux': spectralFlux,
        'snr': snr,
        'sample_rate': sampleRate,
        'duration_ms': durationMs,
      };

  factory AudioFeatures.fromJson(Map<String, dynamic> json) {
    return AudioFeatures(
      rms: _toDouble(json['rms']),
      dominantFrequency: _toDouble(json['dominant_frequency']),
      spectralCentroid: _toDouble(json['spectral_centroid']),
      spectralRolloff: _toDouble(json['spectral_rolloff']),
      zeroCrossingRate: _toDouble(json['zero_crossing_rate']),
      frequencySpectrum: _toDoubleList(json['frequency_spectrum']),
      spectralFlux: _toDouble(json['spectral_flux']),
      snr: _toDouble(json['snr']),
      sampleRate: (json['sample_rate'] as num?)?.toInt() ?? 44100,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return 0.0;
  }

  static List<double> _toDoubleList(dynamic value) {
    if (value is List) {
      return value.map((e) => _toDouble(e)).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────
  // copyWith / equals / toString
  // ─────────────────────────────────────────

  AudioFeatures copyWith({
    double? rms,
    double? dominantFrequency,
    double? spectralCentroid,
    double? spectralRolloff,
    double? zeroCrossingRate,
    List<double>? frequencySpectrum,
    double? spectralFlux,
    double? snr,
    int? sampleRate,
    int? durationMs,
  }) {
    return AudioFeatures(
      rms: rms ?? this.rms,
      dominantFrequency: dominantFrequency ?? this.dominantFrequency,
      spectralCentroid: spectralCentroid ?? this.spectralCentroid,
      spectralRolloff: spectralRolloff ?? this.spectralRolloff,
      zeroCrossingRate: zeroCrossingRate ?? this.zeroCrossingRate,
      frequencySpectrum: frequencySpectrum ?? this.frequencySpectrum,
      spectralFlux: spectralFlux ?? this.spectralFlux,
      snr: snr ?? this.snr,
      sampleRate: sampleRate ?? this.sampleRate,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AudioFeatures) return false;
    
    // ✅ استفاده از حد آستانه برای مقایسه اعداد اعشاری (جلوگیری از باگ‌های دقیق)
    const epsilon = 1e-10;
    bool doubleEq(double a, double b) => (a - b).abs() < epsilon;

    return doubleEq(other.rms, rms) &&
        doubleEq(other.dominantFrequency, dominantFrequency) &&
        doubleEq(other.spectralCentroid, spectralCentroid) &&
        doubleEq(other.spectralRolloff, spectralRolloff) &&
        doubleEq(other.zeroCrossingRate, zeroCrossingRate) &&
        doubleEq(other.spectralFlux, spectralFlux) && // ✅ اضافه شد
        doubleEq(other.snr, snr) &&                   // ✅ اضافه شد
        other.sampleRate == sampleRate &&             // ✅ اضافه شد
        other.durationMs == durationMs &&             // ✅ اضافه شد
        _listEquals(other.frequencySpectrum, frequencySpectrum);
  }

  @override
  int get hashCode => Object.hash(
        rms,
        dominantFrequency,
        spectralCentroid,
        spectralRolloff,
        zeroCrossingRate,
        spectralFlux, // ✅ اضافه شد
        snr,          // ✅ اضافه شد
        sampleRate,   // ✅ اضافه شد
        durationMs,   // ✅ اضافه شد
        Object.hashAll(frequencySpectrum),
      );

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    // ✅ مقایسه لیست‌های اعشاری نیز با حد آستانه
    const epsilon = 1e-10;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > epsilon) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'AudioFeatures(rms: ${rms.toStringAsFixed(3)}, '
        'dominantFreq: ${dominantFrequency.toStringAsFixed(1)}Hz, '
        'snr: ${snr.toStringAsFixed(1)}dB, '
        'spectrumPoints: ${frequencySpectrum.length})';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum سطح صدا
// ─────────────────────────────────────────────────────────────────────────────

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
