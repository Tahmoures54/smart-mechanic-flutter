import 'dart:async';

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
  Future<void>? _connectionFuture;

  Future<void> connect() {
    if (!StoreConfig.isBazaar) {
      throw const ApiException(
        400,
        'پرداخت بازار فقط در نسخه کافه‌بازار فعال است.',
      );
    }
    if (_connected) return Future<void>.value();
    return _connectionFuture ??= _connect();
  }

  Future<void> _connect() async {
    final completer = Completer<void>();

    try {
      await CafeBazaarBilling.connect(
        StoreConfig.bazaarRsaPublicKey,
        onSucceed: () {
          _connected = true;
          if (!completer.isCompleted) completer.complete();
        },
        onFailed: () {
          _connected = false;
          if (!completer.isCompleted) {
            completer.completeError(
              const ApiException(
                503,
                'اتصال به سرویس پرداخت کافه‌بازار برقرار نشد.',
              ),
            );
          }
        },
        onDisconnected: () {
          _connected = false;
        },
      );

      // The plugin reports connection readiness through onSucceed. Do not mark
      // the service connected merely because connect() returned.
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const ApiException(
          504,
          'زمان اتصال به سرویس پرداخت کافه‌بازار تمام شد.',
        ),
      );
    } finally {
      _connectionFuture = null;
    }
  }

  Future<BazaarPurchaseResult> purchase({
    required String productId,
    required String payload,
    required ApiService api,
    required String authToken,
    String? garageId,
  }) async {
    if (!StoreConfig.isBazaar) {
      throw const ApiException(
        400,
        'پرداخت بازار فقط در نسخه کافه‌بازار فعال است.',
      );
    }

    await connect();

    try {
      final info = await CafeBazaarBilling.purchase(
        productId,
        payload: payload,
      );

      // The server is the source of truth. It validates the product, order,
      // package name and purchase token against Cafe Bazaar before granting
      // credits/access.
      final verified = await api.verifyBazaarPurchase(
        authToken,
        productId: info.productId,
        purchaseToken: info.purchaseToken,
        orderId: info.orderId,
        packageName: info.packageName,
        payload: info.payload,
        garageId: garageId,
      );

      // Consume only after the server has atomically granted the entitlement.
      // This prevents a failed server request from losing a paid purchase.
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
      throw ApiException(
        502,
        e.message ?? 'پرداخت کافه‌بازار ناموفق بود.',
      );
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
