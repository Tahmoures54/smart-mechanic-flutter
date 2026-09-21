# 📦 راهنمای انتشار — مکانیک هوشمند

## فقط این ۴ Secret برای بازار لازم است

| Secret | از کجا |
|--------|--------|
| `RELEASE_KEYSTORE_BASE64` | فایل `RELEASE_KEYSTORE.base64` |
| `RELEASE_KEYSTORE_PASSWORD` | فایل `github-secrets.txt` |
| `RELEASE_KEY_PASSWORD` | همان فایل |
| `RELEASE_KEY_ALIAS` | معمولاً `upload` |

**Google Maps لازم نیست.** تعمیرگاه‌ها از دیتابیس خود اپ (`smart-mec.ir`) می‌آیند.

---

## مراحل ساده (۳ قدم)

### قدم ۱ — ساخت کلید (فقط یک‌بار در عمر اپ)

1. برو به: **Actions**
2. روی **Generate Play / Bazaar Upload Key** کلیک کن
3. **Run workflow** را بزن
4. صبر کن تا سبز شود → Artifact به نام `play-bazaar-upload-key` را **دانلود** کن
5. فایل zip را باز کن؛ داخلش این‌ها هست:
   - `RELEASE_KEYSTORE.base64`
   - `github-secrets.txt`
   - `play-bazaar-upload.jks` ← این را جایی امن نگه دار

### قدم ۲ — گذاشتن Secret در GitHub

1. برو به: **Settings → Secrets and variables → Actions**
2. **New repository secret** و چهار تا بساز:

| Name | Value |
|------|--------|
| `RELEASE_KEYSTORE_BASE64` | کل متن داخل `RELEASE_KEYSTORE.base64` را کپی کن (یک خط خیلی بلند) |
| `RELEASE_KEYSTORE_PASSWORD` | از داخل `github-secrets.txt` |
| `RELEASE_KEY_PASSWORD` | از داخل `github-secrets.txt` |
| `RELEASE_KEY_ALIAS` | بنویس: `upload` |

### قدم ۳ — ساخت APK بازار

1. برو به: **Actions → Build Flutter APK**
2. **Run workflow** (دکمه سمت راست)
3. گزینه `apk` یا `both`
4. صبر کن تا سبز شود
5. Artifact **`cafe-bazaar-release`** را دانلود کن
6. داخلش `app-release.apk` را در **پنل کافه‌بازار** آپلود کن

---

## نسخه فعلی

- **Version name:** `1.3.2`
- **Version code:** `8`
- **Package:** `ir.smartmec.app`

اگر قبلاً نسخه‌ای در بازار هست، `versionCode` باید از آن بیشتر باشد.

---

## نکته مهم

- کلید را **یک‌بار** بساز و برای همیشه نگه دار
- اگر کلید گم شود، آپدیت اپ در بازار ممکن نیست
- بیلد خودکار روی push بدون کلید فقط برای تست CI است و برای بازار قابل قبول نیست

---

## پشتیبانی

- ایمیل: support@smart-mec.ir
