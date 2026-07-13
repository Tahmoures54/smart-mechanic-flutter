import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AIResponse {
  final String diagnosis;
  final double confidence;
  final String recommendedAction;
  final List<String> possibleFaults;
  final double estimatedCost; // تومان یا دلار
  final List<String> nearbyGarages; // نام تعمیرگاه‌ها

  AIResponse({
    required this.diagnosis,
    required this.confidence,
    required this.recommendedAction,
    required this.possibleFaults,
    required this.estimatedCost,
    required this.nearbyGarages,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) => AIResponse(
        diagnosis: json['diagnosis'] ?? '',
        confidence: (json['confidence'] ?? 0.0).toDouble(),
        recommendedAction: json['recommended_action'] ?? '',
        possibleFaults: List<String>.from(json['possible_faults'] ?? []),
        estimatedCost: (json['estimated_cost'] ?? 0).toDouble(),
        nearbyGarages: List<String>.from(json['nearby_garages'] ?? []),
      );
}

class AIDiagnosticService {
  static const String _apiKey = 'YOUR_API_KEY'; // از constantes.dart خوانده شود
  static const String _apiEndpoint = 'https://api.openai.com/v1/chat/completions'; // یاendpoint مدل محلی

  Future<AIResponse> diagnose({
    required AudioFeatures audioFeatures,
    required CarInfo carInfo,
    required List<DiagnosticCode> obdCodes,
  }) async {
    final prompt = _buildPrompt(audioFeatures, carInfo, obdCodes);
    
    final response = await http.post(
      Uri.parse(_apiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o', // یا مدل مناسب
        'messages': [
          {'role': 'system', 'content': 'شما یک متخصص تعمیرات خودرو هستید.'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.2,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return AIResponse.fromJson(jsonDecode(content)); // فرض بر اینکه AI JSON برگرداند
    } else {
      throw Exception('AI Diagnosis failed: ${response.body}');
    }
  }

  String _buildPrompt(AudioFeatures af, CarInfo car, List<DiagnosticCode> codes) {
    return '''
    تحلیل صدا موتور خودرو:
    - RMS: ${af.rms}
    - فرکانس غالب: ${af.dominantFrequency} Hz
    - صداهای نامنظم: ${af.zeroCrossingRate}
    - Centroid: ${af.spectralCentroid}

    اطلاعات خودرو:
    - مدل: ${car.model}
    - سال: ${car.year}
    - منطقه: ${car.region}
    - ن coolant: ${car.fuelType}

    کدهای خطا OBD-II:
    ${codes.map((c) => '- ${c.code}: ${c.description}').join('\n')}

    بر اساس این داده‌ها، عیب‌چشمان، توصیه تعمیر و تخمین هزینه را به فارسی/عربی ارائه ده.
    ''';
  }
}
