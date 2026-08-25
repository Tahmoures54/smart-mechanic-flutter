# 🚗 مکانیک هوشمند (Smart Mechanic)

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API_24+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue?style=for-the-badge)](RELEASE.md)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**عیب‌یابی هوشمند خودرو با کمک هوش مصنوعی، تحلیل صدا و نقشه تعمیرگاه‌های نزدیک**

[راهنمای انتشار](RELEASE.md) · [حریم خصوصی](PRIVACY.md) · [سلب مسئولیت](DISCLAIMER.md)

</div>

---

## ⚠️ سلب مسئولیت

> اپلیکیشن «مکانیک هوشمند» یک ابزار **کمکی و اطلاعاتی** است.  
> تشخیص‌های ارائه‌شده **جایگزین نظر مکانیک حرفه‌ای** نیستند.

متن کامل: [DISCLAIMER.md](DISCLAIMER.md)

---

## ✨ ویژگی‌ها

| ویژگی | توضیح |
|-------|--------|
| 🧠 عیب‌یابی با AI | تشخیص مشکل، علل احتمالی و راه‌حل از طریق گفتگو |
| 🎤 تحلیل صدای موتور | استخراج RMS، فرکانس غالب، طیف فرکانسی |
| 📍 تعمیرگاه نزدیک | Google Places + نقشه |
| 🔐 ورود OTP | احراز هویت با شماره موبایل |
| 💳 اعتبار و اشتراک | بسته‌های اعتباری + اشتراک طلایی |
| 👥 سیستم معرفی | کد معرف، پاداش و برداشت |
| 📋 تاریخچه | ذخیره و مرور عیب‌یابی‌های قبلی |
| 🌙 تم تاریک/روشن | طراحی مدرن با فونت وزیرمتن |

---

## 🧱 معماری

```
lib/
├── constants.dart
├── main.dart
├── models/
│   ├── car.dart
│   ├── diagnostic.dart
│   ├── audio_features.dart
│   ├── chat_message.dart      # استخراج‌شده از chat_screen
│   └── shop_package.dart      # استخراج‌شده از shop_screen
├── providers/                 # Auth, Theme, Locale
├── screens/
│   ├── home_screen.dart       # + CarSelectorWidget مشترک
│   ├── chat_screen.dart
│   ├── shop_screen.dart
│   ├── payment_webview.dart   # استخراج‌شده از shop
│   └── ...
├── services/
├── theme/
│   └── app_theme.dart         # تم و رنگ‌های متمرکز
└── widgets/
    └── car_selector_widget.dart
```

- **State:** Provider  
- **Storage:** Hive + Secure Storage  
- **Package ID:** `ir.smartmec.app`

---

## 🚀 اجرا

```bash
git clone https://github.com/Tahmoures54/smart-mechanic-flutter.git
cd smart-mechanic-flutter
flutter pub get
dart run flutter_launcher_icons
flutter run
```

---

## 📦 انتشار

جزئیات: [RELEASE.md](RELEASE.md)

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

---

## 📄 مجوز

[MIT](LICENSE)
