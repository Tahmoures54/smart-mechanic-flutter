import 'api_service.dart';

/// سرویس عیب‌یابی — رابط بین سنسورها و بک‌اند
class AIDiagnosticService {
  final ApiService _apiService;

  AIDiagnosticService({required ApiService apiService})
      : _apiService = apiService;

  Future<String> diagnose({
    required String token,
    required String carId,
    required String year,
    String? carName,
    String? userDescription,
    AudioFeatures? audioFeatures,
    List<DiagnosticCode>? obdCodes,
  }) async {
    final String finalDescription = _buildPrompt(
      userDescription: userDescription,
      af: audioFeatures,
      codes: obdCodes,
    );

    return _apiService.diagnose(
      token,
      carId,
      finalDescription,
      year: year,
      carName: carName,
    );
  }

  String _buildPrompt({
    String? userDescription,
    AudioFeatures? af,
    List<DiagnosticCode>? codes,
  }) {
    final StringBuffer prompt = StringBuffer();

    if (userDescription != null && userDescription.isNotEmpty) {
      prompt.writeln('شرح مشکل توسط راننده: $userDescription');
    }

    if (codes != null && codes.isNotEmpty) {
      prompt.writeln('\nکدهای خطای استخراج شده از دستگاه دیاگ (OBD-II):');
      for (final c in codes) {
        prompt.writeln('- ${c.code}: ${c.description}');
      }
    }

    if (af != null) {
      prompt.writeln('\nتحلیل فرکانس صدای موتور (ضبط شده توسط گوشی):');
      prompt.writeln('- بلندی صدا (RMS): ${af.rms}');
      prompt.writeln('- فرکانس غالب: ${af.dominantFrequency} Hz');
    }

    if (prompt.isEmpty) {
      return 'لطفاً ماشین را بررسی کنید.';
    }

    return prompt.toString();
  }
}

class AudioFeatures {
  final double rms;
  final double dominantFrequency;
  final double zeroCrossingRate;
  final double spectralCentroid;
  const AudioFeatures(
    this.rms,
    this.dominantFrequency,
    this.zeroCrossingRate,
    this.spectralCentroid,
  );
}

class DiagnosticCode {
  final String code;
  final String description;
  const DiagnosticCode(this.code, this.description);
}
