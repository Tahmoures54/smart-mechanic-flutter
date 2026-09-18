import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';

/// صفحه درگاه پرداخت (WebView)
class PaymentWebView extends StatefulWidget {
  /// آدرس درگاه پرداخت.
  final String url;

  /// دامنه‌های مجاز. اگر خالی باشد، هیچ محدودیتی اعمال نمی‌شود.
  final List<String> allowedHosts;

  /// حداکثر زمان مجاز برای تکمیل پرداخت. اگر null باشد، تایمری اعمال نمی‌شود.
  final Duration? timeout;

  const PaymentWebView({
    super.key,
    required this.url,
    this.allowedHosts = const [],
    this.timeout,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  Timer? _timeoutTimer;

  bool _isProcessed = false;
  bool _isPageLoading = true;
  bool _showResultOverlay = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onUrlChange: _onUrlChange,
          onWebResourceError: _onWebResourceError,
        ),
      );

    _loadInitialUrl();

    if (widget.timeout != null) {
      _timeoutTimer = Timer(widget.timeout!, _onTimeout);
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // راه‌اندازی
  // ---------------------------------------------------------------------------

  void _loadInitialUrl() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() {
        _loadError = 'آدرس درگاه پرداخت نامعتبر است.';
        _isPageLoading = false;
      });
      return;
    }
    _controller.loadRequest(uri);
  }

  void _onTimeout() {
    if (_isProcessed || !mounted) return;
    _isProcessed = true;
    _handlePaymentResult(
      isSuccess: false,
      message: 'زمان پرداخت به پایان رسید.',
    );
  }

  // ---------------------------------------------------------------------------
  // رویدادهای WebView
  // ---------------------------------------------------------------------------

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;

    if (widget.allowedHosts.isNotEmpty) {
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? '';
      final isAllowedHost = widget.allowedHosts.any(
        (h) => host == h || host.endsWith('.$h'),
      );
      final isDeepLink = url.toLowerCase().startsWith('smartmec://');
      if (!isAllowedHost && !isDeepLink) {
        debugPrint('[PaymentWebView] blocked navigation → $url');
        return NavigationDecision.prevent;
      }
    }

    if (_maybeHandleDeepLink(url)) {
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onPageStarted(String url) {
    if (!mounted) return;
    if (!_isPageLoading) setState(() => _isPageLoading = true);
  }

  void _onPageFinished(String url) {
    if (!mounted) return;
    if (_isPageLoading) setState(() => _isPageLoading = false);

    if (_maybeHandleDeepLink(url)) return;
    // بعضی وب‌ویوها deep link را از طریق navigation نمی‌فرستند؛
    // DOM را برای callback اسکن کن.
    _scanPageForCallback();
  }

  void _onUrlChange(UrlChange change) {
    final u = change.url;
    if (u != null) _maybeHandleDeepLink(u);
  }

  void _onWebResourceError(WebResourceError error) {
    debugPrint(
      '[PaymentWebView] resource error: '
      '${error.errorCode} ${error.description}',
    );
  }

  // ---------------------------------------------------------------------------
  // تشخیص نتیجه پرداخت
  // ---------------------------------------------------------------------------

  bool _maybeHandleDeepLink(String url) {
    if (_isProcessed) return true;
    final lower = url.toLowerCase();

    if (lower.contains('smartmec://success')) {
      _isProcessed = true;
      _handlePaymentResult(isSuccess: true);
      return true;
    }
    if (lower.contains('smartmec://failed') ||
        lower.contains('smartmec://fail') ||
        lower.contains('smartmec://cancel')) {
      _isProcessed = true;
      _handlePaymentResult(isSuccess: false);
      return true;
    }

    // The gateway callback URL itself is NOT proof of payment success.
    // The backend must verify the transaction with Zibal first and then return
    // the signed application result via smartmec://success or smartmec://failed.
    // This prevents the client from trusting success/status query parameters.
    if (lower.contains('/api/purchase/verify') ||
        lower.contains('/purchase/verify')) {
      debugPrint('[PaymentWebView] backend payment callback reached: $url');
      return false;
    }
    return false;
  }

  Future<void> _scanPageForCallback() async {
    if (_isProcessed || !mounted) return;
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        "(function(){"
        "try{"
        "var loc=(window.location&&window.location.href)||'';"
        "if(loc.indexOf('smartmec://')===0)return loc;"
        "if(loc.indexOf('/purchase/verify')!==-1||"
        "loc.indexOf('/api/purchase/verify')!==-1)return loc;"
        "var a=document.querySelector('a[href^=\"smartmec\"]');"
        "if(a&&a.href)return a.href;"
        "var html=(document.documentElement&&"
        "document.documentElement.innerHTML)||'';"
        "var m=html.match(/smartmec:\\/\\/(success|failed|fail|cancel)/);"
        "if(m)return 'smartmec://'+m[1];"
        "}catch(e){}"
        "return '';"
        "})()",
      );
      final value = raw.toString().replaceAll('"', '');
      if (value.isNotEmpty) {
        _maybeHandleDeepLink(value);
      }
    } catch (e) {
      debugPrint('[PaymentWebView] scanPage error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // نتیجه پرداخت
  // ---------------------------------------------------------------------------

  Future<void> _handlePaymentResult({
    required bool isSuccess,
    String? message,
  }) async {
    if (!mounted) return;

    if (!isSuccess) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(message ?? 'پرداخت لغو شد یا ناموفق بود.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _showResultOverlay = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await context.read<AuthProvider>().fetchProfile(force: true);
      if (!mounted) return;

      setState(() => _showResultOverlay = false);
      navigator.pop(true);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('پرداخت موفق ✅ موجودی شما به‌روز شد.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[PaymentWebView] fetchProfile failed: $e');
      if (!mounted) return;

      setState(() => _showResultOverlay = false);
      navigator.pop(true);

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'پرداخت انجام شد اما بروزرسانی با تأخیر مواجه شد. '
            'صفحه را بکشید تا تازه شود.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // اگر نتیجه پردازش شده یا خطا داریم، مستقیم ببند.
        if (_isProcessed || _loadError != null) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('درگاه پرداخت امن'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: Stack(
          children: [
            if (_loadError != null)
              _buildError()
            else
              WebViewWidget(controller: _controller),

            if (_isPageLoading && _loadError == null)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (_showResultOverlay)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'خطای نامشخص',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loadError = null;
                  _isPageLoading = true;
                });
                _loadInitialUrl();
              },
              child: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}
