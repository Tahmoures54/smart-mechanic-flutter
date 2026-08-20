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
///
/// توجه مهم:
/// این کلاس برای فایل‌های خام PCM / WAV طراحی شده است.
/// فایل‌های AAC/M4A که توسط flutter_sound ضبط می‌شوند،
/// به صورت کامل دیکد نمی‌شوند و نتایج تقریبی خواهند بود.
/// برای دقت بالاتر در نسخه‌های بعدی از ffmpeg_kit_flutter یا
/// تغییر کدک ضبط به PCM/WAV استفاده شود.
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

    // هشدار در مورد فرمت فشرده
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.aac') ||
        lowerPath.endsWith('.m4a') ||
        lowerPath.endsWith('.mp3')) {
      debugPrint(
        '[SoundAnalyzer] هشدار: فایل فشرده ($filePath). '
        'نتایج تقریبی خواهند بود. بهتر است از WAV/PCM استفاده شود.',
      );
    }

    try {
      final samples = _bytesToSamples(bytes);
      if (samples.isEmpty) {
        throw AnalyzerException('نمونه‌های صوتی استخراج نشدند.');
      }

      // محدود کردن طول نمونه‌ها برای جلوگیری از مصرف بیش از حد حافظه
      final maxSamples = config.sampleRate * 30; // حداکثر ۳۰ ثانیه
      final limitedSamples = samples.length > maxSamples
          ? samples.sublist(0, maxSamples)
          : samples;

      final rms = _calculateRMS(limitedSamples);
      final zcrRate = _calculateZeroCrossingRate(limitedSamples);

      final spectrum = _calculateSpectrum(limitedSamples);

      final dominantFreq = _findDominantFrequency(spectrum);
      final spectralCentroid = _calculateSpectralCentroid(spectrum);
      final spectralRolloff = _calculateSpectralRolloff(spectrum, 0.95);
      final spectralFlux = _calculateSpectralFlux(limitedSamples);
      final snr = _estimateSNR(limitedSamples);

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
        durationMs: (limitedSamples.length / config.sampleRate * 1000).toInt(),
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
    // تلاش برای تشخیص هدر WAV
    if (bytes.length > 44 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46) { // F
      try {
        return _decodeWav(bytes);
      } catch (_) {}
    }

    // تلاش برای PCM16 خام
    if (bytes.length >= 2) {
      try {
        return _decodePCM16(bytes);
      } catch (_) {}
    }

    // fallback: normalize bytes مستقیم (تقریبی برای AAC)
    return bytes.map((b) => (b - 128) / 128.0).toList();
  }

  List<double> _decodeWav(Uint8List bytes) {
    // رد کردن ۴۴ بایت هدر استاندارد WAV
    final dataOffset = 44;
    if (bytes.length <= dataOffset) return [];

    final buffer = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes + dataOffset,
      bytes.length - dataOffset,
    );

    final samples = <double>[];
    for (int i = 0; i + 1 < buffer.lengthInBytes; i += 2) {
      final sample = buffer.getInt16(i, Endian.little);
      samples.add(sample / 32768.0);
    }
    return samples;
  }

  List<double> _decodePCM16(Uint8List bytes) {
    final buffer = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    final samples = <double>[];

    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final sample = buffer.getInt16(i, Endian.little);
      samples.add(sample / 32768.0);
    }

    return samples;
  }

  // ─────────────────────────────────────────
  // ── محاسبات آماری ──
  // ─────────────────────────────────────────

  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final x in samples) {
      sumSquares += x * x;
    }
    return math.sqrt(sumSquares / samples.length);
  }

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

  List<double> _calculateSpectrum(List<double> samples) {
    final windowed = _applyWindow(samples);
    final fftSize = config.fftSize;

    final real = List<double>.filled(fftSize, 0.0);
    final imag = List<double>.filled(fftSize, 0.0);

    for (int i = 0; i < math.min(fftSize, windowed.length); i++) {
      real[i] = windowed[i];
    }

    _fft(real, imag);

    final spectrum = List<double>.filled(fftSize ~/ 2, 0.0);
    for (int i = 0; i < fftSize ~/ 2; i++) {
      spectrum[i] = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }

    return spectrum;
  }

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

  /// پیاده‌سازی Iterative Cooley-Tukey FFT
  void _fft(List<double> real, List<double> imag) {
    final n = real.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tempR = real[i];
        real[i] = real[j];
        real[j] = tempR;

        final tempI = imag[i];
        imag[i] = imag[j];
        imag[j] = tempI;
      }
    }

    // Cooley-Tukey butterfly
    for (int len = 2; len <= n; len <<= 1) {
      final angle = -2 * math.pi / len;
      final wReal = math.cos(angle);
      final wImag = math.sin(angle);

      for (int i = 0; i < n; i += len) {
        double curReal = 1.0;
        double curImag = 0.0;

        for (int k = 0; k < len ~/ 2; k++) {
          final evenReal = real[i + k];
          final evenImag = imag[i + k];

          final oddReal = real[i + k + len ~/ 2] * curReal -
              imag[i + k + len ~/ 2] * curImag;
          final oddImag = real[i + k + len ~/ 2] * curImag +
              imag[i + k + len ~/ 2] * curReal;

          real[i + k] = evenReal + oddReal;
          imag[i + k] = evenImag + oddImag;

          real[i + k + len ~/ 2] = evenReal - oddReal;
          imag[i + k + len ~/ 2] = evenImag - oddImag;

          final nextReal = curReal * wReal - curImag * wImag;
          curImag = curReal * wImag + curImag * wReal;
          curReal = nextReal;
        }
      }
    }
  }

  double _findDominantFrequency(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double maxMagnitude = 0.0;
    int maxIndex = 0;
    // نادیده گرفتن باین‌های خیلی پایین (DC و نویز بسیار پایین)
    final startBin = math.max(1, (50 * config.fftSize / config.sampleRate).round());

    for (int i = startBin; i < spectrum.length; i++) {
      if (spectrum[i] > maxMagnitude) {
        maxMagnitude = spectrum[i];
        maxIndex = i;
      }
    }

    return maxIndex * config.sampleRate / config.fftSize;
  }

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

  double _estimateSNR(List<double> samples) {
    if (samples.length < 2) return 0.0;

    final noiseLength = math.max(1, (samples.length * 0.15).toInt());
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

    if (noiseEnergy <= 1e-12) return 50.0;
    return 10 * math.log(signalEnergy / noiseEnergy) / math.ln10;
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
