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
  final int fftSize;           // معمولاً 1024 یا 2048 (باید توانی از 2 باشد)
  final int hopLength;         // تعداد نمونه بین frameها
  final String windowType;     // 'hann', 'hamming', 'blackman'
  final bool normalize;        // نرمال‌سازی به -1 تا 1

  const AnalyzerConfig({
    this.sampleRate = 44100,
    this.fftSize = 2048,
    this.hopLength = 1024,
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
// ─ـ تحلیل‌کننده صدا ──
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

    // ✅ readAsBytes مستقیماً Uint8List برمی‌گرداند (جلوگیری از کپی حافظه)
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AnalyzerException('فایل صوتی خالی است.');
    }

    try {
      final samples = _bytesToSamples(bytes);
      if (samples.isEmpty) {
        throw AnalyzerException('نمونه‌های صوتی استخراج نشدند.');
      }

      // ── محاسبات ──
      final rms = _calculateRMS(samples);
      final zcrRate = _calculateZeroCrossingRate(samples);
      
      // محاسبه طیف فرکانسی برای فریم اصلی
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
  // ─ـ تبدیل Bytes به Samples ──
  // ─────────────────────────────────────────
  List<double> _bytesToSamples(Uint8List bytes) {
    if (bytes.length >= 2) {
      try {
        return _decodePCM16(bytes);
      } catch (_) {}
    }
    // fallback: normalize bytes مستقیم
    return bytes.map((b) => (b - 128) / 128.0).toList();
  }

  /// دیکد PCM 16-bit (کمون‌ترین فرمت)
  List<double> _decodePCM16(Uint8List bytes) {
    // ✅ استفاده مستقیم از buffer بدون کپی گرفتن
    final buffer = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    final samples = <double>[];

    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final sample = buffer.getInt16(i, Endian.little);
      samples.add(sample / 32768.0); // تبدیل به -1 تا 1
    }

    return samples;
  }

  // ─────────────────────────────────────────
  // ── محاسبات آماری ──
  // ─────────────────────────────────────────

  /// RMS (Root Mean Square) - قدرت سیگنال
  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final x in samples) {
      sumSquares += x * x;
    }
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

  // ─────────────────────────────────────────
  // ── پردازش طیف فرکانسی (FFT) ──
  // ─────────────────────────────────────────

  /// محاسبه طیف فرکانسی (Magnitude Spectrum)
  List<double> _calculateSpectrum(List<double> samples) {
    final windowed = _applyWindow(samples);
    final fftSize = config.fftSize;

    // آماده‌سازی آرایه‌های حقیقی و موهومی
    final real = List<double>.filled(fftSize, 0.0);
    final imag = List<double>.filled(fftSize, 0.0);
    
    for (int i = 0; i < math.min(fftSize, windowed.length); i++) {
      real[i] = windowed[i];
    }

    // ✅ اجرای الگوریتم صحیح FFT مبتنی بر اعداد مختلط
    _fft(real, imag);

    // محاسبه بزرگی (Magnitude) نیمی از طیف (به دلیل تقارن)
    final spectrum = List<double>.filled(fftSize ~/ 2, 0.0);
    for (int i = 0; i < fftSize ~/ 2; i++) {
      spectrum[i] = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }
    
    return spectrum;
  }

  /// اعمال Hann Window
  List<double> _applyWindow(List<double> samples) {
    final n = math.min(config.fftSize, samples.length);
    if (n <= 1) return samples.sublist(0, n);

    final window = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final windowValue = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
      window[i] = samples[i] * windowValue;
    }
    return window;
  }

  /// ✅ پیاده‌سازی صحیح FFT تکرارشونده (Iterative Cooley-Tukey)
  /// این الگوریتم از Stack Overflow جلوگیری می‌کند و دارای دقت ریاضی است.
  void _fft(List<double> real, List<double> imag) {
    final n = real.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        double tempR = real[i];
        real[i] = real[j];
        real[j] = tempR;
        
        double tempI = imag[i];
        imag[i] = imag[j];
        imag[j] = tempI;
      }
    }

    // Cooley-Tukey butterfly
    for (int len = 2; len <= n; len <<= 1) {
      double angle = -2 * math.pi / len;
      double wReal = math.cos(angle);
      double wImag = math.sin(angle);

      for (int i = 0; i < n; i += len) {
        double curReal = 1.0;
        double curImag = 0.0;

        for (int k = 0; k < len ~/ 2; k++) {
          double evenReal = real[i + k];
          double evenImag = imag[i + k];
          
          double oddReal = real[i + k + len ~/ 2] * curReal - imag[i + k + len ~/ 2] * curImag;
          double oddImag = real[i + k + len ~/ 2] * curImag + imag[i + k + len ~/ 2] * curReal;

          real[i + k] = evenReal + oddReal;
          imag[i + k] = evenImag + oddImag;
          
          real[i + k + len ~/ 2] = evenReal - oddReal;
          imag[i + k + len ~/ 2] = evenImag - oddImag;

          double nextReal = curReal * wReal - curImag * wImag;
          curImag = curReal * wImag + curImag * wReal;
          curReal = nextReal;
        }
      }
    }
  }

  /// فرکانس غالب
  double _findDominantFrequency(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double maxMagnitude = 0.0;
    int maxIndex = 0;
    for (int i = 0; i < spectrum.length; i++) {
      if (spectrum[i] > maxMagnitude) {
        maxMagnitude = spectrum[i];
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
      final magnitude = spectrum[i];
      weighted += i * magnitude;
      total += magnitude;
    }

    if (total == 0) return 0.0;
    return (weighted / total) * config.sampleRate / config.fftSize;
  }

  /// نقطه پایان طیف (Spectral Rolloff)
  double _calculateSpectralRolloff(List<double> spectrum, double threshold) {
    if (spectrum.isEmpty) return 0.0;

    double total = 0.0;
    for (final x in spectrum) {
      total += x;
    }
    
    if (total == 0) return 0.0;

    double accumulated = 0.0;
    for (int i = 0; i < spectrum.length; i++) {
      accumulated += spectrum[i];
      if (accumulated >= threshold * total) {
        return i * config.sampleRate / config.fftSize;
      }
    }

    return spectrum.length * config.sampleRate / config.fftSize;
  }

  /// نرخ تغییر طیف (Spectral Flux)
  double _calculateSpectralFlux(List<double> samples) {
    if (samples.length < config.hopLength * 2) return 0.0;

    List<double> prevSpectrum = [];
    double totalFlux = 0.0;
    int frameCount = 0;

    for (int i = 0; i < samples.length - config.fftSize; i += config.hopLength) {
      final frame = samples.sublist(i, math.min(i + config.fftSize, samples.length));
      final currSpectrum = _calculateSpectrum(frame);

      if (prevSpectrum.isNotEmpty) {
        double frameFlux = 0.0;
        for (int k = 0; k < currSpectrum.length; k++) {
          // فقط تغییرات مثبت (افزایش انرژی) محاسبه می‌شود
          final diff = currSpectrum[k] - prevSpectrum[k];
          if (diff > 0) {
            frameFlux += diff * diff;
          }
        }
        totalFlux += math.sqrt(frameFlux);
        frameCount++;
      }
      prevSpectrum = currSpectrum;
    }

    return frameCount > 0 ? totalFlux / frameCount : 0.0;
  }

  /// تخمین SNR (نسبت سیگنال به نویز)
  double _estimateSNR(List<double> samples) {
    if (samples.length < 2) return 0.0;

    final noiseLength = math.max(1, (samples.length * 0.2).toInt());
    final noiseSamples = samples.sublist(0, noiseLength);
    final signalSamples = samples.sublist(noiseLength);

    double noiseEnergy = 0.0;
    for (final x in noiseSamples) {
      noiseEnergy += x * x;
    }
    noiseEnergy /= noiseSamples.length;

    double signalEnergy = 0.0;
    for (final x in signalSamples) {
      signalEnergy += x * x;
    }
    signalEnergy /= signalSamples.length;

    if (noiseEnergy == 0) return 50.0;
    return 10 * math.log(signalEnergy / noiseEnergy) / math.log(10);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ خطای اختصاصی ──
// ─────────────────────────────────────────────────────────────────────────────
class AnalyzerException implements Exception {
  final String message;
  const AnalyzerException(this.message);

  @override
  String toString() => 'AnalyzerException: $message';
}
