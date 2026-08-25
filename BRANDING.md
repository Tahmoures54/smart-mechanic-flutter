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
| `app_icon.svg` / `.png` | آیکون اپ (۱۰۲۴×۱۰۲۴) |
| `app_icon_foreground.png` | لایهٔ پیش‌زمینهٔ Adaptive |
| `logo.png` / `.svg` | لوگو افقی |
| `splash_mark.png` | علامت اسپلش |
| `banner.png` | بنر |

### مفهوم بصری آیکون
- پس‌زمینه دارک گرد
- حلقه کهربایی
- آچار هندسی + موج صدا (تحلیل موتور) + نقطه AI

### تولید آیکون لانچر (الزامی بعد از کلون)

منبع‌ها آماده است (`app_icon.png` و `app_icon_foreground.png`).
فولدرهای `mipmap` در اندروید باید ساخته شوند:

```bash
flutter pub get
dart run flutter_launcher_icons
# اختیاری — اسپلش:
dart run flutter_native_splash:create
```

یا بدون Flutter SDK:

```bash
python3 tool/apply_icons.py   # نیاز به tool/icons_*.json
```

تنظیمات در `pubspec.yaml` → `flutter_launcher_icons`:
- `image_path`: `assets/branding/app_icon.png`
- `adaptive_icon_background`: `#0D0D12`
- `adaptive_icon_foreground`: `assets/branding/app_icon_foreground.png`

AndroidManifest: `android:icon` + `android:roundIcon` روی `@mipmap/ic_launcher(_round)`.
