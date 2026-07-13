import 'dart:math';
import 'package:fft/fft.dart';

class AudioFeatures {
  final double rms;
  final double dominantFrequency;
  final double spectralCentroid;
  final double spectralRolloff;
  final double zeroCrossingRate;
  final List<double> frequencySpectrum; // لیست magnitude برای نمودار

  AudioFeatures({
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
  static AudioFeatures analyze(List<short> pcmData, int sampleRate) {
    final fft = FFT(1024); // اندازه FFT
    final spectrum = fft.forward(pcmData);
    
    // محاسبه RMS
    double rms = sqrt(spectrum.map((e) => e * e).reduce((a, b) => a + b) / spectrum.length);

    // یافتن فرکانس غالب
    double dominantFreq = 0;
    double maxMagnitude = 0;
    for (int i = 0; i < spectrum.length ~/ 2; i++) {
      if (spectrum[i] > maxMagnitude) {
        maxMagnitude = spectrum[i];
        dominantFreq = (i * sampleRate) / fft.n;
      }
    }

    // محاسبه Centroid و Rolloff (تبسيplified)
    double centroid = 0, rolloff = 0;
    double totalMagnitude = spectrum.map((e) => e.abs()).reduce((a, b) => a + b);
    double energy = 0;
    for (int i = 0; i < spectrum.length; i++) {
      energy += spectrum[i].abs();
      if (energy / totalMagnitude > 0.85) { // 85% energy
        rolloff = (i * sampleRate) / fft.n;
        break;
      }
      centroid += (i * sampleRate / fft.n) * spectrum[i].abs();
    }
    centroid /= totalMagnitude;

    // Zero Crossing Rate
    int zcr = 0;
    for (int i = 1; i < pcmData.length; i++) {
      if ((pcmData[i] > 0 && pcmData[i-1] <= 0) || (pcmData[i] <= 0 && pcmData[i-1] > 0)) {
        zcr++;
      }
    }
    double zcrRate = zcr / (pcmData.length - 1);

    return AudioFeatures(
      rms: rms,
      dominantFrequency: dominantFreq,
      spectralCentroid: centroid,
      spectralRolloff: rolloff,
      zeroCrossingRate: zcrRate,
      frequencySpectrum: spectrum.map((e) => e.abs()).toList(),
    );
  }
}
