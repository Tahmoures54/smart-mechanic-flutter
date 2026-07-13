class AudioFeatures {
  final double rms;
  final double dominantFrequency;
  final double spectralCentroid;
  final double spectralRolloff;
  final double zeroCrossingRate;
  final List<double> frequencySpectrum; // برای نمودار

  AudioFeatures({
    required this.rms,
    required this.dominantFrequency,
    required this.spectralCentroid,
    required this.spectralRolloff,
    required this.zeroCrossingRate,
    required this.frequencySpectrum,
  });

  Map<String, dynamic> toJson() => {
    'rms': rms,
    'dominant_frequency': dominantFrequency,
    'spectral_centroid': spectralCentroid,
    'spectral_rolloff': spectralRolloff,
    'zero_crossing_rate': zeroCrossingRate,
    'frequency_spectrum': frequencySpectrum,
  };

  factory AudioFeatures.fromJson(Map<String, dynamic> json) => AudioFeatures(
    rms: json['rms']?.toDouble() ?? 0,
    dominantFrequency: json['dominant_frequency']?.toDouble() ?? 0,
    spectralCentroid: json['spectral_centroid']?.toDouble() ?? 0,
    spectralRolloff: json['spectral_rolloff']?.toDouble() ?? 0,
    zeroCrossingRate: json['zero_crossing_rate']?.toDouble() ?? 0,
    frequencySpectrum: json['frequency_spectrum']?.cast<double>() ?? [],
  );
}
