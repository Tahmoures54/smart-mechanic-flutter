import 'package:cafebazaar_billing/cafebazaar_billing.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'store_config.dart';

class BazaarPurchaseResult {
  const BazaarPurchaseResult({
    required this.productId,
    required this.orderId,
    required this.purchaseToken,
  });

  final String productId;
  final String orderId;
  final String purchaseToken;
}

class BazaarBillingService {
  BazaarBillingService._();
  static final BazaarBillingService instance = BazaarBillingService._();

  bool _connected = false;

  Future<void> connect() async {
    if (!StoreConfig.isBazaar || _connected) return;

    await CafeBazaarBilling.connect(
      StoreConfig.bazaarRsaPublicKey,
      onSucceed: () => _connected = true,
      onFailed: () => _connected = false,
      onDisconnected: () => _connected = false,
    );

    _connected = true;
  }

  Future<BazaarPurchaseResult> purchase({
    required String productId,
    required String payload,
    required ApiService api,
    required String authToken,
    String? garageId,
  }) async {
    if (!StoreConfig.isBazaar) {
      throw const ApiException(400, 'پرداخت بازار فقط در نسخه کافه‌بازار فعال است.');
    }

    await connect();

    try {
      final info = await CafeBazaarBilling.purchase(
        productId,
        payload: payload,
      );

      final verified = await api.verifyBazaarPurchase(
        authToken,
        productId: info.productId,
        purchaseToken: info.purchaseToken,
        orderId: info.orderId,
        packageName: info.packageName,
        payload: info.payload,
        garageId: garageId,
      );

      await CafeBazaarBilling.consume(info.purchaseToken);

      return BazaarPurchaseResult(
        productId: verified.productId,
        orderId: verified.orderId,
        purchaseToken: verified.purchaseToken,
      );
    } on PlatformException catch (e) {
      if (e.code == 'PURCHASE_CANCELLED') {
        throw const ApiException(499, 'پرداخت لغو شد.');
      }
      throw ApiException(502, e.message ?? 'پرداخت کافه‌بازار ناموفق بود.');
    }
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    try {
      await CafeBazaarBilling.disconnect();
    } finally {
      _connected = false;
    }
  }
}
