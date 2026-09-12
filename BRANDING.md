# برندینگ — مکانیک هوشمند

## هویت

| مورد | مقدار |
|------|--------|
| نام فارسی | مکانیک هوشمند |
| نام انگلیسی | Smart Mechanic |
| کوتاه | Smart Mec |
| شعار | عیب‌یابی هوشمند خودرو |
| پکیج | `ir.smartmec.app` |
| حس برند | قابل‌اعتماد · فنی · قفلِ اطمینان + ابزار مکانیک |

منبع لوگو: `logo.png` در ریشهٔ مخزن (نشان دایره‌ای: چرخ‌دنده، قفل طلایی، پیچ‌گوشتی و آچار).

کد: `lib/theme/brand.dart` و ویجت `lib/widgets/brand_logo.dart`.

## پالت رنگ

| نقش | رنگ | هگز |
|-----|------|-----|
| طلایی برند | Gold | `#E4BA56` |
| طلایی روشن | Gold Light | `#F5DFB0` |
| طلایی تیره | Gold Dark | `#D6A330` |
| نارنجی CTA | Orange | `#FF9800` |
| پس‌زمینه دارک | Dark BG | `#0D0D12` |
| سطح | Dark Surface | `#1A1A24` |
| روشن | Light BG | `#F5F5FA` |

## آیکون و لوگو

فایل‌های تولیدشده در `assets/branding/` (از روی لوگوی ریشه):

| فایل | کاربرد |
|------|--------|
| `logo.png` | لوگو دایره‌ای داخل اپ (اسپلش، ورود، AppBar) |
| `logo_source.png` | کپی راستر اصلی ۱۲۸px |
| `app_icon.png` | آیکون لانچر ۱۰۲۴×۱۰۲۴ |
| `app_icon_foreground.png` | لایهٔ Adaptive (محدودهٔ امن) |
| `splash_mark.png` | علامت اسپلش با پس‌زمینه شفاف |
| `banner.png` | بنر گیت‌هاب / فروشگاه |
| `play_store_icon.png` | آیکون ۵۱۲px پلی‌استور |

### مفهوم بصری
- حلقه سفید روی پس‌زمینه زغالی
- چرخ‌دنده هشت‌دندانه (فنی بودن)
- قفل طلایی (اعتماد و امنیت داده)
- پیچ‌گوشتی و آچار (عیب‌یابی مکانیکی)

### تولید مجدد دارایی‌ها

```bash
python3 tool/generate_branding.py
flutter pub get
dart run flutter_launcher_icons
# اختیاری — اسپلش نیتیو:
dart run flutter_native_splash:create
```

تنظیمات در `pubspec.yaml` → `flutter_launcher_icons`:
- `image_path`: `assets/branding/app_icon.png`
- `adaptive_icon_background`: `#0D0D12`
- `adaptive_icon_foreground`: `assets/branding/app_icon_foreground.png`

AndroidManifest: `android:icon` = `@mipmap/ic_launcher` و `android:roundIcon` = `@mipmap/ic_launcher_round`.
