import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';

/// صفحه درگاه پرداخت (WebView)
class PaymentWebView extends StatefulWidget {
  final String url;
  const PaymentWebView({super.key, required this.url});

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isProcessed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final handled = _maybeHandleDeepLink(request.url);
            if (handled) return NavigationDecision.prevent;
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            _maybeHandleDeepLink(url);
            // بعضی وب‌ویوها deep link را به صورت navigation نمی‌فرستند؛
            // بعد از لود صفحهٔ وریفای، لینک‌های smartmec را از DOM چک کن.
            _scanPageForCallback();
          },
          onUrlChange: (UrlChange change) {
            final u = change.url;
            if (u != null) _maybeHandleDeepLink(u);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  bool _maybeHandleDeepLink(String url) {
    if (_isProcessed) return true;
    final lower = url.toLowerCase();

    if (lower.startsWith('smartmec://success') ||
        lower.contains('smartmec://success')) {
      _isProcessed = true;
      _handlePaymentResult(isSuccess: true);
      return true;
    }
    if (lower.startsWith('smartmec://failed') ||
        lower.contains('smartmec://failed')) {
      _isProcessed = true;
      _handlePaymentResult(isSuccess: false);
      return true;
    }

    // کال‌بک HTML وریفای: /api/purchase/verify?...&success=0|1
    if (lower.contains('/api/purchase/verify') ||
        lower.contains('/purchase/verify')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final success = uri.queryParameters['success'];
        if (success == '0') {
          _isProcessed = true;
          _handlePaymentResult(isSuccess: false);
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _scanPageForCallback() async {
    if (_isProcessed || !mounted) return;
    try {
      final href = await _controller.runJavaScriptReturningResult(
        'window.location.href',
      );
      final hrefStr = href.toString().replaceAll('"', '');
      if (_maybeHandleDeepLink(hrefStr)) return;

      final link = await _controller.runJavaScriptReturningResult(
        "(function(){var a=document.querySelector('a[href^=\"smartmec\"]');return a?a.href:'';})()",
      );
      final linkStr = link.toString().replaceAll('"', '');
      if (linkStr.startsWith('smartmec')) {
        _maybeHandleDeepLink(linkStr);
      }
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _handlePaymentResult({required bool isSuccess}) async {
    if (!mounted) return;

    if (!isSuccess) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پرداخت لغو شد یا ناموفق بود.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );

    try {
      await context.read<AuthProvider>().fetchProfile(force: true);
      if (!mounted) return;

      Navigator.pop(context); // dialog
      Navigator.pop(context); // webview

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پرداخت موفق ✅ موجودی شما به‌روز شد.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'پرداخت انجام شد اما بروزرسانی با تأخیر مواجه شد. صفحه را بکشید تا تازه شود.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('درگاه پرداخت امن'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
