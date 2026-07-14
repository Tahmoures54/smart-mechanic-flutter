import 'dart:io';
import 'dart:math';
import '../models/audio_features.dart'; // ایمپورت مدل

class SoundAnalyzer {
  Future<AudioFeatures> analyze(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('فایل صوتی یافت نشد.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('فایل صوتی خالی است.');
    }

    const int fftSize = 1024;
    
    List<double> input = List.filled(fftSize, 0.0);
    for (int i = 0; i < min(fftSize, bytes.length); i++) {
      input[i] = bytes[i] / 255.0; 
    }

    double sumSquares = 0;
    for (double sample in input) {
      sumSquares += sample * sample;
    }
    double rms = sqrt(sumSquares / input.length);

    int zcr = 0;
    for (int i = 1; i < input.length; i++) {
      if ((input[i] >= 0 && input[i - 1] < 0) || (input[i] < 0 && input[i - 1] >= 0)) {
        zcr++;
      }
    }
    double zcrRate = zcr / (input.length - 1);

    return AudioFeatures(
      rms: rms,
      dominantFrequency: 440.0,
      spectralCentroid: 1500.0,
      spectralRolloff: 3000.0,
      zeroCrossingRate: zcrRate,
      frequencySpectrum: List.filled(512, 0.0),
    );
  }
}
