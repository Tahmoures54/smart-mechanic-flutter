/// اطلاعات تعمیرگاه‌هایی که با حساب فعلی ثبت شده‌اند.
/// وضعیت نمایش در چت از backend می‌آید و کلاینت نباید آن را حدس بزند.
class OwnedGarage {
  const OwnedGarage({
    required this.id,
    required this.name,
    this.city,
    this.phone,
    this.address,
    required this.lat,
    required this.lng,
    this.specialties = const [],
    this.chatStatus = 'none',
    this.showInChat = false,
    this.subscriptionTier = 'free',
    this.subscriptionExpiresAt,
    this.isActive = true,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String? city;
  final String? phone;
  final String? address;
  final double lat;
  final double lng;
  final List<String> specialties;
  final String chatStatus;
  final bool showInChat;
  final String subscriptionTier;
  final String? subscriptionExpiresAt;
  final bool isActive;
  final bool isVerified;

  factory OwnedGarage.fromJson(Map<String, dynamic> json) {
    final rawSpecialties = json['specialties'];
    final specialties = rawSpecialties is List
        ? rawSpecialties.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList()
        : rawSpecialties is String
            ? rawSpecialties
                .split(RegExp(r'[,،]'))
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
            : <String>[];

    return OwnedGarage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: _nullable(json['city']),
      phone: _nullable(json['phone']),
      address: _nullable(json['address']),
      lat: _number(json['lat'] ?? json['latitude']),
      lng: _number(json['lng'] ?? json['longitude']),
      specialties: specialties,
      chatStatus: json['chatStatus']?.toString() ?? 'none',
      showInChat: json['showInChat'] == true,
      subscriptionTier: json['subscriptionTier']?.toString() ?? 'free',
      subscriptionExpiresAt: _nullable(json['subscriptionExpiresAt']),
      isActive: json['isActive'] != false,
      isVerified: json['isVerified'] == true,
    );
  }

  static String? _nullable(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  bool get hasPromotion => subscriptionTier == 'silver' || subscriptionTier == 'gold';

  String get statusLabel {
    switch (chatStatus) {
      case 'pending_payment':
        return 'در انتظار پرداخت پکیج معرفی';
      case 'pending_review':
        return 'پرداخت شده؛ در صف تأیید ادمین';
      case 'approved':
        return 'تأیید شده؛ در چت عیب‌یابی نمایش داده می‌شود';
      case 'rejected':
        return 'درخواست معرفی توسط ادمین رد شده است';
      default:
        return 'ثبت شده؛ هنوز پکیج معرفی خریداری نشده است';
    }
  }

  String get tierLabel {
    switch (subscriptionTier) {
      case 'gold':
        return 'طلایی';
      case 'silver':
        return 'نقره‌ای';
      default:
        return 'بدون پکیج';
    }
  }
}
