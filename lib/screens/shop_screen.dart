import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
// فرض می‌کنیم Constants موجود است
// import '../constants.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _loadingProductId; // ردیابی کدام پکیج در حال پردازش است

  Future<void> _buyProduct(String productId) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _loadingProductId = productId);

    try {
      final api = context.read<ApiService>();
      final url = await api.getPaymentUrl(auth.token!, productId);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PaymentWebView(url: url)),
      );
    } catch (e) {
      debugPrint('Payment URL Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ایجاد درگاه پرداخت. لطفاً دوباره تلاش کنید.')),
      );
    } finally {
      if (mounted) setState(() => _loadingProductId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('فروشگاه'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
      ),
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
    final theme = Theme.of(context);
    final bool isLoadingThis = _loadingProductId == id;

    return Card(
      color: isGold ? Colors.amber[800] : theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                title: Text(title, style: TextStyle(color: isGold ? Colors.black : theme.textTheme.titleMedium?.color, fontWeight: FontWeight.bold)),
                subtitle: Text(price, style: TextStyle(color: isGold ? Colors.black87 : theme.textTheme.bodyMedium?.color)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isGold ? Colors.black : theme.colorScheme.primary),
              onPressed: isLoadingThis ? null : () => _buyProduct(id),
              child: isLoadingThis
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: isGold ? Colors.amber : theme.colorScheme.onPrimary, strokeWidth: 2))
                  : Text('خرید', style: TextStyle(color: isGold ? Colors.amber : theme.colorScheme.onPrimary)),
            ),
            const SizedBox(width: 8),
          ],
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
  bool _isProcessed = false; // جلوگیری از اجرای چندباره کال‌بک

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            if (_isProcessed) return; // اگر یک بار پردازش شد، دیگه ادامه نده
            
            final url = change.url;
            // نکته امنیتی: در پروژه واقعی باید transaction_id را استخراج کرده و به سرور verify کنید
            if (url != null && url.contains('myapp://payment-success')) {
              _isProcessed = true; // قفل کردن
              _handlePaymentSuccess();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handlePaymentSuccess() async {
    // چک کردن mounted قبل از هر کار مربوط به context
    if (!mounted) return;
    
    // نمایش یک لودینگ روی صفحه وب‌ویو می‌تواند مفید باشد
    
    try {
      await context.read<AuthProvider>().fetchProfile();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پرداخت با موفقیت انجام شد')));
      Navigator.pop(context); // بستن وب‌ویو
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پرداخت موفق بود اما خطا در بروزرسانی پروفایل')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('درگاه پرداخت'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
