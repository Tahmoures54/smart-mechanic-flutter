import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/payment_flow.dart';

/// درگاه زیبال داخل WebView — پس از پرداخت به callback بک‌اند برمی‌گردد.
class PaymentWebView extends StatefulWidget {
  final String url;
  const PaymentWebView({super.key, required this.url});

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isProcessed = false;
  bool _pageLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(PaymentFlow.chromeMobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (PaymentFlow.isCustomAppScheme(request.url)) {
              _completeFromUrl(request.url, immediate: true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _pageLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _pageLoading = false);
            // فقط بعد از لود کامل verify — تا GET بک‌اند اعتبار را اعمال کند
            _completeFromUrl(url, immediate: false);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && PaymentFlow.isCustomAppScheme(url)) {
              _completeFromUrl(url, immediate: true);
            }
          },
          onWebResourceError: (error) {
            final failing = error.url ?? '';
            if (PaymentFlow.isCustomAppScheme(failing)) {
              _completeFromUrl(failing, immediate: true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _completeFromUrl(String url, {required bool immediate}) {
    if (_isProcessed) return;
    if (immediate && !PaymentFlow.isCustomAppScheme(url)) return;
    final outcome = PaymentFlow.outcomeFromUrl(url);
    if (outcome == null) return;
    _isProcessed = true;
    _finish(outcome);
  }

  Future<void> _finish(PaymentCallbackOutcome outcome) async {
    if (!mounted) return;
    final ok = outcome == PaymentCallbackOutcome.success;
    if (ok) {
      try {
        await context.read<AuthProvider>().fetchProfile(force: true);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پرداخت امن زیبال'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            if (_pageLoading) const LinearProgressIndicator(minHeight: 3),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
