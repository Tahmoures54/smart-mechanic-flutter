# 🚗 مکانیک هوشمند (Smart Mechanic)

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.4+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API_24+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue?style=for-the-badge)](RELEASE.md)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**عیب‌یابی هوشمند خودرو با کمک هوش مصنوعی، تحلیل صدا و نقشه تعمیرگاه‌های نزدیک**

[راهنمای انتشار](RELEASE.md) · [حریم خصوصی](PRIVACY.md) · [سلب مسئولیت](DISCLAIMER.md)

</div>

---

## ⚠️ سلب مسئولیت

> اپلیکیشن «مکانیک هوشمند» یک ابزار **کمکی و اطلاعاتی** است.  
> تشخیص‌ها **جایگزین نظر مکانیک حرفه‌ای** نیستند.

متن کامل: [DISCLAIMER.md](DISCLAIMER.md)

---

## ✨ ویژگی‌ها

| ویژگی | توضیح |
|-------|--------|
| 🧠 عیب‌یابی با AI | تشخیص مشکل، علل و راه‌حل |
| 🎤 تحلیل صدای موتور | RMS، فرکانس غالب، طیف |
| 📍 تعمیرگاه نزدیک | Google Places + نقشه |
| 🔐 ورود OTP | احراز هویت موبایل |
| 💳 اعتبار و اشتراک | بسته اعتباری + طلایی |
| 👥 سیستم معرفی | کد معرف و برداشت |
| 📋 تاریخچه | ذخیره عیب‌یابی‌ها |
| 🌙 تم تاریک/روشن | فونت وزیرمتن |

---

## 🧱 معماری

```
lib/
├── constants.dart
├── main.dart
├── models/          # Car, Diagnostic, AudioFeatures
├── providers/       # Auth, Theme, Locale
├── screens/         # Home, Chat, Record, History, ...
├── services/        # API, AI, Audio, Map, SoundAnalyzer
└── widgets/
```

**State:** Provider · **Storage:** Hive + SecureStorage · **Package:** `ir.smartmec.app`

---

## 🚀 اجرا

```bash
git clone https://github.com/Tahmoures54/smart-mechanic-flutter.git
cd smart-mechanic-flutter
flutter pub get
flutter run
```

---

## 📦 انتشار

جزئیات کامل در [RELEASE.md](RELEASE.md).

**خلاصه:**
1. Secrets را در GitHub تنظیم کنید (keystore + Google Maps)
2. از Actions → **Build Flutter APK** بیلد بگیرید
3. APK یا AAB را دانلود و منتشر کنید

```bash
# بیلد محلی
flutter build apk --release --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

---

## 📄 مجوز

[MIT](LICENSE)
