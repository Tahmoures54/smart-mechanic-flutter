import 'api_service.dart';

/// کلاس سرویس عیب‌یابی (رابط بین دیتای سنسورهای گوشی و بک‌اَند)
class AIDiagnosticService {
  final ApiService _apiService;

  // فقط ApiService خودمان را می‌گیرد، نیازی به کلید API هوش مصنوعی در گوشی نیست!
  AIDiagnosticService({required ApiService apiService}) : _apiService = apiService;

  /// ترکیب داده‌های پیشرفته (صدا + دستگاه دیاگ + متن) و ارسال به سرور خودمان
  Future<String> diagnose({
    required String token,
    required String carId, // آیدی ماشین از فایل cars.json
    String? userDescription,
    AudioFeatures? audioFeatures,
    List<DiagnosticCode>? obdCodes,
  }) async {
    // تبدیل اطلاعات پیچیده به یک متن قابل فهم برای هوش مصنوعیِ سمت سرور
    final String finalDescription = _buildPrompt(
      userDescription: userDescription,
      af: audioFeatures,
      codes: obdCodes,
    );

    try {
      // ارسال به بک‌اند امن خودمان (که آنجا اعتبار کسر می‌شود و به DeepSeek وصل است)
      final result = await _apiService.diagnose(token, carId, finalDescription);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// متد کمکی برای ساختن شرح حال دقیق
  String _buildPrompt({
    String? userDescription,
    AudioFeatures? af,
    List<DiagnosticCode>? codes,
  }) {
    StringBuffer prompt = StringBuffer();

    if (userDescription != null && userDescription.isNotEmpty) {
      prompt.writeln("شرح مشکل توسط راننده: $userDescription");
    }

    if (codes != null && codes.isNotEmpty) {
      prompt.writeln("\nکدهای خطای استخراج شده از دستگاه دیاگ (OBD-II):");
      for (var c in codes) {
        prompt.writeln('- ${c.code}: ${c.description}');
      }
    }

    if (af != null) {
      prompt.writeln("\nتحلیل فرکانس صدای موتور (ضبط شده توسط گوشی):");
      prompt.writeln("- بلندی صدا (RMS): ${af.rms}");
      prompt.writeln("- فرکانس غالب: ${af.dominantFrequency} Hz");
    }

    // اگر هیچ دیتایی نبود
    if (prompt.isEmpty) {
      return "لطفاً ماشین را بررسی کنید.";
    }

    return prompt.toString();
  }
}

// ----------------------------------------------------
// مدل‌های پایه (بهتر است این‌ها را در پوشه models قرار دهید)
// ----------------------------------------------------
class AudioFeatures { 
  final double rms; 
  final double dominantFrequency; 
  final double zeroCrossingRate; 
  final double spectralCentroid; 
  const AudioFeatures(this.rms, this.dominantFrequency, this.zeroCrossingRate, this.spectralCentroid);
}

class DiagnosticCode { 
  final String code; 
  final String description; 
  const DiagnosticCode(this.code, this.description);
}
