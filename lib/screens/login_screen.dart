import 'package:flutter/material.dart';
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
    // رفع نشتی حافظه
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// بستن کیبورد
  void _unfocus() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _sendOtp() async {
    _unfocus();
    
    // اعتبارسنجی با بازخورد به کاربر
    if (_phoneController.text.length < 10 || !_phoneController.text.startsWith('09')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً یک شماره موبایل معتبر (۱۱ رقمی) وارد کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // استفاده از Provider برای دریافت سرویس
      await context.read<ApiService>().sendOtp(_phoneController.text);
      setState(() => _codeSent = true);
    } catch (e) {
      debugPrint('Send OTP Error: $e');
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
      if (mounted) Navigator.pop(context); // بستن صفحه بعد از ورود موفق
    } catch (e) {
      debugPrint('Verify OTP Error: $e');
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
                decoration: InputDecoration(
                  labelText: 'شماره موبایل',
                  labelStyle: TextStyle(color: primaryColor),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 45), // دکمه تمام عرض
                ),
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: theme.colorScheme.onPrimary),
                      )
                    : Text('ارسال کد', style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'کد تایید',
                  labelStyle: TextStyle(color: primaryColor),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
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
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: theme.colorScheme.onPrimary),
                      )
                    : Text('ورود', style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
              const SizedBox(height: 12),
              // دکمه بازگشت برای اصلاح شماره
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
