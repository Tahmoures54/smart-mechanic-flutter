/// مدل بسته فروشگاهی — شناسه‌ها باید با PRODUCTS بک‌اند یکی باشند.
///
/// ⚠️ همگام‌سازی با بک‌اند: مقدار اعتبارِ واریزی و سقف‌های مصرف اشتراک
/// طلایی سمت سرور اعمال می‌شوند. جدول دقیق PRODUCTS در فایل PRICING.md
/// (ریشهٔ ریپو) نگه‌داری می‌شود؛ هر تغییری اینجا، آنجا هم باید اعمال شود.
///
/// ─── سیاست قیمت‌گذاری (نسخهٔ 1.3.0) ───
/// • قیمت مبنا: حدود ۱٫۹۹۹ تومان برای هر عیب‌یابی.
/// • بسته‌های بزرگ‌تر، به‌ازای هر عیب‌یابی ارزان‌تر می‌شوند (تخفیف پلکانی) —
///   واحد قیمت بین بسته‌ها هرگز صعودی نیست.
/// • هیچ بسته‌ای «نامحدود واقعی» نیست؛ اشتراک‌های طلایی سقف مصرف منصفانه
///   دارند ([dailyCap] و [periodCap]) تا هزینهٔ سرور کنترل‌شده بماند و
///   کیفیت سرویس برای همه حفظ شود.
class ShopPackage {
  final String id;
  final String title;
  final String subtitle;
  final int priceToman;
  final int? compareAtPriceToman;
  final int? credits;
  final int? days;

  /// سقف مصرف منصفانهٔ اشتراک: حداکثر عیب‌یابی در روز (فقط بسته‌های طلایی).
  final int? dailyCap;

  /// سقف مصرف منصفانهٔ اشتراک: حداکثر کل عیب‌یابی در طول دوره.
  final int? periodCap;

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
    final dailyCapRaw = json['dailyCap'];
    final periodCapRaw = json['periodCap'];
    return ShopPackage(
      id: id,
      title: title,
      subtitle: subtitle,
      priceToman: priceRaw is num ? priceRaw.round() : int.tryParse(priceRaw?.toString() ?? '') ?? 0,
      compareAtPriceToman: compareRaw is num ? compareRaw.round() : int.tryParse(compareRaw?.toString() ?? ''),
      credits: creditsRaw is num && creditsRaw > 0 ? creditsRaw.round() : null,
      days: daysRaw is num && daysRaw > 0 ? daysRaw.round() : null,
      dailyCap: dailyCapRaw is num && dailyCapRaw > 0 ? dailyCapRaw.round() : null,
      periodCap: periodCapRaw is num && periodCapRaw > 0 ? periodCapRaw.round() : null,
      isGold: (json['goldenDays'] is num && (json['goldenDays'] as num) > 0) || id.startsWith('gold_'),
      isPopular: json['highlight'] == true || badge.contains('محبوب'),
      isBestValue: badge.contains('ارزش') || badge.contains('به‌صرفه'),
      benefits: <String>[
        if (creditsRaw is num && creditsRaw > 0) creditsRaw.round().toString() + ' بار عیب‌یابی هوشمند',
        if (daysRaw is num && daysRaw > 0) daysRaw.round().toString() + ' روز دسترسی',
        if (dailyCapRaw is num && dailyCapRaw > 0) 'سقف روزانه: ' + dailyCapRaw.round().toString() + ' عیب‌یابی',
        if (periodCapRaw is num && periodCapRaw > 0) 'سقف دوره: ' + periodCapRaw.round().toString() + ' عیب‌یابی',
        if (json['monthlyLimit'] is num && (json['monthlyLimit'] as num) > 0) 'سقف ماهانه: ' + (json['monthlyLimit'] as num).round().toString() + ' عیب‌یابی',
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
    this.dailyCap,
    this.periodCap,
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

  /// «اگر سقف مصرف منصفانه کاملاً استفاده شود، هر عیب‌یابی چند در می‌آید؟»
  /// برای اشتراک‌های طلایی — عددی برای مقایسهٔ منصفانه با بسته‌های اعتباری.
  int? get bestCaseUnitPrice {
    if (periodCap == null || periodCap! <= 0) return null;
    return (priceToman / periodCap!).round();
  }
}

/// لیست بسته‌ها — هم‌تراز با smart-mec-backend PRODUCTS
/// (تغییر هر ردیف = به‌روزرسانی PRICING.md و PRODUCTS سمت سرور).
const shopPackages = <ShopPackage>[

  // ── بسته‌های اعتباری (قیمت مبنا: ۱٫۹۹۹ تومان برای هر عیب‌یابی) ──
  ShopPackage(
    id: 'credit_10',
    title: '۱۰ عیب‌یابی',
    subtitle: 'شروع مطمئن',
    priceToman: 19990,
    compareAtPriceToman: 26000,
    credits: 10,
    benefits: [
      '۱۰ بار عیب‌یابی هوشمند — هر کدام ۱٫۹۹۹ تومان',
      'مناسب اولین تجربه و مشکلات گاه‌به‌گاه',
      'بدون تاریخ انقضا',
    ],
  ),
  ShopPackage(
    id: 'credit_35',
    title: '۳۵ عیب‌یابی',
    subtitle: 'انتخاب اکثر کاربران',
    priceToman: 59000,
    compareAtPriceToman: 69000,
    credits: 35,
    isPopular: true,
    benefits: [
      '۳۵ بار عیب‌یابی — هر کدام حدود ۱٫۶۸۶ تومان',
      'حدود ۱۶٪ به‌صرفه‌تر از قیمت مبنا',
      'بدون تاریخ انقضا',
    ],
  ),
  ShopPackage(
    id: 'credit_90',
    title: '۹۰ عیب‌یابی',
    subtitle: 'پرطرفدارترین؛ حداکثر صرفه',
    priceToman: 129000,
    compareAtPriceToman: 179000,
    credits: 90,
    isBestValue: true,
    benefits: [
      '۹۰ بار عیب‌یابی — هر کدام حدود ۱٫۴۳۳ تومان',
      'حدود ۲۸٪ به‌صرفه‌تر از قیمت مبنا',
      'مناسب خودروهای چند‌گانه و خانواده',
      'بدون تاریخ انقضا',
    ],
  ),

  // ── اشتراک‌های طلایی («نامحدود» با سقف مصرف منصفانه) ──
  ShopPackage(
    id: 'gold_monthly',
    title: 'طلایی ۳۰ روزه',
    subtitle: 'اشتراک با سقف مصرف منصفانه',
    priceToman: 149000,
    compareAtPriceToman: 199000,
    days: 30,
    dailyCap: 10,
    periodCap: 150,
    isGold: true,
    benefits: [
      '۳۰ روز عیب‌یابی بدون نیاز به شارژ مکرر',
      'تا ۱۰ عیب‌یابی در روز — سقف دوره ۱۵۰ عیب‌یابی',
      'اگر سقف را کامل استفاده کنید، هر عیب‌یابی حدود ۹۹۳ تومان می‌شود',
      'اولویت پشتیبانی',
    ],
  ),
  ShopPackage(
    id: 'gold_quarterly',
    title: 'طلایی ۹۰ روزه',
    subtitle: 'به‌صرفه‌ترین اشتراک',
    priceToman: 399000,
    compareAtPriceToman: 537000,
    days: 90,
    dailyCap: 15,
    periodCap: 500,
    isGold: true,
    benefits: [
      '۹۰ روز عیب‌یابی بدون نیاز به شارژ مکرر',
      'تا ۱۵ عیب‌یابی در روز — سقف دوره ۵۰۰ عیب‌یابی',
      'اگر سقف را کامل استفاده کنید، هر عیب‌یابی حدود ۷۹۸ تومان می‌شود',
      'معادل حدود ۱۳۳ هزار تومان در ماه — حدود ۱۱٪ ارزان‌تر از ماهانه',
      'بهترین انتخاب تعمیرکاران',
    ],
  ),
];
