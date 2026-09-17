/// Helpers for Zibal + Smart Mechanic payment URLs.
///
/// Backend contract (smart-mec-backend):
/// - POST /api/purchase → `{ success, paymentUrl, mock? }`
/// - Zibal then redirects to GET /api/purchase/verify?productId=...&success=&trackId=
/// - Verify HTML tries `smartmec://success` / `smartmec://failed`
library;

enum PaymentCallbackOutcome { success, failed }

class PaymentLaunchInfo {
  final String url;
  final bool isMock;
  final String? trackId;

  const PaymentLaunchInfo({
    required this.url,
    this.isMock = false,
    this.trackId,
  });
}

class PaymentFlow {
  PaymentFlow._();

  static const String gatewayStartBase = 'https://gateway.zibal.ir/start';
  static const String successDeepLink = 'smartmec://success';
  static const String failedDeepLink = 'smartmec://failed';
  static const String chromeMobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static String? _asNonEmpty(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _pickUrl(Map<String, dynamic> map) {
    return _asNonEmpty(map['paymentUrl']) ??
        _asNonEmpty(map['url']) ??
        _asNonEmpty(map['gatewayUrl']) ??
        _asNonEmpty(map['startUrl']) ??
        _asNonEmpty(map['link']);
  }

  /// Reads the gateway URL from POST /purchase JSON.
  static PaymentLaunchInfo? parseLaunch(Map<String, dynamic> data) {
    Map<String, dynamic> nested = const {};
    final rawNested = data['data'];
    if (rawNested is Map) {
      nested = Map<String, dynamic>.from(rawNested);
    }

    var url = _pickUrl(data) ?? _pickUrl(nested);
    final trackId = _asNonEmpty(data['trackId']) ??
        _asNonEmpty(nested['trackId']) ??
        _asNonEmpty(data['authority']) ??
        _asNonEmpty(nested['authority']);

    if (url == null && trackId != null) {
      url = '$gatewayStartBase/$trackId';
    }
    if (url == null) return null;

    final isMock = data['mock'] == true ||
        nested['mock'] == true ||
        url.contains('MOCK_') ||
        (trackId != null && trackId.startsWith('MOCK_'));

    return PaymentLaunchInfo(url: url, isMock: isMock, trackId: trackId);
  }

  static bool isCustomAppScheme(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('smartmec://');
  }

  static bool _isOurVerifyPath(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.contains('/purchase/verify') ||
        path.contains('/payment/verify') ||
        path.contains('/payment/callback');
  }

  /// Outcome after a navigation/page event.
  ///
  /// Custom-scheme links can be decided immediately.
  /// `/purchase/verify?success=` is decided after the backend page has loaded
  /// (so verify/credit has already run).
  static PaymentCallbackOutcome? outcomeFromUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    if (lower.contains('smartmec://success')) {
      return PaymentCallbackOutcome.success;
    }
    if (lower.contains('smartmec://failed') ||
        lower.contains('smartmec://fail') ||
        lower.contains('smartmec://cancel')) {
      return PaymentCallbackOutcome.failed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    final success = uri.queryParameters['success']?.toLowerCase();
    final isVerify = _isOurVerifyPath(uri);
    final hasTrack = (uri.queryParameters['trackId'] ??
            uri.queryParameters['authority'] ??
            '')
        .isNotEmpty;

    if (success == '0' || success == 'false') {
      if (isVerify || hasTrack) return PaymentCallbackOutcome.failed;
    }

    if (isVerify && (success == '1' || success == 'true')) {
      return PaymentCallbackOutcome.success;
    }

    return null;
  }
}
