# برندینگ — مکانیک هوشمند

## هویت

| مورد | مقدار |
|------|--------|
| نام فارسی | مکانیک هوشمند |
| نام انگلیسی | Smart Mechanic |
| کوتاه | Smart Mec |
| شعار | عیب‌یابی هوشمند خودرو |
| پکیج | `ir.smartmec.app` |
| حس برند | قابل‌اعتماد · مدرن · فنیِ دوستانه |

## پالت رنگ

| نقش | رنگ | هگز |
|-----|------|-----|
| کهربایی اصلی | Amber | `#FFC107` |
| نارنجی CTA | Orange | `#FF9800` |
| هایلایت | Amber Light | `#FFD54F` |
| پس‌زمینه دارک | Dark BG | `#0D0D12` |
| سطح | Dark Surface | `#1A1A24` |
| روشن | Light BG | `#F5F5FA` |

کد منبع: `lib/theme/brand.dart`

## آیکون و لوگو

فایل‌های منبع در `assets/branding/`:

| فایل | کاربرد |
|------|--------|
| `app_icon.svg` | آیکون اپ (۱۰۲۴×۱۰۲۴ مفهومی) |
| `logo_horizontal.svg` | لوگو افقی (سایت، هدر، استور) |
| `splash_mark.svg` | علامت اسپلش |

### مفهوم بصری آیکون
- پس‌زمینه دارک گرد
- حلقه کهربایی
- آچار هندسی + موج صدا (تحلیل موتور) + نقطه AI

### تولید PNG برای لانچر

1. SVG را به PNG ۱۰۲۴×۱۰۲۴ تبدیل کنید (Figma / Inkscape / [svg2png](https://svgtopng.com)):
   ```bash
   # با Inkscape
   inkscape assets/branding/app_icon.svg -w 1024 -h 1024 -o assets/branding/app_icon.png
   ```
2. وابستگی را اضافه و اجرا کنید:
   ```bash
   flutter pub get
   dart run flutter_launcher_icons
   ```
3. برای اسپلش (اختیاری):
   ```bash
   dart run flutter_native_splash:create
   ```

تنظیمات در `pubspec.yaml` بخش `flutter_launcher_icons` آماده است.

## فونت

- UI: **Vazirmatn** (`google_fonts`)
- استور / بنر: همان یا ایران‌سنس در صورت دسترسی

## لحن نوشتار

- آرام، شفاف، بدون اغراق
- تشخیص = راهنما، نه حکم قطعی
- اعلان‌ها بدون فشار فروش

## شبکه‌ها

- وب: https://smart-mec.ir
- اینستاگرام: @smart_mec_app
- تلگرام: t.me/smart_mec_app
- ایمیل: support@smart-mec.ir

## چک‌لیست استور

- [ ] `app_icon.png` ۱۰۲۴×۱۰۲۴
- [ ] اجرای `flutter_launcher_icons`
- [ ] Feature graphic ۱۰۲۴×۵۰۰
- [ ] ۳–۵ اسکرین‌شات با کپشن فارسی
- [ ] توضیح کوتاه + بلند استور هم‌راستا با شعار
