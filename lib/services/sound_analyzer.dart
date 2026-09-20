import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/audio_features.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── تنظیمات تحلیل ──
// ─────────────────────────────────────────────────────────────────────────────
class AnalyzerConfig {
  final int sampleRate; // Hz
  final int fftSize; // معمولاً 1024 یا 2048 (باید توانی از 2 باشد)
  final int hopLength; // تعداد نمونه بین frameها
  final String windowType; // 'hann', 'hamming', 'blackman'
  final bool normalize; // نرمال‌سازی به -1 تا 1

  /// حداکثر مدت نمونه‌برداری برای تحلیل (ثانیه) — بقیه نادیده گرفته می‌شود
  final int maxAnalysisSeconds;

  /// حداکثر تعداد فریم برای spectral flux (جلوگیری از قفل شدن CPU)
  final int maxFluxFrames;

  const AnalyzerConfig({
    this.sampleRate = 44100,
    this.fftSize = 2048,
    this.hopLength = 1024,
    this.windowType = 'hann',
    this.normalize = true,
    this.maxAnalysisSeconds = 8,
    this.maxFluxFrames = 24,
  });

  static const engine = AnalyzerConfig(
    sampleRate: 44100,
    fftSize: 2048,
    hopLength: 1024,
    windowType: 'hann',
    maxAnalysisSeconds: 8,
    maxFluxFrames: 24,
  );

  Map<String, dynamic> toMap() => {
        'sampleRate': sampleRate,
        'fftSize': fftSize,
        'hopLength': hopLength,
        'windowType': windowType,
        'normalize': normalize,
        'maxAnalysisSeconds': maxAnalysisSeconds,
        'maxFluxFrames': maxFluxFrames,
      };

  factory AnalyzerConfig.fromMap(Map<String, dynamic> m) => AnalyzerConfig(
        sampleRate: m['sampleRate'] as int? ?? 44100,
        fftSize: m['fftSize'] as int? ?? 2048,
        hopLength: m['hopLength'] as int? ?? 1024,
        windowType: m['windowType'] as String? ?? 'hann',
        normalize: m['normalize'] as bool? ?? true,
        maxAnalysisSeconds: m['maxAnalysisSeconds'] as int? ?? 8,
        maxFluxFrames: m['maxFluxFrames'] as int? ?? 24,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── تحلیل‌کننده صدا ──
// ─────────────────────────────────────────────────────────────────────────────
///
/// توجه مهم:
/// این کلاس برای فایل‌های خام PCM / WAV طراحی شده است.
/// فایل‌های AAC/M4A که توسط flutter_sound ضبط می‌شوند،
/// به صورت کامل دیکد نمی‌شوند و نتایج تقریبی خواهند بود.
///
/// پردازش سنگین (FFT و …) روی isolate پس‌زمینه با [compute] اجرا می‌شود
/// تا UI jank نداشته باشد.
class SoundAnalyzer {
  final AnalyzerConfig config;

  SoundAnalyzer({AnalyzerConfig? config})
      : config = config ?? const AnalyzerConfig();

  /// تحلیل فایل صوتی — I/O روی isolate اصلی، محاسبات روی background isolate.
  Future<AudioFeatures> analyze(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw AnalyzerException('فایل صوتی یافت نشد: $filePath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AnalyzerException('فایل صوتی خالی است.');
    }

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
      // فقط انواع sendable (Map / Uint8List) به isolate فرستاده می‌شود.
      final map = await compute<_AnalyzeArgs, Map<String, dynamic>>(
        _analyzeInIsolate,
        (
          bytes: bytes,
          configMap: config.toMap(),
        ),
      );

      if (map.containsKey('error')) {
        throw AnalyzerException(map['error'] as String);
      }
      return AudioFeatures.fromJson(map);
    } on AnalyzerException {
      rethrow;
    } catch (e) {
      throw AnalyzerException('خطا در تحلیل صدا: $e');
    }
  }
}

/// آرگومان compute — record ساده و sendable
typedef _AnalyzeArgs = ({Uint8List bytes, Map<String, dynamic> configMap});

/// Entry point سطح بالا برای [compute] — نباید به instance وابسته باشد.
Map<String, dynamic> _analyzeInIsolate(_AnalyzeArgs args) {
  try {
    final config = AnalyzerConfig.fromMap(args.configMap);
    final engine = _SoundEngine(config);

    final samples = engine.bytesToSamples(args.bytes);
    if (samples.isEmpty) {
      return {'error': 'نمونه‌های صوتی استخراج نشدند.'};
    }

    // پنجره تحلیل: حداکثر N ثانیه از وسط ضبط (نه فقط ابتدای فایل)
    final maxSamples = config.sampleRate * config.maxAnalysisSeconds;
    final List<double> limitedSamples;
    if (samples.length <= maxSamples) {
      limitedSamples = samples;
    } else {
      final start = ((samples.length - maxSamples) / 2).floor();
      limitedSamples = samples.sublist(start, start + maxSamples);
    }

    final rms = engine.calculateRMS(limitedSamples);
    final zcrRate = engine.calculateZeroCrossingRate(limitedSamples);
    final spectrum = engine.calculateSpectrum(limitedSamples);
    final dominantFreq = engine.findDominantFrequency(spectrum);
    final spectralCentroid = engine.calculateSpectralCentroid(spectrum);
    final spectralRolloff = engine.calculateSpectralRolloff(spectrum, 0.95);
    final spectralFlux = engine.calculateSpectralFlux(limitedSamples);
    final snr = engine.estimateSNR(limitedSamples);

    // spectrum را downsample می‌کنیم تا انتقال بین isolate سبک بماند
    final spectrumOut = spectrum.length > 256
        ? _downsampleList(spectrum, 256)
        : spectrum;

    return {
      'rms': rms,
      'dominant_frequency': dominantFreq,
      'spectral_centroid': spectralCentroid,
      'spectral_rolloff': spectralRolloff,
      'zero_crossing_rate': zcrRate,
      'frequency_spectrum': spectrumOut,
      'spectral_flux': spectralFlux,
      'snr': snr,
      'sample_rate': config.sampleRate,
      'duration_ms':
          (limitedSamples.length / config.sampleRate * 1000).toInt(),
    };
  } catch (e) {
    return {'error': e.toString()};
  }
}

List<double> _downsampleList(List<double> src, int maxPoints) {
  if (src.length <= maxPoints) return src;
  final out = <double>[];
  final step = src.length / maxPoints;
  double i = 0;
  while (i < src.length && out.length < maxPoints) {
    out.add(src[i.round().clamp(0, src.length - 1)]);
    i += step;
  }
  return out;
}

/// موتور محاسبات خالص — بدون وابستگی به Flutter UI
class _SoundEngine {
  final AnalyzerConfig config;

  // بافرهای قابل استفاده مجدد برای FFT تا GC کمتر شود
  late final List<double> _real;
  late final List<double> _imag;
  late final List<double> _windowCoeffs;

  _SoundEngine(this.config) {
    final n = config.fftSize;
    _real = List<double>.filled(n, 0.0);
    _imag = List<double>.filled(n, 0.0);
    _windowCoeffs = List<double>.generate(n, (i) {
      if (n <= 1) return 1.0;
      return 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1))); // Hann
    });
  }

  List<double> bytesToSamples(Uint8List bytes) {
    if (bytes.length > 44 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      try {
        return _decodeWav(bytes);
      } catch (_) {}
    }

    if (bytes.length >= 2) {
      try {
        return _decodePCM16(bytes);
      } catch (_) {}
    }

    // fallback تقریبی برای AAC و مشابه
    return List<double>.generate(
      bytes.length,
      (i) => (bytes[i] - 128) / 128.0,
      growable: false,
    );
  }

  List<double> _decodeWav(Uint8List bytes) {
    // پیدا کردن chunk "data" به‌جای فرض offset ثابت ۴۴
    var dataOffset = 44;
    var dataSize = bytes.length - 44;
    if (bytes.length > 44) {
      var offset = 12;
      while (offset + 8 < bytes.length) {
        final id0 = bytes[offset];
        final id1 = bytes[offset + 1];
        final id2 = bytes[offset + 2];
        final id3 = bytes[offset + 3];
        final size =
            ByteData.view(bytes.buffer, bytes.offsetInBytes + offset + 4, 4)
                .getUint32(0, Endian.little);
        if (id0 == 0x64 && id1 == 0x61 && id2 == 0x74 && id3 == 0x61) {
          // "data"
          dataOffset = offset + 8;
          dataSize = size;
          break;
        }
        offset += 8 + size;
        if (size.isOdd) offset++; // word alignment
      }
    }

    if (dataOffset >= bytes.length) return const [];
    final end = math.min(bytes.length, dataOffset + dataSize);
    final sampleCount = (end - dataOffset) ~/ 2;
    if (sampleCount <= 0) return const [];

    final buffer = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes + dataOffset,
      end - dataOffset,
    );
    final samples = List<double>.filled(sampleCount, 0.0);
    for (int i = 0; i < sampleCount; i++) {
      samples[i] = buffer.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  List<double> _decodePCM16(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount <= 0) return const [];
    final buffer =
        ByteData.view(bytes.buffer, bytes.offsetInBytes, sampleCount * 2);
    final samples = List<double>.filled(sampleCount, 0.0);
    for (int i = 0; i < sampleCount; i++) {
      samples[i] = buffer.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  double calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final x in samples) {
      sumSquares += x * x;
    }
    return math.sqrt(sumSquares / samples.length);
  }

  double calculateZeroCrossingRate(List<double> samples) {
    if (samples.length < 2) return 0.0;
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0) != (samples[i - 1] >= 0)) {
        crossings++;
      }
    }
    return crossings / (samples.length - 1);
  }

  /// طیف یک فریم (با استفاده از بافرهای مشترک)
  List<double> calculateSpectrum(List<double> samples) {
    final fftSize = config.fftSize;
    final n = math.min(fftSize, samples.length);

    for (int i = 0; i < fftSize; i++) {
      _real[i] = 0.0;
      _imag[i] = 0.0;
    }
    for (int i = 0; i < n; i++) {
      _real[i] = samples[i] * _windowCoeffs[i];
    }

    _fft(_real, _imag);

    final half = fftSize ~/ 2;
    final spectrum = List<double>.filled(half, 0.0);
    for (int i = 0; i < half; i++) {
      spectrum[i] = math.sqrt(_real[i] * _real[i] + _imag[i] * _imag[i]);
    }
    return spectrum;
  }

  /// نسخه in-place برای flux تا تخصیص کمتر شود
  void _spectrumInto(List<double> samples, int offset, List<double> out) {
    final fftSize = config.fftSize;
    final available = samples.length - offset;
    final n = math.min(fftSize, available);

    for (int i = 0; i < fftSize; i++) {
      _real[i] = 0.0;
      _imag[i] = 0.0;
    }
    for (int i = 0; i < n; i++) {
      _real[i] = samples[offset + i] * _windowCoeffs[i];
    }

    _fft(_real, _imag);

    final half = fftSize ~/ 2;
    for (int i = 0; i < half; i++) {
      out[i] = math.sqrt(_real[i] * _real[i] + _imag[i] * _imag[i]);
    }
  }

  void _fft(List<double> real, List<double> imag) {
    final n = real.length;
    if (n <= 1) return;

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

  double findDominantFrequency(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double maxMagnitude = 0.0;
    int maxIndex = 0;
    final startBin =
        math.max(1, (50 * config.fftSize / config.sampleRate).round());

    for (int i = startBin; i < spectrum.length; i++) {
      if (spectrum[i] > maxMagnitude) {
        maxMagnitude = spectrum[i];
        maxIndex = i;
      }
    }

    return maxIndex * config.sampleRate / config.fftSize;
  }

  double calculateSpectralCentroid(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double weighted = 0.0;
    double total = 0.0;
    for (int i = 0; i < spectrum.length; i++) {
      weighted += i * spectrum[i];
      total += spectrum[i];
    }
    if (total == 0) return 0.0;
    return (weighted / total) * config.sampleRate / config.fftSize;
  }

  double calculateSpectralRolloff(List<double> spectrum, double threshold) {
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

  /// Spectral flux با سقف فریم و بدون sublist مکرر
  double calculateSpectralFlux(List<double> samples) {
    if (samples.length < config.hopLength * 2) return 0.0;

    final half = config.fftSize ~/ 2;
    final prev = List<double>.filled(half, 0.0);
    final curr = List<double>.filled(half, 0.0);

    final maxStart = samples.length - config.fftSize;
    if (maxStart <= 0) return 0.0;

    final totalPossible =
        (maxStart / config.hopLength).floor().clamp(1, 100000);
    final frameCount = math.min(config.maxFluxFrames, totalPossible);
    final step = totalPossible <= 1
        ? config.hopLength
        : math.max(
            config.hopLength,
            (maxStart / frameCount).floor(),
          );

    double totalFlux = 0.0;
    int counted = 0;
    var hasPrev = false;

    for (int start = 0; start <= maxStart; start += step) {
      _spectrumInto(samples, start, curr);

      if (hasPrev) {
        double frameFlux = 0.0;
        for (int k = 0; k < half; k++) {
          final diff = curr[k] - prev[k];
          if (diff > 0) frameFlux += diff * diff;
        }
        totalFlux += math.sqrt(frameFlux);
        counted++;
      }

      for (int k = 0; k < half; k++) {
        prev[k] = curr[k];
      }
      hasPrev = true;

      if (counted >= config.maxFluxFrames) break;
    }

    return counted > 0 ? totalFlux / counted : 0.0;
  }

  double estimateSNR(List<double> samples) {
    if (samples.length < 2) return 0.0;

    final noiseLength = math.max(1, (samples.length * 0.15).toInt());
    double noiseEnergy = 0.0;
    for (int i = 0; i < noiseLength; i++) {
      final x = samples[i];
      noiseEnergy += x * x;
    }
    noiseEnergy /= noiseLength;

    double signalEnergy = 0.0;
    final signalCount = samples.length - noiseLength;
    for (int i = noiseLength; i < samples.length; i++) {
      final x = samples[i];
      signalEnergy += x * x;
    }
    signalEnergy /= signalCount;

    if (noiseEnergy <= 1e-12) return 50.0;
    return 10 * math.log(signalEnergy / noiseEnergy) / math.ln10;
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
