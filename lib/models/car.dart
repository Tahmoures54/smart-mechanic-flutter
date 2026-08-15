/// مدل کامل خودرو
class Car {
  // ── شناسه ──
  final String id;

  // ── مشخصات اصلی ──
  final String brand;
  final String model;

  /// سال نمونه در لیست (اختیاری) — سال واقعی را کاربر جدا وارد می‌کند
  final String year;
  final String engine;

  // ── مشخصات اضافه ──
  final String? region;
  final String? fuelType;
  final String? transmission;
  final String? category;       // سدان، شاسی‌بلند، هاچ‌بک، وانت، ...
  final String? imageUrl;       // آدرس تصویر خودرو
  final String? countryOfOrigin; // کشور سازنده: ایران، ژاپن، کره، ...

  // ── ویژگی‌های بولی ──
  final bool isPopular;         // خودروهای محبوب (برای نمایش اول لیست)
  final bool isElectric;        // خودروی برقی یا هیبرید
  final bool isActive;          // آیا در حال تولید است

  // ── مشکلات و تاریخچه ──
  final List<String> commonIssues;
  final List<CarHistoryEntry> history;

  // ── اطلاعات تکمیلی ──
  final int? productionStartYear;  // سال شروع تولید
  final int? productionEndYear;    // سال پایان تولید (null یعنی در حال تولید)

  const Car({
    required this.id,
    required this.brand,
    required this.model,
    this.year = '',
    required this.engine,
    this.region,
    this.fuelType,
    this.transmission,
    this.category,
    this.imageUrl,
    this.countryOfOrigin,
    this.isPopular = false,
    this.isElectric = false,
    this.isActive = true,
    this.commonIssues = const [],
    this.history = const [],
    this.productionStartYear,
    this.productionEndYear,
  });

  // ─────────────────────────────────────────
  // ── سازنده از JSON ──
  // ─────────────────────────────────────────
  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: _str(json['id']),
      brand: _str(json['brand']),
      model: _str(json['model']),
      year: json['year']?.toString() ?? '',
      engine: _str(json['engine']),
      region: json['region'] as String?,
      fuelType: json['fuelType'] as String?,
      transmission: (json['transmission'] ?? json['gearbox']) as String?,
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] ?? json['image_url'] as String?,
      countryOfOrigin:
          json['countryOfOrigin'] ?? json['country_of_origin'] as String?,
      isPopular: _bool(json['isPopular'] ?? json['is_popular']),
      isElectric: _bool(json['isElectric'] ?? json['is_electric']),
      isActive: _bool(json['isActive'] ?? json['is_active'], defaultValue: true),
      commonIssues: _parseStringList(json['commonIssues']),
      history: _parseHistory(json['history']),
      productionStartYear: _parseInt(json['productionStartYear']),
      productionEndYear: _parseInt(json['productionEndYear']),
    );
  }

  // ─────────────────────────────────────────
  // ── تبدیل به JSON ──
  // ─────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'model': model,
        'year': year,
        'engine': engine,
        if (region != null) 'region': region,
        if (fuelType != null) 'fuelType': fuelType,
        if (transmission != null) 'transmission': transmission,
        if (category != null) 'category': category,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (countryOfOrigin != null) 'countryOfOrigin': countryOfOrigin,
        'isPopular': isPopular,
        'isElectric': isElectric,
        'isActive': isActive,
        'commonIssues': commonIssues,
        'history': history.map((h) => h.toJson()).toList(),
        if (productionStartYear != null)
          'productionStartYear': productionStartYear,
        if (productionEndYear != null) 'productionEndYear': productionEndYear,
      };

  // ─────────────────────────────────────────
  // ── copyWith ──
  // ─────────────────────────────────────────
  Car copyWith({
    String? id,
    String? brand,
    String? model,
    String? year,
    String? engine,
    String? region,
    String? fuelType,
    String? transmission,
    String? category,
    String? imageUrl,
    String? countryOfOrigin,
    bool? isPopular,
    bool? isElectric,
    bool? isActive,
    List<String>? commonIssues,
    List<CarHistoryEntry>? history,
    int? productionStartYear,
    int? productionEndYear,
  }) {
    return Car(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      engine: engine ?? this.engine,
      region: region ?? this.region,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      isPopular: isPopular ?? this.isPopular,
      isElectric: isElectric ?? this.isElectric,
      isActive: isActive ?? this.isActive,
      commonIssues: commonIssues ?? this.commonIssues,
      history: history ?? this.history,
      productionStartYear: productionStartYear ?? this.productionStartYear,
      productionEndYear: productionEndYear ?? this.productionEndYear,
    );
  }

  // ─────────────────────────────────────────
  // ── Getters محاسباتی ──
  // ─────────────────────────────────────────

  /// نام کامل بدون سال — برای نمایش در UI
  String get fullName {
    final b = brand.trim();
    final m = model.trim();
    if (b.isEmpty && m.isEmpty) return 'خودروی ناشناس';
    if (b.isEmpty) return m;
    if (m.isEmpty) return b;
    return '$b $m';
  }

  /// نام کامل با سال (اگر سال موجود باشد)
  String get fullNameWithYear {
    if (year.isEmpty) return fullName;
    return '$fullName ($year)';
  }

  /// توضیح کوتاه برای زیرعنوان
  String get description {
    final parts = <String>[];
    if (engine.isNotEmpty) parts.add(engine);
    if (fuelType != null && fuelType!.isNotEmpty) parts.add(fuelType!);
    if (transmission != null && transmission!.isNotEmpty) {
      parts.add(transmission!);
    }
    if (isElectric) parts.add('⚡ برقی');
    return parts.join(' · ');
  }

  /// آیا در حال تولید است
  bool get isInProduction => productionEndYear == null && isActive;

  /// بازه تولید برای نمایش
  String get productionRange {
    if (productionStartYear == null) return '';
    final end = productionEndYear?.toString() ?? 'تاکنون';
    return '$productionStartYear - $end';
  }

  /// آیا تصویر دارد
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  // ─────────────────────────────────────────
  // ── مقایسه ──
  // ─────────────────────────────────────────

  /// مقایسه بر اساس id
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Car && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Car(id=$id, name=$fullName, engine=$engine, isPopular=$isPopular)';

  // ─────────────────────────────────────────
  // ── توابع کمکی private ──
  // ─────────────────────────────────────────

  static String _str(dynamic value) =>
      value == null ? '' : value.toString().trim();

  static bool _bool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return defaultValue;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.isNotEmpty) return [raw.trim()];
    return [];
  }

  static List<CarHistoryEntry> _parseHistory(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CarHistoryEntry.fromJson)
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── مدل تاریخچه خودرو ──
// ─────────────────────────────────────────────────────────────────────────────
class CarHistoryEntry {
  final String id;
  final String title;
  final String? description;
  final DateTime? date;
  final String? type; // 'repair', 'recall', 'update', ...

  const CarHistoryEntry({
    required this.id,
    required this.title,
    this.description,
    this.date,
    this.type,
  });

  factory CarHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime? date;
    final dateStr = json['date'] as String?;
    if (dateStr != null) {
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {}
    }

    return CarHistoryEntry(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      date: date,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        if (date != null) 'date': date!.toIso8601String(),
        if (type != null) 'type': type,
      };

  @override
  String toString() => 'CarHistoryEntry(id=$id, title=$title, type=$type)';
}

// ─────────────────────────────────────────────────────────────────────────────
// ── دسته‌بندی خودرو ──
// ─────────────────────────────────────────────────────────────────────────────
enum CarCategory {
  sedan,
  suv,
  hatchback,
  pickup,
  van,
  coupe,
  convertible,
  wagon,
  other;

  String get label => switch (this) {
        CarCategory.sedan => 'سدان',
        CarCategory.suv => 'شاسی‌بلند',
        CarCategory.hatchback => 'هاچ‌بک',
        CarCategory.pickup => 'وانت',
        CarCategory.van => 'ون',
        CarCategory.coupe => 'کوپه',
        CarCategory.convertible => 'کابریولت',
        CarCategory.wagon => 'واگن',
        CarCategory.other => 'سایر',
      };

  /// پارس از رشته JSON
  static CarCategory fromString(String? value) {
    if (value == null) return CarCategory.other;
    return CarCategory.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => CarCategory.other,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── نوع سوخت ──
// ─────────────────────────────────────────────────────────────────────────────
enum FuelType {
  gasoline,
  diesel,
  cng,
  electric,
  hybrid,
  lpg;

  String get label => switch (this) {
        FuelType.gasoline => 'بنزینی',
        FuelType.diesel => 'دیزل',
        FuelType.cng => 'گاز سوز',
        FuelType.electric => 'برقی',
        FuelType.hybrid => 'هیبریدی',
        FuelType.lpg => 'گاز مایع',
      };

  static FuelType fromString(String? value) {
    if (value == null) return FuelType.gasoline;
    return FuelType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => FuelType.gasoline,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── نوع گیربکس ──
// ─────────────────────────────────────────────────────────────────────────────
enum TransmissionType {
  manual,
  automatic,
  cvt,
  dct;

  String get label => switch (this) {
        TransmissionType.manual => 'دستی',
        TransmissionType.automatic => 'اتوماتیک',
        TransmissionType.cvt => 'CVT',
        TransmissionType.dct => 'دوکلاچه',
      };

  static TransmissionType fromString(String? value) {
    if (value == null) return TransmissionType.manual;
    return TransmissionType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => TransmissionType.manual,
    );
  }
}
