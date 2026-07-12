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

  void _sendOtp() async {
    if (_phoneController.text.length < 10) return;
    setState(() => _isLoading = true);
    try {
      await ApiService().sendOtp(_phoneController.text);
      setState(() => _codeSent = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _isLoading = false);
  }

  void _verifyOtp() async {
    if (_codeController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).login(
        _phoneController.text,
        _codeController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('ورود'), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'شماره موبایل',
                  labelStyle: TextStyle(color: Colors.orange),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading ? const CircularProgressIndicator() : const Text('ارسال کد'),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'کد تایید (۱۲۳۴)',
                  labelStyle: TextStyle(color: Colors.orange),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading ? const CircularProgressIndicator() : const Text('ورود'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
