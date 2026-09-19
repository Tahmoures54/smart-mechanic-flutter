import 'package:flutter_test/flutter_test.dart';

import 'package:smart_mechanic/models/shop_package.dart';

void main() {
  group('پلن‌های فروش — سیاست قیمت‌گذاری 1.3.0', () {
    test('قیمت مبنا: هیچ بسته‌ای گران‌تر از ۱٫۹۹۹ تومان برای هر عیب‌یابی نیست', () {
      const anchor = 1999;
      for (final pkg in shopPackages) {
        final unit = pkg.bestCaseUnitPrice ?? pkg.unitPrice;
        expect(
          unit,
          lessThanOrEqualTo(anchor),
          reason: 'واحد قیمت «${pkg.title}» از قیمت مبنا ۱۹۹۹ تومان بیشتر است',
        );
      }
    });

    test('تخفیف پلکانی: بستهٔ بزرگ‌تر هرگز گران‌ترِ واحد نیست', () {
      final creditPacks = shopPackages.where((p) => p.credits != null).toList()
        ..sort((a, b) => a.credits!.compareTo(b.credits!));

      for (var i = 1; i < creditPacks.length; i++) {
        final smaller = creditPacks[i - 1].unitPrice!;
        final larger = creditPacks[i].unitPrice!;
        expect(
          larger,
          lessThanOrEqualTo(smaller),
          reason:
              'واحد قیمت «${creditPacks[i].title}» نباید از بستهٔ کوچک‌تر بیشتر باشد',
        );
      }
    });

    test('اشتراک‌های طلایی سقف مصرف منصفانه دارند (نامحدود واقعی ممنوع)', () {
      final golds = shopPackages.where((p) => p.isGold).toList();
      expect(golds, isNotEmpty);
      for (final gold in golds) {
        expect(gold.dailyCap, greaterThan(0),
            reason: '«${gold.title}» سقف روزانه ندارد');
        expect(gold.periodCap, greaterThan(0),
            reason: '«${gold.title}» سقف دوره ندارد');
        // سقف دوره با مدت اشتراک سازگار باشد.
        expect(gold.periodCap!, lessThanOrEqualTo(gold.dailyCap! * gold.days!),
            reason: '«${gold.title}»: سقف دوره از (سقف روزانه × روزها) بیشتر است');
      }
    });

    test('قیمت مقایسه‌ای (خط‌خورده) همیشه از قیمت واقعی بیشتر است', () {
      for (final pkg in shopPackages) {
        final compare = pkg.compareAtPriceToman;
        if (compare == null) continue;
        expect(compare, greaterThan(pkg.priceToman),
            reason: '«${pkg.title}»: قیمت مقایسه‌ای نامعتبر است');
      }
    });

    test('شناسه‌ها یکتا و هم‌تراز با PRICING.md هستند', () {
      final ids = shopPackages.map((p) => p.id).toSet();
      expect(ids.length, shopPackages.length);
      expect(
        ids,
        containsAll(<String>[
          'credit_10',
          'credit_35',
          'credit_90',
          'gold_monthly',
          'gold_quarterly',
        ]),
      );
    });

    test('بج‌های محبوب/بیشترین‌صرفه هر کدام فقط به یک بسته داده شده', () {
      expect(
        shopPackages.where((p) => p.isPopular).length,
        1,
        reason: 'فقط یک بسته باید «محبوب» باشد',
      );
      expect(
        shopPackages.where((p) => p.isBestValue).length,
        1,
        reason: 'فقط یک بسته باید «بیشترین صرفه» باشد',
      );
    });

    test('بسته‌های اعتباری بدون انقضا، اشتراک‌ها با مدت مشخص‌اند', () {
      for (final pkg in shopPackages) {
        if (pkg.isGold) {
          expect(pkg.days, isNotNull);
          expect(pkg.credits, isNull);
        } else {
          expect(pkg.credits, isNotNull);
          expect(pkg.days, isNull);
        }
      }
    });
  });
}
