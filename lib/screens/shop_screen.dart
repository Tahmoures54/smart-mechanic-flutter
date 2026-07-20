import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _loadingProductId;

  // لیست محصولات هماهنگ با بک‌اند جدید (بدون credit_1)
  final List<Map<String, dynamic>> _products = [
    {
      'title': 'بسته ۵ عیب‌یابی',
      'subtitle': '۵ بار عیب‌یابی هوشمند',
      'price': '۶۵,۰۰۰ تومان',
      'pricePerUse': '۱۳,۰۰۰',
      'id': 'credit_5',
      'isGold': false,
      'discount': null,
      'popular': false,
      'limit': null,
    },
    {
      'title': 'بسته ۱۰ عیب‌یابی (محبوب)',
      'subtitle': '۱۰ بار عیب‌یابی، ۲۰٪ صرفه‌جویی',
      'price': '۱۲۰,۰۰۰ تومان',
      'pricePerUse': '۱۲,۰۰۰',
      'id': 'credit_10',
      'isGold': false,
      'discount': '۲۰٪',
      'popular': true,
      'limit': null,
    },
    {
      'title': 'اشتراک طلایی ۳۰ روزه',
      'subtitle': 'دسترسی نامحدود تا ۲۰۰ عیب‌یابی در ماه',
      'price': '۱۹۹,۰۰۰ تومان',
      'pricePerUse': null,
      'id': 'golden_30',
      'isGold': true,
      'discount': null,
      'popular': false,
      'limit': 'حداکثر ۲۰۰ درخواست در ماه',
    },
    {
      'title': 'اشتراک طلایی ۹۰ روزه (محبوب)',
      'subtitle': '۳۰۰ عیب‌یابی در ماه، صرفه‌جویی ۱۶٪',
      'price': '۴۹۹,۰۰۰ تومان',
      'pricePerUse': null,
      'id': 'golden_90',
      'isGold': true,
      'discount': '۱۶٪',
      'popular': true,
      'limit': 'حداکثر ۳۰۰ درخواست در ماه',
    },
    {
      'title': 'اشتراک طلایی سالانه',
      'subtitle': '۵۰۰ عیب‌یابی در ماه، بهترین ارزش',
      'price': '۱,۴۹۹,۰۰۰ تومان',
      'pricePerUse': null,
      'id': 'golden_365',
      'isGold': true,
      'discount': '۲۵٪',
      'popular': false,
      'limit': 'حداکثر ۵۰۰ درخواست در ماه',
    },
  ];

  Future<void> _buyProduct(String productId) async {
    final auth = context.read<AuthProvider>();

    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (auth.token == null) return;

    setState(() => _loadingProductId = productId);

    try {
      final api = context.read<ApiService>();
      final url = await api.getPaymentUrl(auth.token!, productId);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaymentWebView(url: url)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'خطا در ایجاد درگاه پرداخت.'),
        ),
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
        children: _products.map((product) {
          return _buildPackage(
            context,
            product['title'] as String,
            product['subtitle'] as String,
            product['price'] as String,
            product['id'] as String,
            isGold: product['isGold'] as bool,
            discount: product['discount'] as String?,
            popular: product['popular'] as bool,
            limit: product['limit'] as String?,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPackage(
    BuildContext context,
    String title,
    String subtitle,
    String price,
    String id, {
    bool isGold = false,
    String? discount,
    bool popular = false,
    String? limit,
  }) {
    final theme = Theme.of(context);
    final bool isLoadingThis = _loadingProductId == id;

    return Card(
      color: isGold ? Colors.amber[800] : theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: popular
            ? BorderSide(color: theme.colorScheme.secondary, width: 2)
            : BorderSide.none,
      ),
      elevation: popular ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isGold ? Colors.black26 : theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGold ? Icons.workspace_premium : Icons.build_circle,
                    color: isGold ? Colors.white : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: isGold ? Colors.black : theme.textTheme.titleMedium?.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (popular)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'محبوب',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isGold ? Colors.black87 : theme.textTheme.bodyMedium?.color,
                          fontSize: 13,
                        ),
                      ),
                      if (limit != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: isGold ? Colors.black54 : theme.hintColor),
                              const SizedBox(width: 4),
                              Text(
                                limit,
                                style: TextStyle(
                                  color: isGold ? Colors.black54 : theme.hintColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          color: isGold ? Colors.black : theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      if (discount != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'صرفه‌جویی $discount',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isGold ? Colors.black : theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isLoadingThis ? null : () => _buyProduct(id),
                  child: isLoadingThis
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: isGold ? Colors.amber : theme.colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'خرید',
                          style: TextStyle(
                            color: isGold ? Colors.amber : theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
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
  bool _hasPageError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('smartmec://')) {
              if (!_isProcessed) {
                _isProcessed = true;
                _handlePaymentSuccess();
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            setState(() => _hasPageError = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطا در بارگذاری درگاه: ${error.description}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handlePaymentSuccess() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );

    try {
      await context.read<AuthProvider>().fetchProfile();
      if (!mounted) return;

      Navigator.pop(context); // close loading
      Navigator.pop(context); // close webview

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پرداخت با موفقیت تأیید شد و محصول به حساب شما اضافه گردید.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context); // close loading

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('پرداخت موفق'),
          content: const Text(
            'پرداخت شما با موفقیت انجام شد، اما در بروزرسانی پروفایل خطایی رخ داد.\n'
            'لطفاً یکبار برنامه را ببندید و دوباره باز کنید.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('باشه'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // close webview

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای دریافت محصول، برنامه را مجدداً راه‌اندازی کنید.'),
          duration: Duration(seconds: 5),
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
        if (!_isProcessed) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('خروج از درگاه'),
              content: const Text('در صورت خروج، پرداخت شما ناتمام می‌ماند. مطمئن هستید؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('انصراف'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('خروج'),
                ),
              ],
            ),
          );
          if (shouldPop == true && mounted) {
            Navigator.pop(context);
          }
        } else {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('درگاه پرداخت امن')),
        body: _hasPageError
            ? const Center(
                child: Text(
                  'متأسفانه بارگذاری درگاه با خطا مواجه شد.\nلطفاً دوباره تلاش کنید.',
                  textAlign: TextAlign.center,
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
