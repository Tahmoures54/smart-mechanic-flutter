# 📦 راهنمای انتشار نهایی — مکانیک هوشمند

## پیش‌نیازها

### ۱. Secrets در GitHub Repository

در Settings → Secrets and variables → Actions این موارد را اضافه کنید:

| Secret | توضیح |
|--------|--------|
| `RELEASE_KEYSTORE_BASE64` | کلید keystore به صورت base64 |
| `RELEASE_KEYSTORE_PASSWORD` | رمز keystore |
| `RELEASE_KEY_ALIAS` | نام alias (معمولاً `release`) |
| `RELEASE_KEY_PASSWORD` | رمز کلید |
| `GOOGLE_MAPS_API_KEY` | کلید Google Maps / Places |

> برای تولید keystore یک‌بار workflow به نام **Generate Release Keystore** را اجرا کنید.

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
- **Version name:** `1.0.0`
- **Version code:** `1`
- **Package:** `ir.smartmec.app`

### بیلد از طریق GitHub Actions

1. به تب **Actions** بروید
2. workflow **Build Flutter APK** را انتخاب کنید
3. **Run workflow** را بزنید
4. پس از اتمام، فایل APK را از Artifacts دانلود کنید

### بیلد محلی (اختیاری)

```bash
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build/symbols
# یا App Bundle برای Play Store:
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

---

## چک‌لیست قبل از انتشار

- [ ] نسخه در `pubspec.yaml` و `Constants` یکسان است
- [ ] `enableLogging` در production خاموش است
- [ ] keystore واقعی (نه تست) استفاده شده
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
1. ساخت `app-release.aab`
2. ساخت اپ در Google Play Console
3. آپلود AAB + تصاویر + توضیحات + سیاست حریم خصوصی
4. تکمیل پرسشنامه محتوا و رتبه‌بندی سنی

### آپلود مستقیم (APK)
فایل `app-release.apk` را می‌توانید مستقیم توزیع کنید (مثلاً سایت رسمی).

---

## پشتیبانی

- ایمیل: support@smart-mec.ir
- گزارش باگ: Issues همین ریپازیتوری
