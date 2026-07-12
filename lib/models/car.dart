class Car {
  final String id;
  final String brand;
  final String model;
  final String year;
  final String engine;
  final List<String> commonIssues;

  Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.engine,
    required this.commonIssues,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'],
      brand: json['brand'],
      model: json['model'],
      year: json['year'],
      engine: json['engine'],
      commonIssues: List<String>.from(json['commonIssues'] ?? []),
    );
  }

  String get fullName => '$brand $model ($year)';
}
