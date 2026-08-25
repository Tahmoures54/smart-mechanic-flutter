import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/shop_package.dart';
import 'payment_webview.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── صفحه فروشگاه ──
// ─────────────────────────────────────────────────────────────────────────────
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

  void _showSnack(String msg, {Color color = Colors.green}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _buyProduct(String productId) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.token == null) {
      _showSnack('ابتدا وارد حساب شوید.', color: Colors.orange);
      return;
    }

    setState(() => _loadingProductId = productId);

    try {
      final api = context.read<ApiService>();
      final url = await api.getPaymentUrl(auth.token!, productId);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PaymentWebView(url: url)),
      );

      // بعد از برگشت از درگاه، پروفایل را تازه کن
      if (mounted) await auth.fetchProfile(force: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'خطا در ایجاد درگاه پرداخت. اینترنت را بررسی کنید.',
        color: Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _loadingProductId = null);
    }
  }

  void _copyReferralCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _showSnack('کد معرف کپی شد ✨');
  }

  void _shareReferral(String code, int percent) {
    Share.share(
      '🚗 مکانیک هوشمند — عیب‌یابی ماشین با AI\n\n'
      'با کد معرف من ثبت‌نام کن و اعتبار هدیه بگیر:\n'
      '🎁 کد: $code\n\n'
      'من هم $percent٪ از خریدت پاداش می‌گیرم.\n'
      'لینک اپ: https://smart-mec.ir',
      subject: 'دعوت به مکانیک هوشمند',
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
      text: auth.earnings >= auth.minWithdrawal ? auth.earnings.toString() : '',
    );
    final cardCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('برداشت درآمد معرفی'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'موجودی قابل برداشت: ${_formatToman(auth.earnings)}\n'
                      'حداقل: ${_formatToman(auth.minWithdrawal)}',
                      style: TextStyle(color: theme.hintColor, fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مبلغ (تومان)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null || val < auth.minWithdrawal) {
                        return 'حداقل مبلغ: ${auth.minWithdrawal}';
                      }
                      if (val > auth.earnings) return 'موجودی کافی نیست';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: cardCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    decoration: const InputDecoration(
                      labelText: 'شماره کارت ۱۶ رقمی',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null ||
                          v.replaceAll(RegExp(r'\s|-'), '').length != 16) {
                        return 'شماره کارت باید ۱۶ رقم باشد';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نام صاحب حساب',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'نام را درست وارد کنید' : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'پس از تأیید، مبلغ طی ۱ تا ۳ روز کاری واریز می‌شود.',
                    style: TextStyle(color: theme.hintColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('ثبت درخواست'),
            ),
          ],
        );
      },
    );

    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    final card = cardCtrl.text.replaceAll(RegExp(r'\s|-'), '');
    final name = nameCtrl.text.trim();

    amountCtrl.dispose();
    cardCtrl.dispose();
    nameCtrl.dispose();

    if (ok != true || !mounted) return;

    setState(() => _withdrawLoading = true);
    try {
      await context.read<ApiService>().requestWithdraw(
            auth.token!,
            amount: amount,
            cardNumber: card,
            fullName: name,
          );
      await auth.fetchProfile(force: true);
      if (!mounted) return;
      _showSnack('درخواست برداشت ثبت شد ✅');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, color: Colors.redAccent);
    } catch (_) {
      if (!mounted) return;
      _showSnack('خطا در ثبت درخواست', color: Colors.redAccent);
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
        title: const Text('اعتبار و اشتراک'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => auth.fetchProfile(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildWalletCard(auth, theme),
            const SizedBox(height: 20),
            if (auth.referralCode != null && auth.referralCode!.isNotEmpty) ...[
              _buildReferralCard(auth, theme),
              const SizedBox(height: 20),
            ],
            Text(
              'بسته‌ها',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'هرچه بیشتر بخرید، هر عیب‌یابی ارزان‌تر تمام می‌شود',
              style: TextStyle(color: theme.hintColor, fontSize: 13),
            ),
            const SizedBox(height: 14),
            ...shopPackages.map((p) => _buildPackageCard(p, theme)),
            const SizedBox(height: 12),
            _buildTrustFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(AuthProvider auth, ThemeData theme) {
    final isGold = auth.isGoldenActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isGold
              ? [const Color(0xFFFFB300), const Color(0xFFFF8F00)]
              : [
                  theme.colorScheme.primary.withOpacity(0.85),
                  theme.colorScheme.secondary.withOpacity(0.75),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isGold ? Colors.amber : theme.colorScheme.primary)
                .withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGold ? Icons.workspace_premium : Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isGold ? 'اشتراک طلایی فعال' : 'کیف اعتبار شما',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isGold && auth.goldenDaysLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${auth.goldenDaysLeft} روز باقی',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _walletStat(
                  label: 'اعتبار باقی‌مانده',
                  value: isGold ? 'نامحدود' : '${auth.credits}',
                  icon: Icons.bolt_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _walletStat(
                  label: 'وضعیت',
                  value: auth.canDiagnose ? 'آماده عیب‌یابی' : 'نیاز به شارژ',
                  icon: auth.canDiagnose
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
          if (!auth.canDiagnose) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'برای ادامه عیب‌یابی یکی از بسته‌های زیر را انتخاب کنید.',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _walletStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildReferralCard(AuthProvider auth, ThemeData theme) {
    final code = auth.referralCode!;
    final canWithdraw = auth.earnings >= auth.minWithdrawal;
    final progress = (auth.earnings / auth.minWithdrawal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'دوستانت را دعوت کن',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تو ${auth.referralPercentage}٪ پاداش می‌گیری · دوستت اعتبار هدیه می‌گیرد',
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'کد اختصاصی شما',
                        style: TextStyle(color: theme.hintColor, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 2,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'کپی',
                  onPressed: () => _copyReferralCode(code),
                  icon: const Icon(Icons.copy_rounded),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _shareReferral(code, auth.referralPercentage),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('ارسال'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statChip(theme, 'دعوت‌شده‌ها', '${auth.referredCount} نفر'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statChip(theme, 'درآمد شما', _formatToman(auth.earnings)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!canWithdraw) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'پیشرفت تا برداشت',
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}٪',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.dividerColor,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatToman(auth.minWithdrawal - auth.earnings)} تا حداقل برداشت باقی مانده',
              style: TextStyle(color: theme.hintColor, fontSize: 11),
            ),
            const SizedBox(height: 10),
          ],
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
                    ? 'درخواست برداشت'
                    : 'حداقل برداشت: ${_formatToman(auth.minWithdrawal)}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '💡 هر دوست با کد تو ثبت‌نام کند، هر دو نفر سود می‌برید.',
            style: TextStyle(color: theme.hintColor, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _statChip(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildPackageCard(ShopPackage pkg, ThemeData theme) {
    final isLoadingThis = _loadingProductId == pkg.id;
    final isAnyLoading = _loadingProductId != null;
    final unit = pkg.unitPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pkg.isGold
            ? Colors.amber.withOpacity(theme.brightness == Brightness.dark ? 0.12 : 0.18)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pkg.isPopular || pkg.isBestValue
              ? theme.colorScheme.secondary
              : theme.dividerColor,
          width: pkg.isPopular || pkg.isBestValue ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pkg.isGold
                            ? Colors.amber.withOpacity(0.25)
                            : theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        pkg.isGold
                            ? Icons.workspace_premium_rounded
                            : Icons.auto_awesome_rounded,
                        color: pkg.isGold
                            ? Colors.amber.shade700
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pkg.subtitle,
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatToman(pkg.priceToman),
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          if (unit != null)
                            Text(
                              pkg.credits != null
                                  ? 'حدود ${_formatToman(unit)} به‌ازای هر عیب‌یابی'
                                  : 'حدود ${_formatToman(unit)} در روز',
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...pkg.benefits.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pkg.isGold
                          ? Colors.amber.shade700
                          : theme.colorScheme.secondary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        (isLoadingThis || isAnyLoading) ? null : () => _buyProduct(pkg.id),
                    child: isLoadingThis
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : Text(
                            pkg.isGold ? 'فعال‌سازی اشتراک' : 'خرید بسته',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (pkg.isPopular || pkg.isBestValue)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  pkg.isBestValue ? 'به‌صرفه‌ترین' : 'محبوب‌ترین',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrustFooter(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 14, color: theme.hintColor),
            const SizedBox(width: 6),
            Text(
              'پرداخت امن · فعال‌سازی آنی پس از پرداخت',
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'عیب‌یابی‌ها ابزار کمکی هستند و جایگزین نظر مکانیک متخصص نیستند.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.hintColor, fontSize: 11),
        ),
      ],
    );
  }
}
