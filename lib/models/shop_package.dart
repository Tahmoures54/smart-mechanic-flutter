/// مدل بسته فروشگاهی — شناسه‌ها باید با PRODUCTS بک‌اند یکی باشند
class ShopPackage {
  final String id;
  final String title;
  final String subtitle;
  final int priceToman;
  final int? compareAtPriceToman;
  final int? credits;
  final int? days;
  final bool isGold;
  final bool isPopular;
  final bool isBestValue;
  final List<String> benefits;

  factory ShopPackage.fromJson(Map<String, dynamic> json) {
    final creditsRaw = json['credits'];
    final daysRaw = json['days'];
    final priceRaw = json['price'];
    final compareRaw = json['compareAtPrice'] ?? json['originalPrice'];
    final badge = (json['badge'] ?? '').toString();
    final id = (json['id'] ?? '').toString();
    final title = (json['title'] ?? json['name'] ?? id).toString();
    final subtitle = (json['subtitle'] ?? '').toString();
    return ShopPackage(
      id: id, title: title, subtitle: subtitle,
      priceToman: priceRaw is num ? priceRaw.round() : int.tryParse(priceRaw?.toString() ?? '') ?? 0,
      compareAtPriceToman: compareRaw is num ? compareRaw.round() : int.tryParse(compareRaw?.toString() ?? ''),
      credits: creditsRaw is num && creditsRaw > 0 ? creditsRaw.round() : null,
      days: daysRaw is num && daysRaw > 0 ? daysRaw.round() : null,
      isGold: (json['goldenDays'] is num && (json['goldenDays'] as num) > 0) || id.startsWith('gold_'),
      isPopular: json['highlight'] == true || badge.contains('محبوب'),
      isBestValue: badge.contains('ارزش') || badge.contains('به‌صرفه'),
      benefits: <String>[
        if (creditsRaw is num && creditsRaw > 0) '${creditsRaw.round()} بار عیب‌یابی هوشمند',
        if (daysRaw is num && daysRaw > 0) '${daysRaw.round()} روز دسترسی',
        if (json['monthlyLimit'] is num && (json['monthlyLimit'] as num) > 0) 'سقف ماهانه: ${(json['monthlyLimit'] as num).round()} عیب‌یابی',
        if (subtitle.isNotEmpty) subtitle,
      ],
    );
  }
  const ShopPackage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceToman,
    this.compareAtPriceToman,
    this.credits,
    this.days,
    this.isGold = false,
    this.isPopular = false,
    this.isBestValue = false,
    this.benefits = const [],
  });

  int? get unitPrice {
    if (credits != null && credits! > 0) {
      return (priceToman / credits!).round();
    }
    if (days != null && days! > 0) {
      return (priceToman / days!).round();
    }
    return null;
  }
}

/// Fallback catalog used only when the backend catalog cannot be loaded.
const shopPackages = <ShopPackage>[
  ShopPackage(id: 'credit_5', title: '۵ عیب‌یابی', subtitle: 'شروع سریع', priceToman: 49000, compareAtPriceToman: 65000, credits: 5),
  ShopPackage(id: 'credit_10', title: '۱۰ عیب‌یابی', subtitle: 'بسته کاربردی', priceToman: 89000, compareAtPriceToman: 120000, credits: 10),
  ShopPackage(id: 'credit_20', title: '۲۰ عیب‌یابی', subtitle: 'انتخاب اکثر راننده‌ها', priceToman: 149000, compareAtPriceToman: 200000, credits: 20, isPopular: true),
  ShopPackage(id: 'credit_50', title: '۵۰ عیب‌یابی', subtitle: 'به‌صرفه‌ترین واحد', priceToman: 299000, compareAtPriceToman: 400000, credits: 50, isBestValue: true),
  ShopPackage(id: 'credit_100', title: '۱۰۰ عیب‌یابی', subtitle: 'ویژه پرمصرف', priceToman: 499000, compareAtPriceToman: 700000, credits: 100),
  ShopPackage(id: 'gold_monthly', title: '۳۰ روز طلایی', subtitle: 'تا ۱۰۰ عیب‌یابی در ماه', priceToman: 179000, compareAtPriceToman: 199000, days: 30, isGold: true),
  ShopPackage(id: 'gold_quarterly', title: '۹۰ روز طلایی', subtitle: 'سه ماه دسترسی طلایی', priceToman: 449000, compareAtPriceToman: 537000, days: 90, isGold: true),
  ShopPackage(id: 'gold_yearly', title: '۳۶۵ روز طلایی', subtitle: 'یک سال دسترسی طلایی', priceToman: 1290000, compareAtPriceToman: 2148000, days: 365, isGold: true),
];