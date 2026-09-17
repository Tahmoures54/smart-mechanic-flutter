import 'package:flutter_test/flutter_test.dart';
import 'package:smart_mechanic/services/payment_flow.dart';

void main() {
  group('PaymentFlow.parseLaunch', () {
    test('reads paymentUrl from backend Zibal response', () {
      final launch = PaymentFlow.parseLaunch({
        'success': true,
        'paymentUrl': 'https://gateway.zibal.ir/start/998877',
      });
      expect(launch, isNotNull);
      expect(launch!.url, 'https://gateway.zibal.ir/start/998877');
      expect(launch.isMock, isFalse);
    });

    test('falls back to url for older payloads', () {
      final launch = PaymentFlow.parseLaunch({
        'url': 'https://gateway.zibal.ir/start/1',
      });
      expect(launch!.url, 'https://gateway.zibal.ir/start/1');
    });

    test('builds start URL from trackId when url is missing', () {
      final launch = PaymentFlow.parseLaunch({'trackId': 12345});
      expect(launch!.url, 'https://gateway.zibal.ir/start/12345');
      expect(launch.trackId, '12345');
    });

    test('reads nested data.paymentUrl', () {
      final launch = PaymentFlow.parseLaunch({
        'success': true,
        'data': {'paymentUrl': 'https://gateway.zibal.ir/start/7'},
      });
      expect(launch!.url, 'https://gateway.zibal.ir/start/7');
    });

    test('detects mock payments', () {
      final launch = PaymentFlow.parseLaunch({
        'success': true,
        'mock': true,
        'paymentUrl':
            'https://smart-mec.ir/api/purchase/verify?trackId=MOCK_ABC&success=1',
      });
      expect(launch!.isMock, isTrue);
    });

    test('returns null when no url or trackId', () {
      expect(PaymentFlow.parseLaunch({'success': true}), isNull);
    });
  });

  group('PaymentFlow.outcomeFromUrl', () {
    test('smartmec success deep link', () {
      expect(
        PaymentFlow.outcomeFromUrl('smartmec://success'),
        PaymentCallbackOutcome.success,
      );
    });

    test('smartmec failed deep link', () {
      expect(
        PaymentFlow.outcomeFromUrl('smartmec://failed'),
        PaymentCallbackOutcome.failed,
      );
    });

    test('Zibal cancel callback on verify URL', () {
      expect(
        PaymentFlow.outcomeFromUrl(
          'https://smart-mec.ir/api/purchase/verify?productId=credit_5&success=0&trackId=99',
        ),
        PaymentCallbackOutcome.failed,
      );
    });

    test('Zibal paid callback on verify URL', () {
      expect(
        PaymentFlow.outcomeFromUrl(
          'https://smart-mec.ir/api/purchase/verify?productId=credit_5&success=1&trackId=99&status=2',
        ),
        PaymentCallbackOutcome.success,
      );
    });

    test('does not treat Zibal start page as a result', () {
      expect(
        PaymentFlow.outcomeFromUrl('https://gateway.zibal.ir/start/99'),
        isNull,
      );
    });

    test('detects deep link embedded in a page URL', () {
      expect(
        PaymentFlow.outcomeFromUrl(
          'https://smart-mec.ir/?next=smartmec://success',
        ),
        PaymentCallbackOutcome.success,
      );
    });
  });
}
