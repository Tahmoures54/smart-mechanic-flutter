import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _loadingProductId; 

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ایجاد درگاه پرداخت. اینترنت را بررسی کنید.')),
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
        title: const Text('فروشگاه اعتبار و اشتراک'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPackage(context, 'بسته ۵ عیب‌یابی', '۶۵,۰۰۰ تومان', 'credit_5'),
          _buildPackage(context, 'بسته ۱۰ عیب‌یابی (محبوب)', '۱۲۰,۰۰۰ تومان', 'credit_10'),
          _buildPackage(context, 'اشتراک طلایی (۳۰ روزه)', '۱۹۹,۰۰۰ تومان', 'golden_30', isGold: true),
          _buildPackage(context, 'اشتراک طلایی (۹۰ روزه)', '۴۹۹,۰۰۰ تومان', 'golden_90', isGold: true),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGold ? Colors.black26 : theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isGold ? Icons.workspace_premium : Icons.build_circle, 
                color: isGold ? Colors.white : theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isGold ? Colors.black : theme.textTheme.titleMedium?.color, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(price, style: TextStyle(color: isGold ? Colors.black87 : theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isGold ? Colors.black : theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isLoadingThis ? null : () => _buyProduct(id),
              child: isLoadingThis
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: isGold ? Colors.amber : theme.colorScheme.onPrimary, strokeWidth: 2))
                  : Text('خرید', style: TextStyle(color: isGold ? Colors.amber : theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ),
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
  bool _isProcessed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // 👈 تفکیک پرداخت موفق از ناموفق
            if (request.url.startsWith('smartmec://success')) {
              if (!_isProcessed) {
                _isProcessed = true;
                _handlePaymentResult(isSuccess: true);
              }
              return NavigationDecision.prevent; 
            } 
            else if (request.url.startsWith('smartmec://failed')) {
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
    
    // اگر کاربر انصراف داده بود یا پرداخت ناموفق بود
    if (!isSuccess) {
      Navigator.pop(context); // بستن وب‌ویو
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پرداخت لغو شد یا ناموفق بود.', style: TextStyle(fontFamily: 'Vazirmatn')), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // اگر پرداخت موفق بود
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );
    
    try {
      // دریافت اطلاعات جدید کاربر از سرور (تا تعداد اعتبار یا اشتراک آپدیت شود)
      await context.read<AuthProvider>().fetchProfile();
      if (!mounted) return;
      
      Navigator.pop(context); // بستن دیالوگ
      Navigator.pop(context); // بستن وب‌ویو
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پرداخت با موفقیت انجام شد. موجودی شما بروزرسانی شد.', style: TextStyle(fontFamily: 'Vazirmatn')), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پرداخت انجام شد اما در بروزرسانی صفحه خطایی رخ داد. لطفاً صفحه را رفرش کنید.')),
      );
    }
  }

  // 👈 استفاده از PopScope به جای WillPopScope برای فلاتر 3.22 به بعد
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('درگاه پرداخت امن'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(), // دکمه خروج دستی
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
