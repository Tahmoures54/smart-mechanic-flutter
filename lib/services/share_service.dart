import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';

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

  /// دعوت کوتاه و طبیعی برای فرستادن به یک دوست یا همکار.
  /// اگر کد معرف کاربر موجود باشد، به پیام اضافه می‌شود تا اعتبار معرف
  /// به حساب دعوت‌کننده واریز شود.
  static String supportInvite({String? referralCode}) {
    final referral = (referralCode != null && referralCode.isNotEmpty)
        ? '\n\nبا کد معرف من ثبت‌نام کن و اعتبار هدیه بگیر:\n🎁 $referralCode'
        : '';
    return 'قبل از رفتن به تعمیرگاه این بررسی اولیه را امتحان کن 🔧\n'
        'مشکل ماشینت را بنویس یا صدای موتور را بفرست؛ یک سرنخ و چند سؤال کاربردی برای ادامه بررسی بگیر.\n\n'
        '$websiteUrl'
        '$referral';
  }

  static Future<void> contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: Constants.supportEmail,
      queryParameters: const {
        'subject': 'پیشنهاد برای مکانیک هوشمند',
        'body': 'سلام، پیشنهاد یا بازخورد من درباره مکانیک هوشمند:\n\n',
      },
    );
    final opened = await launchUrl(uri);
    if (!opened) throw StateError('برنامه ایمیل باز نشد');
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
