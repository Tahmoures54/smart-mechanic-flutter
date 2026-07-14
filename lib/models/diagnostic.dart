import 'car.dart';
import 'audio_features.dart';

class Diagnostic {
  final String id;
  final String carId;
  final Car? car;
  final DateTime timestamp;
  final String? description;
  final String? result;
  final AudioFeatures? audioFeatures;
  final double? confidenceScore;

  Diagnostic({
    required this.id,
    required this.timestamp,
    this.carId = '',
    this.car,
    this.description,
    this.result,
    this.audioFeatures,
    this.confidenceScore,
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
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'carId': carId,
        'car': car?.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'description': description,
        'result': result,
        'audioFeatures': audioFeatures?.toJson(),
        'confidenceScore': confidenceScore,
      };

  String get summary => result ?? description ?? 'بدون خلاصه';
}
