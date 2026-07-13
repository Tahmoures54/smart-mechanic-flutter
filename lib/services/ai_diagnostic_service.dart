import 'dart:convert';
import 'package:http/http.dart' as http;

/// مدل پاسخ هوش مصنوعی برای عیب‌یابی خودرو
class AIResponse {
  final String diagnosis;
  final double confidence;
  final String recommendedAction;
  final List<String> possibleFaults;
  final double estimatedCost;
  final List<String> nearbyGarages;

  const AIResponse({
    required this.diagnosis,
    required this.confidence,
    required this.recommendedAction,
    required this.possibleFaults,
    required this.estimatedCost,
    required this.nearbyGarages,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    // مدیریت امن مقادیر عددی برای جلوگیری از خطای Type Casting
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return AIResponse(
      diagnosis: json['diagnosis'] as String? ?? '',
      confidence: parseDouble(json['confidence']),
      recommendedAction: json['recommended_action'] as String? ?? '',
      possibleFaults: List<String>.unmodifiable(
          (json['possible_faults'] as List<dynamic>?)?.cast<String>() ?? const []),
      estimatedCost: parseDouble(json['estimated_cost']),
      nearbyGarages: List<String>.unmodifiable(
          (json['nearby_garages'] as List<dynamic>?)?.cast<String>() ?? const []),
    );
  }
}

/// کلاس سرویس عیب‌یابی هوش مصنوعی
class AIDiagnosticService {
  final http.Client _httpClient;
  final String _apiKey;
  final Uri _apiEndpoint = Uri.parse('https://api.openai.com/v1/chat/completions');

  // تزریق وابستگی‌ها از طریق Constructor
  AIDiagnosticService({
    required http.Client httpClient,
    required String apiKey, // کلید باید از محیط امن (مثل .env یا dart-define) تامین شود
  })  : _httpClient = httpClient,
        _apiKey = apiKey;

  /// ارسال داده‌ها به مدل هوش مصنوعی و دریافت عیب‌یابی
  Future<AIResponse> diagnose({
    required AudioFeatures audioFeatures,
    required CarInfo carInfo,
    required List<DiagnosticCode> obdCodes,
  }) async {
    final prompt = _buildPrompt(audioFeatures, carInfo, obdCodes);

    try {
      final response = await _httpClient.post(
        _apiEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini', // پیشنهاد: استفاده از مدل سریع‌تر برای موبایل
          'response_format': {'type': 'json_object'}, // الزام مدل به برگرداندن JSON خالص
          'messages': [
            {'role': 'system', 'content': 'شما یک متخصص تعمیرات خودرو هستید. پاسخ خود را فقط به فرمت JSON معتبر ارائه دهید.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.2,
        }),
      ).timeout(const Duration(seconds: 30)); // جلوگیری از هنگ کردن اپلیکیشن

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        
        if (choices == null || choices.isEmpty) {
          throw FormatException('AI returned no choices.');
        }
        
        final content = choices[0]['message']['content'] as String;
        final parsedJson = _extractAndParseJson(content);
        
        return AIResponse.fromJson(parsedJson);
      } else {
        // مدیریت خطاهای HTTP با اطلاعات بیشتر
        throw Exception('AI Diagnosis failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // در اینجا می‌توانید لاگ‌گیری انجام دهید یا خطا را به یک نوع خطای اختصاصی اپلیکیشن تبدیل کنید
      rethrow; 
    }
  }

  /// استخراج JSON از داخل متن (در صورتی که مدل، Markdown اضافه کرد)
  Map<String, dynamic> _extractAndParseJson(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      // تلاش برای استخراج JSON از بین بلاک‌های کد مارک‌داون
      final regex = RegExp(r'\{.*\}', dotAll: true);
      final match = regex.firstMatch(content);
      if (match != null) {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      }
      throw FormatException('Failed to parse AI response as JSON: $content');
    }
  }

  String _buildPrompt(AudioFeatures af, CarInfo car, List<DiagnosticCode> codes) {
    // اصلاح غلط‌های املایی و شفاف‌سازی خروجی مورد انتظار
    return '''
    تحلیل صدای موتور خودرو:
    - RMS: ${af.rms}
    - فرکانس غالب: ${af.dominantFrequency} Hz
    - نرخ عبور از صفر (Zero Crossing Rate): ${af.zeroCrossingRate}
    - Centroid طیفی: ${af.spectralCentroid}

    اطلاعات خودرو:
    - مدل: ${car.model}
    - سال: ${car.year}
    - منطقه: ${car.region}
    - نوع سوخت: ${car.fuelType}

    کدهای خطا OBD-II:
    ${codes.map((c) => '- ${c.code}: ${c.description}').join('\n')}

    بر اساس این داده‌ها، عیب‌یابی، توصیه تعمیر و تخمین هزینه را ارائه بده.
    خروجی باید دقیقاً شامل کلیدهای JSON زیر باشد:
    "diagnosis" (string), "confidence" (number 0 to 1), "recommended_action" (string), "possible_faults" (array of strings), "estimated_cost" (number), "nearby_garages" (array of strings)
    ''';
  }
}

// نکته: کلاس‌های پایه فرض شده‌اند و در پروژه اصلی باید تعریف شوند.
class AudioFeatures { final double rms; final double dominantFrequency; final double zeroCrossingRate; final double spectralCentroid; const AudioFeatures(this.rms, this.dominantFrequency, this.zeroCrossingRate, this.spectralCentroid);}
class CarInfo { final String model; final int year; final String region; final String fuelType; const CarInfo(this.model, this.year, this.region, this.fuelType);}
class DiagnosticCode { final String code; final String description; const DiagnosticCode(this.code, this.description);}
