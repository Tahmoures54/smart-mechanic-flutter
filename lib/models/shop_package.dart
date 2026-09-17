/// مدل بسته فروشگاهی — شناسه‌ها باید با PRODUCTS بک‌اند یکی باشند
class ShopPackage {
  final String id;
  final String title;
  final String subtitle;
  final int priceToman;
  final int? credits;
  final int? days;
  final bool isGold;
  final bool isPopular;
  final bool isBestValue;
  final List<String> benefits;

  const ShopPackage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceToman,
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

/// لیست بسته‌ها — هم‌تراز با smart-mec-backend PRODUCTS
const shopPackages = <ShopPackage>[
  ShopPackage(
    id: 'credit_5',
    title: '۵ عیب‌یابی',
    subtitle: 'شروع سریع',
    priceToman: 65000,
    credits: 5,
    benefits: [
      '۵ بار عیب‌یابی هوشمند',
      'مناسب تست اولیه',
      'بدون تاریخ انقضا',
    ],
  ),
  ShopPackage(
    id: 'credit_10',
    title: '۱۰ عیب‌یابی',
    subtitle: 'انتخاب اکثر کاربران',
    priceToman: 120000,
    credits: 10,
    isPopular: true,
    benefits: [
      '۱۰ بار عیب‌یابی هوشمند',
      'حدود ۲۰٪ به‌صرفه‌تر',
      'بدون تاریخ انقضا',
    ],
  ),
  ShopPackage(
    id: 'gold_monthly',
    title: 'طلایی ۳۰ روزه',
    subtitle: 'عیب‌یابی نامحدود',
    priceToman: 199000,
    days: 30,
    isGold: true,
    benefits: [
      'عیب‌یابی نامحدود ۳۰ روز',
      'اولویت پشتیبانی',
      'مناسب استفاده روزانه',
    ],
  ),
  ShopPackage(
    id: 'gold_quarterly',
    title: 'طلایی ۹۰ روزه',
    subtitle: 'به‌صرفه‌ترین اشتراک',
    priceToman: 499000,
    days: 90,
    isGold: true,
    isBestValue: true,
    benefits: [
      'عیب‌یابی نامحدود ۹۰ روز',
      'حدود ۱۶٪ تخفیف نسبت به ماهانه',
      'بهترین انتخاب تعمیرکاران',
    ],
  ),
];
