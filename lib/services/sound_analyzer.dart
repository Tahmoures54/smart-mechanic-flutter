import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/audio_features.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── تنظیمات تحلیل ──
// ─────────────────────────────────────────────────────────────────────────────
class AnalyzerConfig {
  final int sampleRate;        // Hz
  final int fftSize;           // معمولاً 1024 یا 2048
  final int hopLength;         // تعداد نمونه بین frameها
  final String windowType;     // 'hann', 'hamming', 'blackman'
  final bool normalize;        // نرمال‌سازی به -1 تا 1

  const AnalyzerConfig({
    this.sampleRate = 44100,
    this.fftSize = 1024,
    this.hopLength = 512,
    this.windowType = 'hann',
    this.normalize = true,
  });

  static const engine = AnalyzerConfig(
    sampleRate: 44100,
    fftSize: 2048,
    hopLength: 1024,
    windowType: 'hann',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── تحلیل‌کننده صدا ──
// ─────────────────────────────────────────────────────────────────────────────
class SoundAnalyzer {
  final AnalyzerConfig config;

  SoundAnalyzer({AnalyzerConfig? config})
      : config = config ?? const AnalyzerConfig();

  // ─────────────────────────────────────────
  // ── تحلیل فایل صوتی ──
  // ─────────────────────────────────────────
  Future<AudioFeatures> analyze(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw AnalyzerException('فایل صوتی یافت نشد: $filePath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AnalyzerException('فایل صوتی خالی است.');
    }

    try {
      // ── تبدیل bytes به نمونه‌های صوتی ──
      final samples = _bytesToSamples(bytes);
      if (samples.isEmpty) {
        throw AnalyzerException('نمونه‌ های صوتی استخراج نشدند.');
      }

      // ── محاسبات ──
      final rms = _calculateRMS(samples);
      final zcrRate = _calculateZeroCrossingRate(samples);
      final spectrum = _calculateSpectrum(samples);
      final dominantFreq = _findDominantFrequency(spectrum);
      final spectralCentroid = _calculateSpectralCentroid(spectrum);
      final spectralRolloff = _calculateSpectralRolloff(spectrum, 0.95);
      final spectralFlux = _calculateSpectralFlux(samples);
      final snr = _estimateSNR(samples);

      return AudioFeatures(
        rms: rms,
        dominantFrequency: dominantFreq,
        spectralCentroid: spectralCentroid,
        spectralRolloff: spectralRolloff,
        zeroCrossingRate: zcrRate,
        frequencySpectrum: spectrum,
        spectralFlux: spectralFlux,
        snr: snr,
        sampleRate: config.sampleRate,
        durationMs: (samples.length / config.sampleRate * 1000).toInt(),
      );
    } catch (e) {
      if (e is AnalyzerException) rethrow;
      throw AnalyzerException('خطا در تحلیل صدا: $e');
    }
  }

  // ─────────────────────────────────────────
  // ── تبدیل Bytes به Samples ──
  // ─────────────────────────────────────────
  List<double> _bytesToSamples(List<int> bytes) {
    // ── سعی کن PCM 16-bit برای دریافت کن ──
    if (bytes.length >= 2) {
      try {
        return _decodePCM16(bytes);
      } catch (_) {}
    }

    // ── fallback: normalize bytes مستقیم ──
    return bytes.map((b) => (b - 128) / 128.0).toList();
  }

  /// دیکد PCM 16-bit (کمون‌ترین فرمت)
  List<double> _decodePCM16(List<int> bytes) {
    final buffer = ByteData.view(Uint8List.fromList(bytes).buffer);
    final samples = <double>[];

    for (int i = 0; i < bytes.length - 1; i += 2) {
      try {
        final sample = buffer.getInt16(i, Endian.little);
        samples.add(sample / 32768.0); // تبدیل به -1 تا 1
      } catch (_) {
        break;
      }
    }

    return samples;
  }

  // ─────────────────────────────────────────
  // ── محاسبات ──
  // ─────────────────────────────────────────

  /// RMS (Root Mean Square) - قدرت سیگنال
  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    final sumSquares = samples.fold(0.0, (s, x) => s + x * x);
    return math.sqrt(sumSquares / samples.length);
  }

  /// نرخ عبور از صفر
  double _calculateZeroCrossingRate(List<double> samples) {
    if (samples.length < 2) return 0.0;
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0 && samples[i - 1] < 0) ||
          (samples[i] < 0 && samples[i - 1] >= 0)) {
        crossings++;
      }
    }
    return crossings / (samples.length - 1);
  }

  /// محاسبه طیف فرکانسی (FFT ساده)
  List<double> _calculateSpectrum(List<double> samples) {
    // ── windowing (Hann) ──
    final windowed = _applyWindow(samples);

    // ── FFT سریع ──
    final fftSize = config.fftSize;
    final padded = List<double>.filled(fftSize, 0.0);
    for (int i = 0; i < math.min(fftSize, windowed.length); i++) {
      padded[i] = windowed[i];
    }

    // ── FFT ساده (Cooley-Tukey) ──
    final spectrum = _computeFFT(padded);
    return spectrum.sublist(0, math.min(512, spectrum.length));
  }

  /// اعمال Hann Window
  List<double> _applyWindow(List<double> samples) {
    final window = <double>[];
    final n = math.min(config.fftSize, samples.length);

    for (int i = 0; i < n; i++) {
      final windowValue = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
      window.add((i < samples.length ? samples[i] : 0.0) * windowValue);
    }

    return window;
  }

  /// FFT ساده (Cooley-Tukey)
  List<double> _computeFFT(List<double> input) {
    final n = input.length;
    if (n <= 1) return input;

    // ── FFT recursive ──
    final even = _computeFFT([
      for (int i = 0; i < n; i += 2)
        if (i < n) input[i]
    ]);
    final odd = _computeFFT([
      for (int i = 1; i < n; i += 2)
        if (i < n) input[i]
    ]);

    final result = List<double>.filled(n, 0.0);
    for (int k = 0; k < n ~/ 2; k++) {
      final twiddle = 2 * math.pi * k / n;
      final real = math.cos(twiddle);
      final imag = -math.sin(twiddle);
      final oddReal = odd[k];
      final oddImag = 0.0;

      result[k] = even[k] + oddReal * real;
      result[k + n ~/ 2] = even[k] - oddReal * real;
    }

    return result;
  }

  /// فرکانس غالب
  double _findDominantFrequency(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double maxMagnitude = 0.0;
    int maxIndex = 0;
    for (int i = 0; i < spectrum.length; i++) {
      final magnitude = spectrum[i].abs();
      if (magnitude > maxMagnitude) {
        maxMagnitude = magnitude;
        maxIndex = i;
      }
    }

    return maxIndex * config.sampleRate / config.fftSize;
  }

  /// مرکز طیف
  double _calculateSpectralCentroid(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double weighted = 0.0;
    double total = 0.0;

    for (int i = 0; i < spectrum.length; i++) {
      final magnitude = spectrum[i].abs();
      weighted += i * magnitude;
      total += magnitude;
    }

    if (total == 0) return 0.0;
    return (weighted / total) * config.sampleRate / config.fftSize;
  }

  /// نقطه پایان طیف (Spectral Rolloff)
  double _calculateSpectralRolloff(List<double> spectrum, double threshold) {
    if (spectrum.isEmpty) return 0.0;

    final total = spectrum.fold(0.0, (s, x) => s + x.abs());
    if (total == 0) return 0.0;

    double accumulated = 0.0;
    for (int i = 0; i < spectrum.length; i++) {
      accumulated += spectrum[i].abs();
      if (accumulated >= threshold * total) {
        return i * config.sampleRate / config.fftSize;
      }
    }

    return spectrum.length * config.sampleRate / config.fftSize;
  }

  /// نرخ تغییر طیف (Spectral Flux)
  double _calculateSpectralFlux(List<double> samples) {
    if (samples.length < config.hopLength * 2) return 0.0;

    final frames = <List<double>>[];
    for (int i = 0; i < samples.length - config.hopLength;
        i += config.hopLength) {
      final frame =
          samples.sublist(i, math.min(i + config.fftSize, samples.length));
      frames.add(_calculateSpectrum(frame));
    }

    if (frames.length < 2) return 0.0;

    double totalFlux = 0.0;
    for (int i = 1; i < frames.length; i++) {
      for (int k = 0; k < frames[i].length; k++) {
        final diff =
            (frames[i][k] - frames[i - 1][k]).abs();
        totalFlux += diff * diff;
      }
    }

    return math.sqrt(totalFlux / (frames.length - 1));
  }

  /// تخمین SNR (نسبت سیگنال به نویز)
  double _estimateSNR(List<double> samples) {
    if (samples.length < 2) return 0.0;

    // ── فرض: 20٪ نمونه اول نویز است ──
    final noiseLength = math.max(1, (samples.length * 0.2).toInt());
    final noiseSamples = samples.sublist(0, noiseLength);
    final signalSamples = samples.sublist(noiseLength);

    final noiseEnergy =
        noiseSamples.fold(0.0, (s, x) => s + x * x) / noiseSamples.length;
    final signalEnergy =
        signalSamples.fold(0.0, (s, x) => s + x * x) / signalSamples.length;

    if (noiseEnergy == 0) return 50.0;
    return 10 * math.log(signalEnergy / noiseEnergy) / math.log(10);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── خطای اختصاصی ──
// ─────────────────────────────────────────────────────────────────────────────
class AnalyzerException implements Exception {
  final String message;

  const AnalyzerException(this.message);

  @override
  String toString() => 'AnalyzerException: $message';
}
