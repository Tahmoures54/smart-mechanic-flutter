import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// متن‌ها و اکشن‌های اشتراک‌گذاری — یک منبع برای کل اپ
class ShareService {
  ShareService._();

  static const String websiteUrl = 'https://smart-mec.ir';
  static const String appName = 'مکانیک هوشمند';

  static String appPitch({String? referralCode}) {
    final referral = (referralCode != null && referralCode.isNotEmpty)
        ? '\n\nبا کد معرف من ثبت‌نام کن و اعتبار هدیه بگیر:\n🎁 $referralCode'
        : '';
    return '🚗 $appName — عیب‌یابی ماشین با هوش مصنوعی\n\n'
        'قبل از رفتن به تعمیرگاه، در چند ثانیه علت احتمالی مشکل را می‌فهمی؛ '
        'هم خیالت راحت‌تر می‌شود، هم کمتر هزینه الکی می‌دهی.\n'
        '$referral\n\n'
        'دانلود: $websiteUrl';
  }

  static String diagnosisShare({
    required String result,
    String? carName,
    String? year,
    String? referralCode,
  }) {
    final carLine = [
      if (carName != null && carName.isNotEmpty) carName,
      if (year != null && year.isNotEmpty) 'مدل $year',
    ].join(' · ');

    final header = carLine.isEmpty
        ? '🔧 نتیجه عیب‌یابی من با $appName:\n\n'
        : '🔧 نتیجه عیب‌یابی $carLine با $appName:\n\n';

    final referral = (referralCode != null && referralCode.isNotEmpty)
        ? '\n\nبا کد معرف $referralCode در $appName ثبت‌نام کن و اعتبار هدیه بگیر.'
        : '\n\nاپ $appName — عیب‌یابی خودرو با کمک AI\n$websiteUrl';

    return '$header$result$referral';
  }

  /// متن آماده برای وضعیت ۲۴ساعته واتساپ
  static String whatsappStatus({String? referralCode}) {
    final referral = (referralCode != null && referralCode.isNotEmpty)
        ? '\nکد معرف من: $referralCode'
        : '';
    return 'از وقتی «$appName» دارم، دیگه چشم‌بسته نمی‌رم تعمیرگاه 🔧\n'
        'عیب‌یابی ماشین با هوش مصنوعی — قبل از هزینه کردن، اول می‌فهمم.\n'
        '$websiteUrl$referral';
  }

  /// متن کوتاه برای بخش «درباره» / پروفایل واتساپ
  static String whatsappAbout() {
    return 'عیب‌یابی ماشین با $appName 🔧 $websiteUrl';
  }

  static Future<void> shareApp({String? referralCode}) {
    return Share.share(
      appPitch(referralCode: referralCode),
      subject: 'دعوت به $appName',
    );
  }

  static Future<void> shareDiagnosis({
    required String result,
    String? carName,
    String? year,
    String? referralCode,
  }) {
    return Share.share(
      diagnosisShare(
        result: result,
        carName: carName,
        year: year,
        referralCode: referralCode,
      ),
      subject: 'نتیجه عیب‌یابی خودرو',
    );
  }

  static Future<void> shareToWhatsApp(String text) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Share.share(text, subject: appName);
      }
    } catch (_) {
      await Share.share(text, subject: appName);
    }
  }

  static Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
