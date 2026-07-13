import 'car_model.dart'; // فرض می‌کنیم کلاس Car (و CarInfo سابق) در این فایل است
import 'audio_features.dart'; // کلاس AudioFeatures
import 'ai_response.dart'; // کلاس AIResponse
import 'diagnostic_code.dart'; // کلاس DiagnosticCode

class Diagnostic {
  final String id;                  // شناسه یکتا (String برای پشتیبانی از UUID یا int تبدیل‌شده)
  final String carId;               // ارجاع به خودرو (اختیاری اگر car مستقیماً ذخیره شود)
  final Car? car;                   // آبجکت کامل خودرو (در صورت نیاز)
  final DateTime timestamp;         // زمان ایجاد یا ثبت
  final String? description;        // توضیحات اولیه (متن ورودی کاربر)
  final String? result;             // نتیجه تشخیص (متن ساده)
  final AudioFeatures? audioFeatures; // ویژگی‌های صوتی استخراج‌شده
  final AIResponse? aiResponse;     // پاسخ کامل مدل هوش مصنوعی
  final double? confidenceScore;    // امتیاز اطمینان
  final List<DiagnosticCode> obdCodes; // کدهای OBD یا خطاها

  Diagnostic({
    required this.id,
    required this.timestamp,
    this.carId = '',
    this.car,
    this.description,
    this.result,
    this.audioFeatures,
    this.aiResponse,
    this.confidenceScore,
    this.obdCodes = const [],
  });

  factory Diagnostic.fromJson(Map<String, dynamic> json) {
    return Diagnostic(
      id: (json['id'] ?? '').toString(),
      carId: json['carId'] ?? '',
      car: json['car'] != null ? Car.fromJson(json['car']) : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      description: json['description'],
      result: json['result'],
      audioFeatures: json['audioFeatures'] != null
          ? AudioFeatures.fromJson(json['audioFeatures'])
          : null,
      aiResponse: json['aiResponse'] != null
          ? AIResponse.fromJson(json['aiResponse'])
          : null,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble(),
      obdCodes: (json['obdCodes'] as List<dynamic>?)
              ?.map((e) => DiagnosticCode.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carId': carId,
      'car': car?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'result': result,
      'audioFeatures': audioFeatures?.toJson(),
      'aiResponse': aiResponse?.toJson(),
      'confidenceScore': confidenceScore,
      'obdCodes': obdCodes.map((e) => e.toJson()).toList(),
    };
  }

  /// خلاصه‌ای خوانا از تشخیص
  String get summary => result ?? aiResponse?.summary ?? description ?? 'بدون خلاصه';
}
