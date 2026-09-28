class BazaarPurchaseVerification {
  const BazaarPurchaseVerification({
    required this.productId,
    required this.orderId,
    required this.purchaseToken,
  });

  final String productId;
  final String orderId;
  final String purchaseToken;
}
