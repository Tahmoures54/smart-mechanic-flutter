import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _referralController = TextEditingController();

  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _showReferral = false;

  static const int _resendCooldown = 60;
  int _secondsLeft = 0;
  Timer? _countdownTimer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _referralController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    _countdownTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _secondsLeft = _resendCooldown;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String? _validatePhone(String phone) {
    final cleanPhone = phone.replaceAll(' ', '').trim();
    if (cleanPhone.length != 11) return 'شماره باید ۱۱ رقم باشد';
    if (!RegExp(r'^09\d{9}$').hasMatch(cleanPhone)) {
      return 'شماره موبایل نامعتبر است (مثال: 09123456789)';
    }
    return null;
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    FocusScope.of(context).unfocus();

    final phone = _phoneController.text.trim();
    final error = _validatePhone(phone);
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<ApiService>().sendOtp(phone);
      if (!mounted) return;

      setState(() => _codeSent = true);
      _startCountdown();
      _codeController.clear();

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) FocusScope.of(context).requestFocus(_codeFocus);
      });

      _showSnack(
        isResend ? 'کد جدید ارسال شد.' : 'کد تأیید ارسال شد.',
        isError: false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('خطا در ارتباط با سرور. اینترنت را بررسی کنید.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();

    final code = _codeController.text.trim();
    if (code.length < 4 || !RegExp(r'^\d+$').hasMatch(code)) {
      _showSnack('کد وارد‌شده معتبر نیست.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().login(
            _phoneController.text.trim(),
            code,
            referralCode: _referralController.text.trim().isEmpty
                ? null
                : _referralController.text.trim(),
          );
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('خطای ناشناخته‌ای در ورود رخ داد.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBackToPhone() {
    _countdownTimer?.cancel();
    setState(() {
      _codeSent = false;
      _codeController.clear();
      _secondsLeft = 0;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) FocusScope.of(context).requestFocus(_phoneFocus);
    });
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ورود به حساب'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(theme),
                    const SizedBox(height: 40),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _codeSent
                          ? _buildOtpSection(theme)
                          : _buildPhoneSection(theme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.secondary.withOpacity(0.12),
          ),
          child: Icon(
            Icons.directions_car_filled_rounded,
            size: 56,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'مکانیک هوشمند',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'با شماره موبایل وارد شوید',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneSection(ThemeData theme) {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 20,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: 'شماره موبایل',
            hintText: '09123456789',
            counterText: '',
            prefixIcon: const Icon(Icons.phone_android_rounded),
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.secondary,
                width: 2,
              ),
            ),
          ),
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 12),

        // کد معرف — طراحی جذاب‌تر برای رشد ویروسی
        AnimatedCrossFade(
          firstChild: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.secondary.withOpacity(0.25),
              ),
            ),
            child: TextButton.icon(
              onPressed: () => setState(() => _showReferral = true),
              icon: Icon(
                Icons.card_giftcard_rounded,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              label: Text(
                'کد معرف داری؟ اعتبار هدیه بگیر 🎁',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          secondChild: Column(
            children: [
              TextField(
                controller: _referralController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: 'کد معرف',
                  hintText: 'SM12AB3C',
                  prefixIcon: const Icon(Icons.card_giftcard_rounded),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.secondary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.35)),
                ),
                child: const Column(
                  children: [
                    Text(
                      '🎁 با کد معرف، اعتبار هدیه می‌گیری',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'دوستت هم از خریدهای بعدی‌ات پاداش می‌گیرد — هر دو برنده می‌شوید',
                      style: TextStyle(fontSize: 12, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showReferral = false;
                    _referralController.clear();
                  });
                },
                child: const Text(
                  'بستن کد معرف',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          crossFadeState: _showReferral
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        const SizedBox(height: 24),

        _buildPrimaryButton(
          label: 'ارسال کد تأیید',
          icon: Icons.send_rounded,
          onPressed: _sendOtp,
        ),
        const SizedBox(height: 40),

        _buildInfoRow(
          theme,
          icon: Icons.lock_outline_rounded,
          text: 'اطلاعات شما کاملاً محرمانه نگهداری می‌شود.',
        ),
      ],
    );
  }

  Widget _buildOtpSection(ThemeData theme) {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'کد برای ${_phoneController.text} ارسال شد',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _goBackToPhone,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                ),
                child: const Text(
                  'تغییر',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        TextField(
          controller: _codeController,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 28,
            letterSpacing: 12,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: 'کد تأیید',
            counterText: '',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.secondary,
                width: 2,
              ),
            ),
          ),
          onChanged: (val) {
            if (val.length == 6 && !_isLoading) {
              _verifyOtp();
            }
          },
          onSubmitted: (_) => _verifyOtp(),
        ),
        const SizedBox(height: 24),

        _buildPrimaryButton(
          label: 'ورود به حساب',
          icon: Icons.login_rounded,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: 16),

        _buildResendRow(theme),
        const SizedBox(height: 24),

        _buildInfoRow(
          theme,
          icon: Icons.info_outline_rounded,
          text: 'اگر کد را دریافت نکردید، مطمئن شوید شماره صحیح است.',
        ),
      ],
    );
  }

  Widget _buildResendRow(ThemeData theme) {
    final canResend = _secondsLeft == 0 && !_isLoading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'کد را دریافت نکردید؟ ',
          style: TextStyle(color: theme.hintColor, fontSize: 13),
        ),
        if (_secondsLeft > 0)
          Row(
            children: [
              const SizedBox(width: 4),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _secondsLeft / _resendCooldown,
                  strokeWidth: 2,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_secondsLeft ثانیه',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          )
        else
          TextButton(
            onPressed: canResend ? () => _sendOtp(isResend: true) : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 30),
            ),
            child: const Text(
              'ارسال مجدد',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: _isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onSecondary.withOpacity(0.8),
              ),
            )
          : Icon(icon, size: 20),
      label: Text(
        _isLoading ? 'لطفاً صبر کنید...' : label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        disabledBackgroundColor: theme.colorScheme.secondary.withOpacity(0.5),
        disabledForegroundColor: theme.colorScheme.onSecondary.withOpacity(0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: theme.hintColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: theme.hintColor, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
