# 🚗 مکانیک هوشمند (Smart Mechanic)

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.4+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API_24+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**عیب‌یابی هوشمند خودرو با کمک هوش مصنوعی، تحلیل صدا و نقشه تعمیرگاه‌های نزدیک**

</div>

---

## ⚠️ سلب مسئولیت

> **هشدار مهم:** اپلیکیشن «مکانیک هوشمند» یک ابزار **کمکی و اطلاعاتی** است.  
> تشخیص‌های ارائه‌شده به هیچ عنوان **قطعی، تخصصی یا جایگزین نظر مکانیک حرفه‌ای** نیستند.

| موضوع | توضیح |
|-------|--------|
| **مسئولیت استفاده** | هرگونه خسارت ناشی از اعتماد به نتایج، بر عهده کاربر است |
| **مشاوره تخصصی** | پیش از هر اقدام، با مکانیک متخصص مشورت کنید |
| **دقت اطلاعات** | مدل AI و تحلیل صدا ممکن است خطا کند |
| **منابع خارجی** | داده‌های نقشه از Google تأمین می‌شوند |

**متن کامل:** [DISCLAIMER.md](DISCLAIMER.md)

---

## ✨ ویژگی‌های کلیدی

| ویژگی | توضیح |
|-------|--------|
| 🧠 **عیب‌یابی با AI** | تشخیص مشکل، علل احتمالی و راه‌حل از طریق گفتگوی متنی |
| 🎤 **تحلیل صدای موتور** | استخراج RMS، فرکانس غالب، طیف فرکانسی و تشخیص ناهنجاری |
| 📍 **تعمیرگاه‌های نزدیک** | نمایش روی نقشه با Google Places API |
| 🔐 **ورود با OTP** | احراز هویت با شماره موبایل و کد یکبارمصرف |
| 💳 **اعتبار و اشتراک** | بسته‌های اعتباری و اشتراک طلایی نامحدود |
| 👥 **سیستم معرفی** | کد معرف، پاداش و برداشت درآمد |
| 📋 **تاریخچه** | ذخیره و مرور تمام عیب‌یابی‌های قبلی |
| 🌙 **تم تاریک/روشن** | طراحی مدرن با فونت وزیرمتن |

---

## 🧱 معماری پروژه

```
lib/
├── constants.dart              # کانفیگ محیط، endpointها، محدودیت‌ها
├── main.dart                   # نقطه ورود + تم + localization
├── models/
│   ├── audio_features.dart     # ویژگی‌های استخراج‌شده از صدا
│   ├── car.dart                # مدل خودرو + Enumها
│   └── diagnostic.dart         # مدل عیب‌یابی + وضعیت
├── providers/
│   ├── auth_provider.dart      # احراز هویت، اعتبار، پروفایل
│   ├── locale_provider.dart    # مدیریت زبان
│   └── theme_provider.dart     # مدیریت تم
├── screens/                    # صفحات اصلی اپ
├── services/
│   ├── ai_diagnostic_service.dart  # ساخت پرامپت + کش + retry
│   ├── api_service.dart            # ارتباط با بک‌اند
│   ├── audio_service.dart          # ضبط صدا با flutter_sound
│   ├── map_service.dart            # نقشه و مکان‌ها
│   └── sound_analyzer.dart         # FFT و استخراج ویژگی‌های صوتی
└── widgets/
```

**الگوی مدیریت state:** Provider  
**ذخیره‌سازی محلی:** Hive + SharedPreferences + FlutterSecureStorage

---

## 🔧 بهبودهای اخیر

- تکمیل و مدرن‌سازی `pubspec.yaml` (نسخه، environment، وابستگی‌ها)
- افزودن `analysis_options.yaml` با قوانین lint سخت‌گیرانه‌تر
- بهبود پرامپت AI (ساختارمندتر، احتیاط‌آمیزتر و کاربردی‌تر)
- تقویت `SoundAnalyzer` (پشتیبانی بهتر از WAV، محدودیت حافظه، هشدار فرمت فشرده)
- بهبود UX صفحه ضبط صدا (راهنما، نوار پیشرفت، حداقل/حداکثر مدت)
- به‌روزرسانی `structure.txt`

### محدودیت شناخته‌شده تحلیل صدا
فایل‌های AAC/M4A به صورت کامل دیکد نمی‌شوند و نتایج تقریبی هستند.  
برای دقت بالاتر در نسخه‌های بعدی پیشنهاد می‌شود:
- استفاده از `ffmpeg_kit_flutter` یا
- تغییر کدک ضبط به PCM/WAV

---

## 🚀 اجرای پروژه

```bash
# کلون
git clone https://github.com/Tahmoures54/smart-mechanic-flutter.git
cd smart-mechanic-flutter

# وابستگی‌ها
flutter pub get

# اجرا
flutter run
```

> برای بیلد ریلیز از workflow گیت‌هاب (`build-apk.yml`) استفاده کنید.

---

## 📝 لایسنس

MIT
