import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _withdrawLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchProfile();
    });
  }

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
        const SnackBar(
          content: Text('خطا در ایجاد درگاه پرداخت. اینترنت را بررسی کنید.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingProductId = null);
    }
  }

  void _copyReferralCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کد معرف کپی شد')),
    );
  }

  void _shareReferral(String code, int percent) {
    Share.share(
      'با اپلیکیشن مکانیک هوشمند، ماشینتو هوشمند عیب‌یابی کن!\n'
      'با کد معرف من ($code) ثبت‌نام کن تا اعتبار هدیه بگیری.\n'
      'من هم $percent٪ از خریدت پاداش می‌گیرم 🎁',
    );
  }

  String _formatToman(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} تومان';
  }

  Future<void> _showWithdrawDialog(AuthProvider auth) async {
    final amountCtrl = TextEditingController(
      text: auth.earnings >= auth.minWithdrawal
          ? auth.earnings.toString()
          : '',
    );
    final cardCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: const Text('درخواست برداشت دستی'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'موجودی: ${_formatToman(auth.earnings)}\nحداقل: ${_formatToman(auth.minWithdrawal)}',
                  style: TextStyle(color: theme.hintColor, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'مبلغ (تومان)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cardCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'شماره کارت ۱۶ رقمی',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام صاحب حساب',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'پس از بررسی ادمین، مبلغ به‌صورت دستی واریز می‌شود.',
                  style: TextStyle(color: theme.hintColor, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ثبت درخواست'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) return;

    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    final card = cardCtrl.text.replaceAll(RegExp(r'\s|-'), '');
    final name = nameCtrl.text.trim();

    setState(() => _withdrawLoading = true);
    try {
      await context.read<ApiService>().requestWithdraw(
            auth.token!,
            amount: amount,
            cardNumber: card,
            fullName: name,
          );
      await auth.fetchProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست برداشت ثبت شد و در انتظار بررسی ادمین است.'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ثبت درخواست')),
      );
    } finally {
      if (mounted) setState(() => _withdrawLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('فروشگاه اعتبار و اشتراک'),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.referralCode != null && auth.referralCode!.isNotEmpty)
            _buildReferralCard(auth, theme),
          _buildPackage(context, 'بسته ۵ عیب‌یابی', '۶۵,۰۰۰ تومان', 'credit_5'),
          _buildPackage(
            context,
            'بسته ۱۰ عیب‌یابی (محبوب)',
            '۱۲۰,۰۰۰ تومان',
            'credit_10',
          ),
          _buildPackage(
            context,
            'اشتراک طلایی (۳۰ روزه)',
            '۱۹۹,۰۰۰ تومان',
            'golden_30',
            isGold: true,
          ),
          _buildPackage(
            context,
            'اشتراک طلایی (۹۰ روزه)',
            '۴۹۹,۰۰۰ تومان',
            'golden_90',
            isGold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(AuthProvider auth, ThemeData theme) {
    final code = auth.referralCode!;
    final canWithdraw = auth.earnings >= auth.minWithdrawal;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.25),
            theme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'دعوت از دوستان',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'با معرفی دوستان، ${auth.referralPercentage}٪ از مبلغ خرید آن‌ها به حساب شما اضافه می‌شود.',
            style: TextStyle(color: theme.hintColor, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'کپی',
                  onPressed: () => _copyReferralCode(code),
                  icon: const Icon(Icons.copy, size: 20),
                ),
                IconButton(
                  tooltip: 'اشتراک‌گذاری',
                  onPressed: () =>
                      _shareReferral(code, auth.referralPercentage),
                  icon: const Icon(Icons.share, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  theme,
                  'دعوت‌شده‌ها',
                  '${auth.referredCount} نفر',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statChip(
                  theme,
                  'درآمد شما',
                  _formatToman(auth.earnings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (!canWithdraw || _withdrawLoading)
                  ? null
                  : () => _showWithdrawDialog(auth),
              icon: _withdrawLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet_outlined),
              label: Text(
                canWithdraw
                    ? 'درخواست برداشت دستی'
                    : 'حداقل برداشت: ${_formatToman(auth.minWithdrawal)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPackage(
    BuildContext context,
    String title,
    String price,
    String id, {
    bool isGold = false,
  }) {
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
                color: isGold
                    ? Colors.black26
                    : theme.colorScheme.primary.withOpacity(0.1),
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
                  Text(
                    title,
                    style: TextStyle(
                      color: isGold
                          ? Colors.black
                          : theme.textTheme.titleMedium?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(
                      color: isGold
                          ? Colors.black87
                          : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isGold ? Colors.black : theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isLoadingThis ? null : () => _buyProduct(id),
              child: isLoadingThis
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color:
                            isGold ? Colors.amber : theme.colorScheme.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'خرید',
                      style: TextStyle(
                        color: isGold
                            ? Colors.amber
                            : theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );

    try {
      await context.read<AuthProvider>().fetchProfile();
      if (!mounted) return;

      Navigator.pop(context);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پرداخت با موفقیت انجام شد. موجودی شما بروزرسانی شد.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'پرداخت انجام شد اما در بروزرسانی صفحه خطایی رخ داد. لطفاً صفحه را رفرش کنید.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ✅ اصلاح شد: onPopInvoked به جای onPopInvokedWithResult
      // (سازگار با Flutter 3.22.0)
      onPopInvoked: (didPop) async {
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
