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
            if (request.url.startsWith('smartmec://success')) {
              if (!_isProcessed) {
                _isProcessed = true;
                _handlePaymentResult(isSuccess: true);
              }
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('smartmec://failed')) {
              if (!_isProcessed) {
                _isProcessed = true;
                _handlePaymentResult(isSuccess: false);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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

      Navigator.pop(context);
      Navigator.pop(context);

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
