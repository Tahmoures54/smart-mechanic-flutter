import 'dart:math';
import 'dart:typed_data';
import 'package:fft/fft.dart';

/// مدل داده‌ای ویژگی‌های صوتی استخراج شده
class AudioFeatures {
  final double rms;
  final double dominantFrequency;
  final double spectralCentroid;
  final double spectralRolloff;
  final double zeroCrossingRate;
  final List<double> frequencySpectrum;

  const AudioFeatures({
    required this.rms,
    required this.dominantFrequency,
    required this.spectralCentroid,
    required this.spectralRolloff,
    required this.zeroCrossingRate,
    required this.frequencySpectrum,
  });
}

class SoundAnalyzer {
  /// تحلیل FFT روی بایت‌های صدا
  /// پارامتر pcmData باید شامل نمونه‌های 16-bit integer باشد
  static AudioFeatures? analyze(List<int> pcmData, int sampleRate) {
    if (pcmData.isEmpty) return null;

    const int fftSize = 1024;
    
    // اگر داده کمتر از fftSize باشد، با صفر پر می‌کنیم (Zero-padding)
    // اگر بیشتر باشد، فقط 1024 نمونه اول را برمی‌داریم (برای سادگی)
    List<double> input = List.filled(fftSize, 0.0);
    for (int i = 0; i < min(fftSize, pcmData.length); i++) {
      // نرمال‌سازی مقادیر 16 بیتی به بازه 1.0- تا 1.0
      input[i] = pcmData[i] / 32768.0; 
    }

    final fft = FFT(fftSize);
    final spectrum = fft.forward(input); // خروجی: List<Complex>

    // محاسبه RMS در حوزه زمان (Time Domain)
    double sumSquares = 0;
    for (double sample in input) {
      sumSquares += sample * sample;
    }
    double rms = sqrt(sumSquares / input.length);

    // محاسبه Zero Crossing Rate در حوزه زمان
    int zcr = 0;
    for (int i = 1; i < input.length; i++) {
      if ((input[i] >= 0 && input[i - 1] < 0) || (input[i] < 0 && input[i - 1] >= 0)) {
        zcr++;
      }
    }
    double zcrRate = zcr / (input.length - 1);

    // پردازش در حوزه فرکانس (Frequency Domain) - فقط نیمه اول (قضیه نایکوئیست)
    final int halfSize = fftSize ~/ 2;
    
    double dominantFreq = 0;
    double maxMagnitude = 0;
    double totalMagnitude = 0;
    double centroidNumerator = 0;
    double rolloff = 0;
    bool rolloffFound = false;
    
    // آماده‌سازی لیست magnitudes برای نمودار
    final List<double> magnitudes = List.filled(halfSize, 0.0);

    // تک‌حلقه‌ای برای بهینه‌سازی سرعت
    for (int i = 0; i < halfSize; i++) {
      final re = spectrum[i].real;
      final im = spectrum[i].imaginary;
      final mag = sqrt(re * re + im * im);
      
      magnitudes[i] = mag;
      totalMagnitude += mag;

      double freq = (i * sampleRate) / fftSize;

      // یافتن فرکانس غالب
      if (mag > maxMagnitude) {
        maxMagnitude = mag;
        dominantFreq = freq;
      }

      // محاسبه Centroid
      centroidNumerator += freq * mag;

      // محاسبه Rolloff (85% انرژی)
      if (!rolloffFound && totalMagnitude > 0) {
        // چون totalMagnitude هنوز کامل محاسبه نشده، این روش در یک پاس کامل درست نمی‌شود.
        // برای درست شدن Rolloff در یک حلقه، باید این بخش را به حلقه دوم منتقل کنیم 
        // یا مجموع کل را در دو مرحله محاسبه کنیم. (برای حفظ کارایی، دو مرحله ای می‌کنیم)
      }
    }

    // محاسبه Centroid نهایی
    double centroid = totalMagnitude > 0 ? (centroidNumerator / totalMagnitude) : 0;

    // محاسبه Rolloff (نیاز به پیمایش دوم چون به totalMagnitude کل نیاز دارد)
    double cumulativeMag = 0;
    for (int i = 0; i < halfSize; i++) {
      cumulativeMag += magnitudes[i];
      if (cumulativeMag / totalMagnitude >= 0.85) {
        rolloff = (i * sampleRate) / fftSize;
        break;
      }
    }

    return AudioFeatures(
      rms: rms,
      dominantFrequency: dominantFreq,
      spectralCentroid: centroid,
      spectralRolloff: rolloff,
      zeroCrossingRate: zcrRate,
      frequencySpectrum: magnitudes, // فقط نیمه مفید بازگردانده می‌شود
    );
  }
}
