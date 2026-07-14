import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _unfocus() => FocusScope.of(context).unfocus();

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شرایط استفاده و سلب مسئولیت'),
        content: SingleChildScrollView(
          child: Text(
            'با استفاده از اپلیکیشن «مکانیک هوشمند»، شما تأیید می‌کنید که این برنامه صرفاً یک '
            'ابزار کمکی و اطلاعاتی است و تشخیص‌های آن به هیچ وجه جایگزین نظر مکانیک متخصص نیست.\n\n'
            'هرگونه اقدام، تعمیر یا خسارت ناشی از اعتماد به نتایج این برنامه کاملاً بر عهده کاربر است '
            'و توسعه‌دهنده(گان) هیچ مسئولیتی در قبال آن ندارند.\n\n'
            'برای اطلاعات بیشتر لطفاً فایل DISCLAIMER.md موجود در صفحه پروژه را مطالعه کنید.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOtp() async {
    _unfocus();

    // شماره موبایل در ایران باید دقیقاً ۱۱ رقم باشد
    if (_phoneController.text.length != 11 || !_phoneController.text.startsWith('09')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً یک شماره موبایل معتبر (۱۱ رقمی) وارد کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<ApiService>().sendOtp(_phoneController.text);
      if (!mounted) return; // جلوگیری از کرش فلاتر
      setState(() => _codeSent = true);
    } catch (e) {
      debugPrint('Send OTP Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ارسال کد. لطفاً اینترنت خود را بررسی کرده و دوباره تلاش کنید.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    _unfocus();

    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً کد تایید را وارد کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().login(
            _phoneController.text,
            _codeController.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Verify OTP Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد تایید اشتباه است یا منقضی شده است.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ورود'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                keyboardType: TextInputType.phone,
                maxLength: 11, // محدود کردن تایپ به 11 رقم
                decoration: InputDecoration(
                  labelText: 'شماره موبایل',
                  labelStyle: TextStyle(color: primaryColor),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  counterText: "", // مخفی کردن شمارنده زیر تکست فیلد
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  children: [
                    const TextSpan(text: 'با وارد کردن شماره و ادامه، '),
                    TextSpan(
                      text: 'شرایط استفاده',
                      style: TextStyle(color: primaryColor, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = _showDisclaimerDialog,
                    ),
                    const TextSpan(text: ' را می‌پذیرم.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading
                    ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary))
                    : Text('ارسال کد', style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                keyboardType: TextInputType.number,
                maxLength: 5, // معمولا کدها 5 رقمی هستند
                decoration: InputDecoration(
                  labelText: 'کد تایید',
                  labelStyle: TextStyle(color: primaryColor),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary))
                    : Text('ورود', style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : () => setState(() => _codeSent = false),
                child: const Text('تغییر شماره موبایل'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
