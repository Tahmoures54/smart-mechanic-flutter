import 'car.dart';
import 'audio_features.dart';

/// مدل کامل عیب‌یابی
class Diagnostic {
  final String id;
  final String carId;
  final String? carName;
  final String? carYear;
  final Car? car;

  final DateTime createdAt;
  final DateTime? updatedAt;

  final String? description;
  final String? result;
  final AudioFeatures? audioFeatures;

  final double? confidenceScore;
  final int? userRating;
  final String? userFeedback;

  final DiagnosticStatus status;
  final DiagnosticType type;
  final bool isGolden;

  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const Diagnostic({
    required this.id,
    required this.carId,
    required this.createdAt,
    this.carName,
    this.carYear,
    this.car,
    this.updatedAt,
    this.description,
    this.result,
    this.audioFeatures,
    this.confidenceScore,
    this.userRating,
    this.userFeedback,
    this.status = DiagnosticStatus.completed,
    this.type = DiagnosticType.text,
    this.isGolden = false,
    this.errorMessage,
    this.metadata,
  });

  factory Diagnostic.fromJson(Map<String, dynamic> json) {
    final createdAt = _parseDate(json['createdAt'] ?? json['created_at'] ?? json['timestamp']) ?? DateTime.now();
    final updatedAt = _parseDate(json['updatedAt'] ?? json['updated_at']);

    final Car? car = json['car'] is Map<String, dynamic>
        ? Car.fromJson(json['car'] as Map<String, dynamic>)
        : null;

    final AudioFeatures? audioFeatures = json['audioFeatures'] is Map<String, dynamic>
        ? AudioFeatures.fromJson(json['audioFeatures'] as Map<String, dynamic>)
        : null;

    final Map<String, dynamic>? metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : null;

    return Diagnostic(
      id: _str(json['id']),
      carId: _str(json['carId'] ?? json['car_id']),
      carName: (json['carName'] ?? json['car_name'])?.toString(),
      carYear: (json['carYear'] ?? json['car_year'])?.toString(),
      car: car,
      createdAt: createdAt,
      updatedAt: updatedAt,
      description: json['description']?.toString(),
      result: json['result']?.toString(),
      audioFeatures: audioFeatures,
      confidenceScore: _parseDouble(json['confidenceScore'] ?? json['confidence_score']),
      userRating: _parseInt(json['userRating'] ?? json['user_rating'] ?? json['rating']),
      userFeedback: (json['feedback'] ?? json['userFeedback'])?.toString(),
      status: DiagnosticStatus.fromString(json['status']?.toString()),
      type: DiagnosticType.fromString(json['type']?.toString(), hasAudio: audioFeatures != null),
      isGolden: _bool(json['isGolden'] ?? json['is_golden']),
      errorMessage: (json['errorMessage'] ?? json['error_message'])?.toString(),
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'carId': carId,
        if (carName != null) 'carName': carName,
        if (carYear != null) 'carYear': carYear,
        if (car != null) 'car': car!.toJson(),
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (description != null) 'description': description,
        if (result != null) 'result': result,
        if (audioFeatures != null) 'audioFeatures': audioFeatures!.toJson(),
        if (confidenceScore != null) 'confidenceScore': confidenceScore,
        if (userRating != null) 'userRating': userRating,
        if (userFeedback != null) 'feedback': userFeedback,
        'status': status.name,
        'type': type.name,
        'isGolden': isGolden,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (metadata != null) 'metadata': metadata,
      };

  Diagnostic copyWith({
    String? id,
    String? carId,
    String? carName,
    String? carYear,
    Car? car,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? result,
    AudioFeatures? audioFeatures,
    double? confidenceScore,
    int? userRating,
    String? userFeedback,
    DiagnosticStatus? status,
    DiagnosticType? type,
    bool? isGolden,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return Diagnostic(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      carName: carName ?? this.carName,
      carYear: carYear ?? this.carYear,
      car: car ?? this.car,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      result: result ?? this.result,
      audioFeatures: audioFeatures ?? this.audioFeatures,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      userRating: userRating ?? this.userRating,
      userFeedback: userFeedback ?? this.userFeedback,
      status: status ?? this.status,
      type: type ?? this.type,
      isGolden: isGolden ?? this.isGolden,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  String get displayCarName {
    if (carName != null && carName!.isNotEmpty) return carName!;
    if (car != null) return car!.fullName;
    if (carId.isNotEmpty) return carId;
    return 'خودروی ناشناس';
  }

  String get displayCarNameWithYear {
    final name = displayCarName;
    if (carYear != null && carYear!.isNotEmpty) return '$name ($carYear)';
    return name;
  }

  String get summary {
    String? text = description;
    if (text == null || text.isEmpty) text = result;
    if (text != null && text.isNotEmpty) {
      return text.length > 80 ? '${text.substring(0, 80)}...' : text;
    }
    return 'بدون توضیحات';
  }

  String get fullContent => result ?? description ?? 'بدون محتوا';
  bool get hasResult => result != null && result!.isNotEmpty;
  bool get hasAudioFeatures => audioFeatures != null;
  bool get isRated => userRating != null;
  bool get isSuccessful => status == DiagnosticStatus.completed && hasResult;
  bool get isPending => status == DiagnosticStatus.pending;
  bool get hasFailed => status == DiagnosticStatus.failed;

  String get formattedDate {
    final d = createdAt;
    final date = '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }

  String get confidencePercent {
    if (confidenceScore == null) return '';
    return '${(confidenceScore! * 100).toStringAsFixed(0)}٪';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Diagnostic && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Diagnostic(id=$id, car=$displayCarName, status=${status.name}, type=${type.name})';

  static String _str(dynamic value) => value == null ? '' : value.toString().trim();

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _bool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return defaultValue;
  }
}

enum DiagnosticStatus {
  pending,
  processing,
  completed,
  failed;

  String get label => switch (this) {
        DiagnosticStatus.pending => 'در انتظار',
        DiagnosticStatus.processing => 'در حال پردازش',
        DiagnosticStatus.completed => 'انجام‌شده',
        DiagnosticStatus.failed => 'ناموفق',
      };

  static DiagnosticStatus fromString(String? value) {
    if (value == null) return DiagnosticStatus.completed;
    final lower = value.toLowerCase();
    for (final status in DiagnosticStatus.values) {
      if (status.name == lower) return status;
    }
    return DiagnosticStatus.completed;
  }
}

enum DiagnosticType {
  text,
  audio;

  String get label => switch (this) {
        DiagnosticType.text => '💬 متنی',
        DiagnosticType.audio => '🎙️ صوتی',
      };

  static DiagnosticType fromString(String? value, {bool hasAudio = false}) {
    if (value != null) {
      final lower = value.toLowerCase();
      for (final type in DiagnosticType.values) {
        if (type.name == lower) return type;
      }
    }
    return hasAudio ? DiagnosticType.audio : DiagnosticType.text;
  }
}
