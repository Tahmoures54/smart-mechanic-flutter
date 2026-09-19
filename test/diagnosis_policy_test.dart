import 'package:flutter_test/flutter_test.dart';

import 'package:smart_mechanic/constants.dart';

void main() {
  group('DiagnosisPolicy', () {
    test('withDirective دستور سیاست را به شرح مشکل اضافه می‌کند', () {
      final out = DiagnosisPolicy.withDirective('عقب ماشینم صدا می‌دهد');

      expect(out, contains('عقب ماشینم صدا می‌دهد'));
      expect(out, contains('دستور اپلیکیشن'));
      expect(out, contains('هیچ سؤالی نپرس'));
      // متن کاربر اول می‌آید و دستور در انتها است.
      expect(out.startsWith('عقب ماشینم'), isTrue);
      expect(out.endsWith(']'), isTrue);
    });

    test('متن خیلی بلند بدون دستور ارسال می‌شود (احترام به بودجهٔ طول)', () {
      final long = 'ک' * 800;
      expect(DiagnosisPolicy.withDirective(long), long);
    });

    test('stripDirective دستور را برای نمایش حذف می‌کند', () {
      final payload = DiagnosisPolicy.withDirective('شرح مشکل کاربر');
      final clean = DiagnosisPolicy.stripDirective(payload);

      expect(clean, 'شرح مشکل کاربر');
      expect(clean.contains('دستور اپلیکیشن'), isFalse);
    });

    test('stripDirective روی متنی بدون دستور بی‌خطر است', () {
      expect(DiagnosisPolicy.stripDirective('متن معمولی'), 'متن معمولی');
    });

    test('پیشنهادهای ادامهٔ گفتگو خالی نیستند', () {
      expect(DiagnosisPolicy.followUpSuggestions, isNotEmpty);
      expect(DiagnosisPolicy.encouragementText, isNotEmpty);
    });
  });
}
