import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

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

  void _verifyOtp() async {
    FocusScope.of(context).unfocus();
    if (_codeController.text.length < 4) return;

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().login(_phoneController.text, _codeController.text);
      if (!mounted) return;
      
      // 👇 حل مشکل صفحه سیاه: بازگشت امن به صفحه اصلی
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (بقیه کدهای _sendOtp و build دقیقاً مثل کدهای قبلی خودتان باشد)
  // فقط دقت کنید در متد _sendOtp لاجیک تغییر نکرده است.
  
  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (_phoneController.text.length != 11 || !_phoneController.text.startsWith('09')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره موبایل نامعتبر است.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await context.read<ApiService>().sendOtp(_phoneController.text);
      if (!mounted) return; 
      setState(() => _codeSent = true);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e is ApiException ? e.message : 'خطا در ارتباط با سرور';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    // UI همان UI قبلی شماست...
    return Scaffold(
      appBar: AppBar(title: const Text('ورود به حساب')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_codeSent) ...[
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'شماره موبایل')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _isLoading ? null : _sendOtp, child: const Text('ارسال کد')),
            ] else ...[
              TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'کد تایید')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _isLoading ? null : _verifyOtp, child: const Text('ورود')),
            ]
          ],
        ),
      ),
    );
  }
}
