import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  void _buyProduct(BuildContext context, String productId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    
    try {
      final url = await ApiService().getPaymentUrl(auth.token!, productId);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PaymentWebView(url: url)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('فروشگاه'), backgroundColor: Colors.orange),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPackage(context, 'بسته ۵ سوالی', '۵۰,۰۰۰ تومان', 'pkg_5'),
          _buildPackage(context, 'بسته ۲۰ سوالی', '۱۷۰,۰۰۰ تومان', 'pkg_20'),
          _buildPackage(context, 'اشتراک طلایی (۱ ماهه)', '۱۵۰,۰۰۰ تومان', 'sub_gold', isGold: true),
        ],
      ),
    );
  }

  Widget _buildPackage(BuildContext context, String title, String price, String id, {bool isGold = false}) {
    return Card(
      color: isGold ? Colors.amber[800] : Colors.grey[900],
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(price, style: const TextStyle(color: Colors.white70)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: isGold ? Colors.black : Colors.orange),
          onPressed: () => _buyProduct(context, id),
          child: Text('خرید', style: TextStyle(color: isGold ? Colors.amber : Colors.white)),
        ),
      ),
    );
  }
}

class PaymentWebView extends StatefulWidget {
  final String url;
  const PaymentWebView({super.key, required this.url});

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            if (change.url != null && change.url!.contains('myapp://payment-success')) {
              Provider.of<AuthProvider>(context, listen: false).fetchProfile();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پرداخت موفق')));
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('درگاه پرداخت'), backgroundColor: Colors.orange),
      body: WebViewWidget(controller: _controller),
    );
  }
}
