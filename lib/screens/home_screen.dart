import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/car.dart';
import 'login_screen.dart';
import 'shop_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import 'record_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Car> _cars = [];
  Car? _selectedCar;

  final _descController = TextEditingController();
  final _customCarController = TextEditingController();
  final _yearController = TextEditingController();

  bool _isLoadingCars = true;
  bool _isRefreshing = false;
  bool _hasCarLoadError = false;
  bool _isCustomCar = false;
  bool _showCommonIssues = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCars());
  }

  @override
  void dispose() {
    _descController.dispose();
    _customCarController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadCars({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (isRefresh) {
        _isRefreshing = true;
      } else {
        _isLoadingCars = true;
      }
      _hasCarLoadError = false;
    });

    try {
      final api = context.read<ApiService>();
      final cars = await api.getCars();
      if (!mounted) return;

      cars.sort((a, b) => a.fullName.compareTo(b.fullName));

      setState(() {
        _cars = cars;
        if (_selectedCar != null) {
          final found = cars.where((c) => c.id == _selectedCar!.id);
          _selectedCar = found.isNotEmpty ? found.first : cars.firstOrNull;
        } else if (cars.isNotEmpty && !_isCustomCar) {
          _selectedCar = cars.first;
        }
      });
    } catch (e) {
      debugPrint('Error loading cars: $e');
      if (mounted) {
        setState(() => _hasCarLoadError = true);
        _showSnack('خطا در دریافت لیست خودروها. اینترنت را بررسی کنید.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCars = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  bool _validateYear(String year) {
    final n = int.tryParse(year);
    if (n == null) return false;
    final shamsi = n >= 1340 && n <= 1420;
    final gregorian = n >= 1960 && n <= 2040;
    return shamsi || gregorian;
  }

  bool _validateInputs({required bool requireDescription}) {
    final auth = context.read<AuthProvider>();

    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return false;
    }

    if (!_isCustomCar && _selectedCar == null) {
      _showSnack('لطفاً ابتدا خودروی خود را انتخاب کنید.');
      return false;
    }

    if (_isCustomCar && _customCarController.text.trim().length < 2) {
      _showSnack('لطفاً نام و مدل خودروی خود را بنویسید (حداقل ۲ حرف).');
      return false;
    }

    final year = _yearController.text.trim();
    if (year.isEmpty || !_validateYear(year)) {
      _showSnack(
        'سال ساخت را وارد کنید (مثلاً ۱۴۰۳ شمسی یا ۲۰۲۴ میلادی).',
      );
      return false;
    }

    if (requireDescription && _descController.text.trim().length < 5) {
      _showSnack('لطفاً مشکل را کمی واضح‌تر بنویسید (حداقل ۵ حرف).');
      return false;
    }

    if (!auth.isGolden && auth.credits <= 0) {
      _showNoCreditDialog();
      return false;
    }

    return true;
  }

  ({String id, String name, String year}) _getCarInfo() {
    return (
      id: _isCustomCar ? 'custom' : (_selectedCar?.id ?? 'custom'),
      name: _isCustomCar
          ? _customCarController.text.trim()
          : (_selectedCar?.fullName ?? ''),
      year: _yearController.text.trim(),
    );
  }

  void _diagnose() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateInputs(requireDescription: true)) return;

    final car = _getCarInfo();
    final userMessage = _descController.text.trim();
    _descController.clear();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          carName: car.name,
          carId: car.id,
          year: car.year,
          initialUserMessage: userMessage,
          isCustomCar: _isCustomCar,
        ),
      ),
    );
  }

  void _onVoiceRecordTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateInputs(requireDescription: false)) return;

    final car = _getCarInfo();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          carName: car.name,
          carId: car.id,
          year: car.year,
        ),
      ),
    );
  }

  void _showNoCreditDialog() {
    final theme = Theme.of(context);
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: theme.colorScheme.secondary, size: 28),
            const SizedBox(width: 8),
            Text(
              'اعتبار تمام شده',
              style: TextStyle(color: theme.textTheme.titleLarge?.color),
            ),
          ],
        ),
        content: Text(
          'برای ادامه عیب‌یابی، یک بسته اعتبار یا اشتراک طلایی انتخاب کن.\n\n'
          'بسته ۱۰تایی معمولاً به‌صرفه‌تر از ۵تایی است.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('بعداً'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مشاهده بسته‌ها'),
          ),
        ],
      ),
    ).then((goToShop) {
      if (goToShop == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        );
      }
    });
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('امکان باز کردن لینک وجود ندارد', color: Colors.red);
      }
    } catch (e) {
      _showSnack('خطا در باز کردن لینک', color: Colors.red);
    }
  }

  void _shareApp() {
    final auth = context.read<AuthProvider>();
    final code = auth.referralCode;
    final codeLine = (code != null && code.isNotEmpty)
        ? '\n🎁 با کد معرف من ثبت‌نام کن تا اعتبار هدیه بگیری: $code\n'
        : '\n';
    SharePlus.instance.share(
      ShareParams(
        text:
            '🚗 مکانیک هوشمند — عیب‌یابی ماشین با کمک AI\n'
            'من استفاده کردم و واقعاً کمکم کرد.'
            '$codeLine'
            'لینک: https://smart-mec.ir',
        subject: 'معرفی مکانیک هوشمند',
      ),
    );
  }

  void _showSupportModal(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Icon(Icons.favorite_rounded,
                      color: Colors.red.shade400, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'حمایت از تیم استارتاپی',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'سلام رفیق! ما یک تیم نوپا هستیم و با عشق این اپلیکیشن رو براتون ساختیم.'
                    ' برای ادامه این مسیر و بهبود اپلیکیشن، به حمایت‌های کوچک شما نیاز داریم. 🙏',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  _buildSupportButton(
                    theme: theme,
                    icon: Icons.camera_alt_rounded,
                    label: 'ما را در اینستاگرام دنبال کنید',
                    gradientColors: [
                      Colors.purple.shade400,
                      Colors.pink.shade400
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      _launchUrl('https://instagram.com/smart_mec_app');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSupportButton(
                    theme: theme,
                    icon: Icons.send_rounded,
                    label: 'عضو کانال تلگرام ما شوید',
                    gradientColors: [
                      Colors.lightBlue.shade400,
                      Colors.blue.shade500
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      _launchUrl('https://t.me/smart_mec_app');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSupportButton(
                    theme: theme,
                    icon: Icons.share_rounded,
                    label: 'معرفی اپلیکیشن به دوستان',
                    gradientColors: [
                      Colors.green.shade400,
                      Colors.teal.shade500
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      _shareApp();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSupportButton(
                    theme: theme,
                    icon: Icons.star_rounded,
                    label: 'حمایت مالی (خرید اعتبار)',
                    gradientColors: [
                      Colors.amber.shade400,
                      Colors.orange.shade500
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withAlpha(76),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_left_rounded,
                    color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'مکانیک هوشمند',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              theme.appBarTheme.backgroundColor ?? theme.primaryColor,
          elevation: 0,
          actions: [
            if (auth.isAuthenticated)
              IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: 'تاریخچه عیب‌یابی',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              )
            else
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: Text(
                  'ورود',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          color: theme.colorScheme.secondary,
          onRefresh: () => _loadCars(isRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.isAuthenticated)
                  _buildCreditCard(auth, theme)
                else
                  _buildGuestBanner(theme),
                const SizedBox(height: 20),
                Text(
                  '۱. مشخصات خودروی خود را وارد کنید:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildCarSelector(theme)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: _buildYearField(theme)),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isCustomCar = !_isCustomCar;
                        _showCommonIssues = false;
                        if (!_isCustomCar) {
                          _customCarController.clear();
                          if (_cars.isNotEmpty) {
                            _selectedCar = _cars.first;
                          }
                        } else {
                          _selectedCar = null;
                        }
                      });
                    },
                    icon: Icon(
                      _isCustomCar
                          ? Icons.arrow_back_rounded
                          : Icons.search_off_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isCustomCar
                          ? 'بازگشت به لیست خودروها'
                          : 'خودروی من در لیست نیست',
                    ),
                  ),
                ),
                _buildCommonIssues(theme),
                const SizedBox(height: 24),
                Text(
                  '۲. شرح خرابی را بنویسید:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDescriptionField(theme),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 24),
                  label: Text(
                    'ارسال به مکانیک هوشمند',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _diagnose,
                ),
                const SizedBox(height: 20),
                _buildDivider(theme),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.mic_none_rounded, size: 28),
                  label: const Text('شروع ضبط صدای موتور / خودرو'),
                  onPressed: _onVoiceRecordTap,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 65),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: theme.scaffoldBackgroundColor,
                    foregroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 36),
                _buildPromoSection(theme),
                const SizedBox(height: 24),
                _buildSupportBanner(theme),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.hintColor.withAlpha(50),
            thickness: 1.5,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.hintColor.withAlpha(50)),
          ),
          child: Text(
            'یا روش دقیق‌تر',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.hintColor.withAlpha(50),
            thickness: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.secondary.withAlpha(50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withAlpha(26),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.redAccent,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ما یک تیم استارتاپی هستیم 🙏',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'صادقانه بگیم، این پروژه بدون حمایت شما دوستان عزیز پیشرفت نمی‌کنه.'
            ' اگه از کارمون راضی بودید، لطفاً با یه فالو یا معرفی به دوستاتون'
            ' کمکمون کنید. 🙏',
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.6,
              color: theme.hintColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.volunteer_activism_rounded, size: 22),
              label: const Text(
                'حمایت از ما',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showSupportModal(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearField(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _yearController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 4,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: '1403',
          labelText: 'سال *',
          labelStyle: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
          hintStyle: TextStyle(color: theme.hintColor, fontSize: 12),
          filled: true,
          fillColor: theme.cardColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: theme.colorScheme.secondary,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCarSelector(ThemeData theme) {
    if (_isCustomCar) {
      return SizedBox(
        height: 56,
        child: TextField(
          controller: _customCarController,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'مثال: تویوتا کمری',
            hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
            filled: true,
            fillColor: theme.cardColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.secondary.withAlpha(128),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.secondary,
                width: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    if (_isLoadingCars && !_isRefreshing) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      );
    }

    if (_hasCarLoadError && _cars.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withAlpha(128)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'خطا در بارگذاری',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  size: 20, color: theme.colorScheme.secondary),
              tooltip: 'تلاش مجدد',
              onPressed: _loadCars,
            ),
          ],
        ),
      );
    }

    if (_cars.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'هیچ خودرویی یافت نشد.',
          style: TextStyle(color: theme.hintColor, fontSize: 12),
        ),
      );
    }

    return InkWell(
      onTap: () => _showCarSearchModal(theme),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(16),
          color: theme.cardColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCar?.fullName ?? 'خودرو را انتخاب کنید',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _selectedCar != null
                      ? theme.textTheme.bodyLarge?.color
                      : theme.hintColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showCarSearchModal(ThemeData theme) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _CarSearchSheet(
            cars: _cars,
            selectedCar: _selectedCar,
            theme: theme,
            onCarSelected: (car) {
              setState(() {
                _selectedCar = car;
                _showCommonIssues = false;
              });
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildCommonIssues(ThemeData theme) {
    if (_isCustomCar || _selectedCar == null) return const SizedBox.shrink();

    final issues = _selectedCar!.commonIssues
        .where((issue) => !issue.contains('اطلاعات دقیقی'))
        .toList();

    if (issues.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _showCommonIssues = !_showCommonIssues),
            icon: Icon(
              _showCommonIssues
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: theme.colorScheme.secondary,
              size: 20,
            ),
            label: Text(
              _showCommonIssues
                  ? 'بستن مشکلات شایع'
                  : 'نمایش مشکلات شایع این خودرو',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showCommonIssues
              ? Padding(
                  key: ValueKey(_selectedCar!.id),
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: issues.map((issue) {
                      return ActionChip(
                        backgroundColor:
                            theme.colorScheme.primary.withAlpha(26),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withAlpha(76),
                        ),
                        labelStyle: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                        label: Text(issue),
                        onPressed: () =>
                            setState(() => _descController.text = issue),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextField(
      controller: _descController,
      maxLines: 4,
      maxLength: 300,
      textInputAction: TextInputAction.done,
      style: TextStyle(
          color: theme.textTheme.bodyLarge?.color, height: 1.5),
      decoration: InputDecoration(
        hintText:
            'مثال: صبح‌ها که هوا سرده، موقع استارت زدن ماشین ریپ می‌زنه...',
        hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.secondary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGuestBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_alt_rounded,
              color: theme.colorScheme.secondary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'مشکل ماشینت رو بنویس تا راهنمایی هوشمند بگیری.\n'
              'با ورود، اعتبار هدیه برای شروع دریافت می‌کنی.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            style: TextButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
              foregroundColor: theme.colorScheme.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'شروع',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withAlpha(230),
            theme.colorScheme.primary.withAlpha(179),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.secondary.withAlpha(76),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(26),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: theme.colorScheme.secondary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'چرا مکانیک هوشمند؟',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'هوش مصنوعی ما با تحلیل میلیون‌ها دادهٔ تعمیرگاهی آموزش دیده'
            ' است تا دقیق‌ترین تشخیص را به شما ارائه دهد.',
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _buildPromoItem(
            theme,
            icon: Icons.savings_rounded,
            title: 'پیشگیری بهتر از تعمیر',
            desc:
                'با آگاهی و تشخیص زودهنگام، نگذارید یک ایراد کوچک به موتور'
                ' آسیب جدی وارد کند.',
          ),
          const SizedBox(height: 16),
          _buildPromoItem(
            theme,
            icon: Icons.handshake_rounded,
            title: 'دستیار هوشمند مکانیک شما',
            desc:
                'تشخیص دقیق اولین قدم است؛ با داشتن گزارش کامل، به مکانیک'
                ' خود کمک کنید.',
          ),
          const SizedBox(height: 16),
          _buildPromoItem(
            theme,
            icon: Icons.timer_rounded,
            title: 'صرفه‌جویی در زمان',
            desc:
                'بدون سردرگمی، در کمتر از چند ثانیه ریشه مشکل را بررسی کنید.',
          ),
        ],
      ),
    );
  }

  Widget _buildPromoItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(38),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreditCard(AuthProvider auth, ThemeData theme) {
    final isGolden = auth.isGolden;
    final lowCredits = !isGolden && auth.credits > 0 && auth.credits <= 2;
    final noCredits = !isGolden && auth.credits <= 0;

    final textColor = isGolden ? Colors.white : theme.textTheme.bodyLarge?.color;
    final subTextColor = isGolden ? Colors.white70 : theme.textTheme.bodySmall?.color;

    String statusLine;
    if (isGolden) {
      statusLine = 'فعال می‌باشد';
    } else if (noCredits) {
      statusLine = 'برای عیب‌یابی نیاز به شارژ داری';
    } else if (lowCredits) {
      statusLine = auth.credits == 1
          ? 'فقط ۱ عیب‌یابی باقی مانده'
          : '${auth.credits} عیب‌یابی باقی مانده';
    } else {
      statusLine = '${auth.credits} بار عیب‌یابی';
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShopScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isGolden
                      ? [Colors.amber.shade700, Colors.orange.shade900]
                      : noCredits
                          ? [
                              theme.colorScheme.error.withOpacity(0.12),
                              theme.cardColor,
                            ]
                          : [theme.cardColor, theme.cardColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isGolden
                      ? Colors.amberAccent
                      : (lowCredits || noCredits)
                          ? theme.colorScheme.secondary.withOpacity(0.5)
                          : theme.dividerColor,
                  width: isGolden || lowCredits || noCredits ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isGolden
                          ? Colors.white.withAlpha(51)
                          : theme.colorScheme.primary.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGolden
                          ? Icons.workspace_premium_rounded
                          : Icons.account_balance_wallet_rounded,
                      color: isGolden ? Colors.white : theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGolden ? 'اشتراک طلایی' : 'موجودی اعتبار شما',
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusLine,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isGolden)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      ),
                      child: Text(
                        noCredits ? 'شارژ' : 'افزایش',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (lowCredits) ...[
          const SizedBox(height: 8),
          Text(
            'پیشنهاد: بسته ۱۰تایی معمولاً هزینه هر عیب‌یابی را کمتر می‌کند.',
            style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.3),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _CarSearchSheet extends StatefulWidget {
  final List<Car> cars;
  final Car? selectedCar;
  final ThemeData theme;
  final void Function(Car) onCarSelected;

  const _CarSearchSheet({
    required this.cars,
    required this.selectedCar,
    required this.theme,
    required this.onCarSelected,
  });

  @override
  State<_CarSearchSheet> createState() => _CarSearchSheetState();
}

class _CarSearchSheetState extends State<_CarSearchSheet> {
  final _searchController = TextEditingController();
  late List<Car> _filteredCars;

  @override
  void initState() {
    super.initState();
    _filteredCars = widget.cars;
    _searchController.addListener(_filterCars);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCars);
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String text) {
    return text
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ی')
        .replaceAll('ة', 'ه')
        .replaceAll('\u200c', '')
        .replaceAll(' ', '')
        .toLowerCase();
  }

  void _filterCars() {
    final query = _normalize(_searchController.text);
    setState(() {
      if (query.isEmpty) {
        _filteredCars = widget.cars;
      } else {
        _filteredCars = widget.cars.where((car) {
          return _normalize(car.fullName).contains(query) ||
              _normalize(car.brand).contains(query) ||
              _normalize(car.model).contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'انتخاب خودرو',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'نام خودرو را جستجو کنید... (مثلاً پژو ۲۰۶)',
                    hintStyle:
                        TextStyle(color: theme.hintColor, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: theme.hintColor),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (_, value, __) => value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: _searchController.clear,
                            )
                          : const SizedBox.shrink(),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_filteredCars.length} خودرو یافت شد',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredCars.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: theme.hintColor),
                        const SizedBox(height: 12),
                        Text(
                          'خودرویی با این نام یافت نشد',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredCars.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.dividerColor.withAlpha(76),
                    ),
                    itemBuilder: (context, index) {
                      final car = _filteredCars[index];
                      final isSelected =
                          car.id == widget.selectedCar?.id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        tileColor: isSelected
                            ? theme.colorScheme.primary.withAlpha(20)
                            : null,
                        title: Text(
                          car.fullName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded,
                                color: theme.colorScheme.primary)
                            : null,
                        onTap: () => widget.onCarSelected(car),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
