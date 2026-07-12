class Diagnostic {
  final int id;
  final String carId;
  final String description;
  final String result;
  final String createdAt;

  Diagnostic({
    required this.id,
    required this.carId,
    required this.description,
    required this.result,
    required this.createdAt,
  });

  factory Diagnostic.fromJson(Map<String, dynamic> json) {
    return Diagnostic(
      id: json['id'],
      carId: json['carId'],
      description: json['description'],
      result: json['result'],
      createdAt: json['createdAt'],
    );
  }
}
