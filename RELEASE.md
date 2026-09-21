# 📦 راهنمای انتشار نهایی — مکانیک هوشمند

## خروجی بیلد

| فایل / Artifact | مخاطب |
|-----------------|--------|
| **`cafe-bazaar-release`** | بستهٔ آمادهٔ **کافه‌بازار** (APK + گواهی + اثرانگشت) |
| `app-release.apk` | نصب مستقیم / بازار (داخل artifact بالا هم هست) |
| `app-release.aab` | **Google Play** |
| `cafe-bazaar-certificate` | فقط گواهی و SHA1/SHA256 |

حداقل اندروید: API 24. فقط معماری `arm64-v8a`.

---

## پیش‌نیازها (الزامی قبل از انتشار بازار)

### ۱. کلید انتشار Play و بازار (یک‌بار)

همین کلید برای **هر دو فروشگاه** است. اگر گم شود، به‌روزرسانی ممکن نیست.

1. Actions → **Generate Play / Bazaar Upload Key** → Run workflow (**فقط یک‌بار**)
2. Artifact `play-bazaar-upload-key` را دانلود کنید
3. در **Settings → Secrets and variables → Actions** این‌ها را بگذارید:

| Secret | منبع |
|--------|--------|
| `RELEASE_KEYSTORE_BASE64` | کل محتوای `RELEASE_KEYSTORE.base64` |
| `RELEASE_KEYSTORE_PASSWORD` | از `github-secrets.txt` |
| `RELEASE_KEY_PASSWORD` | از `github-secrets.txt` |
| `RELEASE_KEY_ALIAS` | معمولاً `upload` |
| `GOOGLE_MAPS_API_KEY` | کلید Maps / Places |

فایل `.jks` و رمز را آفلاین در جای امن نگه دارید. **کلید جدید بعد از انتشار اول نسازید.**

یا محلی:

```bash
chmod +x scripts/generate_release_keystore.sh
./scripts/generate_release_keystore.sh secrets
```

### ۲. کلید Google Maps

1. [Google Cloud Console](https://console.cloud.google.com)
2. فعال‌سازی: Maps SDK for Android + Places API
3. محدودیت package: `ir.smartmec.app`
4. ذخیره در Secret `GOOGLE_MAPS_API_KEY`

### ۳. بک‌اند

- API production: `https://smart-mec.ir/api`
- OTP و پرداخت روی دستگاه واقعی تست شود

---

## نسخه فعلی

- **Version name:** `1.3.2`
- **Version code:** `8`
- **Package:** `ir.smartmec.app`

### تغییرات این نسخه
- پاسخ مستقیم‌تر عیب‌یابی
- بهبود کاتالوگ خودرو و تحلیل صدا
- کارت خرید پلن/اعتبار در صفحه اصلی
- هماهنگی نسخه با `pubspec.yaml`

---

## بیلد برای کافه‌بازار (پیشنهادی)

1. مطمئن شوید Secrets کلید ست شده (بخش پیش‌نیاز)
2. Actions → **Build Flutter APK** → **Run workflow** → `both` یا `apk`
3. بعد از موفقیت این artifacts را بگیرید:

| Artifact | محتوا |
|----------|--------|
| **`cafe-bazaar-release`** | `app-release.apk` + `upload-certificate.bin` + `.pem` + `fingerprints.txt` |
| `app-release-aab` | برای گوگل‌پلی |

4. در پنل [کافه‌بازار توسعه‌دهندگان](https://developers.cafebazaar.ir):
   - فایل **`app-release.apk`** را آپلود کنید
   - `versionCode` باید از نسخه قبلی بیشتر باشد
   - اگر پنل گواهی خواست: `upload-certificate.bin` یا مقادیر SHA از `fingerprints.txt`

> ⚠️ بدون Secrets کلید، بیلد دستی (Run workflow) **خطا می‌دهد**. روی push معمولی بدون کلید فقط CI با امضای debug ساخته می‌شود و برای بازار قابل قبول نیست.

### بیلد محلی

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
```

---

## چک‌لیست قبل از انتشار بازار

- [ ] Secrets کلید (`RELEASE_KEYSTORE_*`) ست شده
- [ ] Artifact **`cafe-bazaar-release`** ساخته شده (نه فقط debug APK)
- [ ] `versionCode` از نسخه قبلی بازار بیشتر است
- [ ] `flutter analyze` / `flutter test` بدون error
- [ ] OTP، پرداخت، صدا، نقشه روی دستگاه واقعی تست شده
- [ ] DISCLAIMER در اپ دیده می‌شود
- [ ] هیچ secret در کد hardcode نیست

---

## Google Play

1. دانلود `app-release.aab`
2. آپلود در Play Console + تصاویر و حریم خصوصی
3. Upload key = همان کلید `upload`

---

## پشتیبانی

- ایمیل: support@smart-mec.ir
- گزارش باگ: Issues همین ریپازیتوری
