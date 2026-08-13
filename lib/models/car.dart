class Car {
  final String id;
  final String brand;
  final String model;
  /// سال نمونه در لیست (اختیاری) — سال واقعی را کاربر وارد می‌کند
  final String year;
  final String engine;
  final String? region;
  final String? fuelType;
  final String? transmission;
  final List<String> commonIssues;
  final List<dynamic> history;

  Car({
    required this.id,
    required this.brand,
    required this.model,
    this.year = '',
    required this.engine,
    this.region,
    this.fuelType,
    this.transmission,
    this.commonIssues = const [],
    this.history = const [],
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: (json['id'] ?? '').toString(),
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      year: json['year']?.toString() ?? '',
      engine: json['engine'] ?? '',
      region: json['region'],
      fuelType: json['fuelType'],
      transmission: json['transmission'] ?? json['gearbox'],
      commonIssues: () {
        final raw = json['commonIssues'];
        if (raw is List) return List<String>.from(raw.map((e) => e.toString()));
        if (raw is String && raw.isNotEmpty) return [raw];
        return <String>[];
      }(),
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

  /// فقط نام خودرو — بدون سال (سال را کاربر جدا وارد می‌کند)
  String get fullName => '$brand $model'.trim();

  String get description {
    final parts = <String>[];
    if (engine.isNotEmpty) parts.add(engine);
    if (fuelType != null) parts.add(fuelType!);
    if (transmission != null) parts.add(transmission!);
    return parts.join(' · ');
  }
}
