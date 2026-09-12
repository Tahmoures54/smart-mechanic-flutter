# 📦 راهنمای انتشار نهایی — مکانیک هوشمند

## خروجی بیلد (یک APK برای گوشی‌های امروزی)

بیلد دیگر سه APK جدا (armeabi-v7a / arm64 / x86) نمی‌سازد.

| فایل | مخاطب |
|------|--------|
| `app-release.apk` | گوشی‌های امروزی ARM 64-bit + آپلود در **کافه‌بازار** |
| `app-release.aab` | **Google Play** (Play App Signing) |

حداقل اندروید: API 24. فقط معماری `arm64-v8a`.

---

## پیش‌نیازها

### ۱. کلید انتشار Play و بازار (یک‌بار)

همین کلید را برای **هر دو فروشگاه** استفاده کنید. اگر گم شود، به‌روزرسانی اپ ممکن نیست.

**روش پیشنهادی:** workflow **Generate Play / Bazaar Upload Key** را **فقط یک‌بار** از تب Actions اجرا کنید و artifact را دانلود کنید.

یا محلی:

```bash
chmod +x scripts/generate_release_keystore.sh
./scripts/generate_release_keystore.sh secrets
```

سپس در GitHub → Settings → Secrets and variables → Actions:

| Secret | منبع |
|--------|--------|
| `RELEASE_KEYSTORE_BASE64` | محتویات `RELEASE_KEYSTORE.base64` |
| `RELEASE_KEYSTORE_PASSWORD` | از `github-secrets.txt` |
| `RELEASE_KEY_ALIAS` | معمولاً `upload` |
| `RELEASE_KEY_PASSWORD` | از `github-secrets.txt` |
| `GOOGLE_MAPS_API_KEY` | کلید Google Maps / Places |

فایل‌های `.jks` و رمز را در گیت نگذارید. یک نسخه آفلاین در جای امن نگه دارید.

> اگر قبلاً کلیدی ساخته‌اید، کلید جدید نسازید؛ فروشگاه‌ها فقط همان کلید اول را می‌پذیرند.

### ۲. کلید Google Maps

1. در [Google Cloud Console](https://console.cloud.google.com) پروژه بسازید
2. APIهای زیر را فعال کنید:
   - Maps SDK for Android
   - Places API
3. کلید API بسازید و محدودیت package name روی `ir.smartmec.app` بگذارید
4. کلید را در Secrets ذخیره کنید

### ۳. بک‌اند

- آدرس production در `lib/constants.dart` بررسی شود
- HTTPS و CORS صحیح باشد
- OTP و پرداخت تست شوند

---

## مراحل انتشار

### نسخه فعلی
- **Version name:** `1.2.0`
- **Version code:** `3`
- **Package:** `ir.smartmec.app`

### بیلد از طریق GitHub Actions

1. به تب **Actions** بروید
2. workflow **Build Flutter APK** را انتخاب کنید
3. **Run workflow** → گزینه `both` (پیش‌فرض)
4. آرتیفکت‌ها:
   - `app-release-apk` → کافه‌بازار / نصب مستقیم
   - `app-release-aab` → Google Play

روی pull request فقط APK ساخته می‌شود تا CI سریع‌تر باشد.

### بیلد محلی

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
```

---

## چک‌لیست قبل از انتشار

- [ ] نسخه در `pubspec.yaml` و `Constants` یکسان است
- [ ] `enableLogging` در production خاموش است
- [ ] keystore واقعی (نه تست) در Secrets است
- [ ] کلید Google Maps محدود به package name است
- [ ] DISCLAIMER در اپ قابل مشاهده است
- [ ] OTP واقعی تست شده
- [ ] پرداخت / درگاه تست شده
- [ ] تحلیل صدا روی دستگاه واقعی تست شده
- [ ] نقشه و تعمیرگاه‌های نزدیک کار می‌کنند
- [ ] تم تاریک/روشن و RTL درست هستند
- [ ] هیچ secretی در کد hardcode نشده

---

## انتشار در فروشگاه‌ها

### Google Play
1. ساخت / دانلود `app-release.aab`
2. ساخت اپ در Google Play Console
3. آپلود AAB + تصاویر + توضیحات + سیاست حریم خصوصی
4. تکمیل پرسشنامه محتوا و رتبه‌بندی سنی
5. در Play App Signing، کلید آپلود همین `upload` است

### کافه‌بازار
1. دانلود `app-release.apk` (arm64)
2. آپلود در پنل بازار با **همان کلید امضا**
3. نسخه و versionCode باید از نسخه قبلی بیشتر باشد

### آپلود مستقیم
فایل `app-release.apk` را می‌توانید مستقیم توزیع کنید (مثلاً سایت رسمی).

---

## پشتیبانی

- ایمیل: support@smart-mec.ir
- گزارش باگ: Issues همین ریپازیتوری
