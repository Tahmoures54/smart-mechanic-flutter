class Car {
  final String id;
  final String brand;
  final String model;
  final String year;
  final String engine;
  final String? region;        // ME, SA, ...
  final String? fuelType;      // petrol, diesel, hybrid, electric
  final String? transmission;  // manual, automatic
  final List<String> commonIssues;
  final List<dynamic> history; // می‌توانید به جای dynamic از نوع DiagnosticCode استفاده کنید

  Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.engine,
    this.region,
    this.fuelType,
    this.transmission,
    this.commonIssues = const [],
    this.history = const [],
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      year: json['year']?.toString() ?? '',
      engine: json['engine'] ?? '',
      region: json['region'],
      fuelType: json['fuelType'],
      transmission: json['transmission'],
      commonIssues: List<String>.from(json['commonIssues'] ?? []),
      history: List<dynamic>.from(json['history'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'year': year,
      'engine': engine,
      'region': region,
      'fuelType': fuelType,
      'transmission': transmission,
      'commonIssues': commonIssues,
      'history': history,
    };
  }

  String get fullName => '$brand $model ($year)';

  /// توضیح کامل خودرو با جزئیات فنی
  String get description {
    final parts = <String>[];
    if (engine.isNotEmpty) parts.add(engine);
    if (fuelType != null) parts.add(fuelType!);
    if (transmission != null) parts.add(transmission!);
    return parts.join(' · ');
  }
}
