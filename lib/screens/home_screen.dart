import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/car.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/share_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/car_selector_widget.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'record_screen.dart';
import 'shop_screen.dart';
import 'terms_screen.dart';

/// صفحه اصلی — مسیر ساده: خودرو → شرح مشکل → ارسال
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
  SharedPreferences? _prefs;
  String? _pendingCarId;

  @override
  void initState() {
    super.initState();
    _yearController.addListener(_saveDraft);
    _customCarController.addListener(_saveDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreDraft();
      await _loadCars();
    });
  }

  @override
  void dispose() {
    _yearController.removeListener(_saveDraft);
    _customCarController.removeListener(_saveDraft);
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
      final cars = await context.read<ApiService>().getCars();
      if (!mounted) return;
      cars.sort((a, b) => a.fullName.compareTo(b.fullName));
      setState(() {
        _cars = cars;
        if (_selectedCar != null) {
          final found = cars.where((c) => c.id == _selectedCar!.id);
          _selectedCar = found.isNotEmpty ? found.first : null;
        } else if (_pendingCarId != null && !_isCustomCar) {
          final found = cars.where((c) => c.id == _pendingCarId);
          _selectedCar = found.isNotEmpty ? found.first : null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _hasCarLoadError = true);
        _snack('لیست وسایل نقلیه لود نشد. فایل داخلی یا اینترنت را چک کنید.');
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

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;
    final year = prefs.getString(Constants.keyLastYear) ?? '';
    final custom = prefs.getString(Constants.keyLastCustomCar) ?? '';
    final carId = prefs.getString(Constants.keyLastCarId);
    setState(() {
      if (year.isNotEmpty) _yearController.text = year;
      if (carId == 'custom' && custom.length >= 2) {
        _isCustomCar = true;
        _customCarController.text = custom;
      } else {
        _pendingCarId = carId;
      }
    });
  }

  void _saveDraft() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(prefs.setString(Constants.keyLastYear, _yearController.text.trim()));
    if (_isCustomCar) {
      unawaited(prefs.setString(Constants.keyLastCarId, 'custom'));
      unawaited(
        prefs.setString(
          Constants.keyLastCustomCar,
          _customCarController.text.trim(),
        ),
      );
    } else if (_selectedCar != null) {
      unawaited(prefs.setString(Constants.keyLastCarId, _selectedCar!.id));
    }
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  bool _validYear(String year) {
    final n = int.tryParse(year);
    if (n == null) return false;
    return (n >= 1340 && n <= 1420) || (n >= 1960 && n <= 2040);
  }

  bool _validate({required bool needDescription}) {
    final auth = context.read<AuthProvider>();

    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return false;
    }
    if (!_isCustomCar && _selectedCar == null) {
      _snack('اول خودرو را انتخاب کنید.');
      return false;
    }
    if (_isCustomCar && _customCarController.text.trim().length < 2) {
      _snack('نام خودرو را بنویسید (مثلاً تویوتا کمری).');
      return false;
    }
    final year = _yearController.text.trim();
    if (year.isEmpty || !_validYear(year)) {
      _snack('سال ساخت را وارد کنید (مثلاً ۱۴۰۲ یا ۲۰۲۳).');
      return false;
    }
    if (needDescription && _descController.text.trim().length < 5) {
      _snack('مشکل را کمی واضح‌تر بنویسید.');
      return false;
    }
    if (!auth.canDiagnose) {
      _showNoCreditDialog();
      return false;
    }
    return true;
  }

  ({String id, String name, String year}) _carInfo() => (
        id: _isCustomCar ? 'custom' : (_selectedCar?.id ?? 'custom'),
        name: _isCustomCar
            ? _customCarController.text.trim()
            : (_selectedCar?.fullName ?? ''),
        year: _yearController.text.trim(),
      );

  void _diagnose() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validate(needDescription: true)) return;

    final car = _carInfo();
    final text = _descController.text.trim();
    _descController.clear();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          carName: car.name,
          carId: car.id,
          year: car.year,
          initialUserMessage: text,
          isCustomCar: _isCustomCar,
        ),
      ),
    );
  }

  void _recordAudio() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validate(needDescription: false)) return;

    final car = _carInfo();
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
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('اعتبار کافی نیست'),
        content: const Text(
          'سهمیه رایگان این ماه تمام شده.\n'
          'برای ادامه می‌توانید بسته اعتبار یا اشتراک طلایی بگیرید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('بعداً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مشاهده بسته‌ها'),
          ),
        ],
      ),
    ).then((go) {
      if (go == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const BrandAppBarTitle(),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'قوانین استفاده',
              icon: const Icon(Icons.gavel_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
            ),
            if (auth.isAuthenticated)
              IconButton(
                tooltip: 'تاریخچه',
                icon: const Icon(Icons.history_rounded),
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
                    color: secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          color: secondary,
          onRefresh: () async {
            await _loadCars(isRefresh: true);
            if (auth.isAuthenticated) {
              await auth.fetchProfile(force: true);
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + (keyboard > 0 ? keyboard * 0.15 : 0),
            ),
            children: [
              _StatusBanner(auth: auth),
              const SizedBox(height: 18),
              Text(
                'عیب‌یابی در ۳ قدم — کمتر از ۲ دقیقه',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              _SectionLabel(number: '۱', title: 'وسیله نقلیه را انتخاب کنید'),
              const SizedBox(height: 10),
              _CarCard(
                isCustom: _isCustomCar,
                cars: _cars,
                selectedCar: _selectedCar,
                isLoading: _isLoadingCars && !_isRefreshing,
                hasError: _hasCarLoadError && _cars.isEmpty,
                customController: _customCarController,
                yearController: _yearController,
                onRetry: () => _loadCars(),
                onCarSelected: (c) => setState(() {
                  _selectedCar = c;
                  _saveDraft();
                }),
                onToggleCustom: () => setState(() {
                  _isCustomCar = !_isCustomCar;
                  _selectedCar = null;
                  if (!_isCustomCar) {
                    _customCarController.clear();
                  }
                  _saveDraft();
                }),
              ),

              // بخش مشکلات رایج حذف شد

              const SizedBox(height: 22),

              _SectionLabel(number: '۲', title: 'مشکل را بنویسید'),
              const SizedBox(height: 10),
              TextField(
                controller: _descController,
                maxLines: 4,
                maxLength: 300,
                textInputAction: TextInputAction.done,
                onEditingComplete: () =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: const TextStyle(height: 1.5),
                decoration: InputDecoration(
                  hintText:
                      'مثال: صبح‌ها که هوا سرد است، موقع استارت ریپ می‌زند و صدای تق‌تق می‌آید...',
                  hintStyle: TextStyle(
                    color: theme.hintColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle:
                      TextStyle(color: theme.hintColor, fontSize: 11),
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
                    borderSide: BorderSide(color: secondary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              _SectionLabel(number: '۳', title: 'ارسال برای عیب‌یابی'),
              const SizedBox(height: 12),
              _DiagnoseCtaButton(onPressed: _diagnose),
              const SizedBox(height: 12),
              _AudioCtaButton(onPressed: _recordAudio),
              const SizedBox(height: 18),
              const _MechanicAllyCard(),
              const SizedBox(height: 22),

              // توضیحات و متقاعدسازی — بعد از مسیر عیب‌یابی
              const _WhyItWorksSection(),
              const SizedBox(height: 18),

              // درخواست حمایت (استارتاپ نوپا)
              const _SupportCard(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// دکمه‌های اقدام — ارتفاع بیشتر و کنتراست واضح برای خوانایی
// ─────────────────────────────────────────────────────────────────────────────
class _DiagnoseCtaButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DiagnoseCtaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSecondary;
    return Material(
      color: theme.colorScheme.secondary,
      elevation: 3,
      shadowColor: theme.colorScheme.secondary.withOpacity(0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.send_rounded, color: fg, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ارسال به مکانیک هوشمند',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تحلیل فوری با هوش مصنوعی',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg.withOpacity(0.82),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.auto_awesome_rounded, color: fg, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioCtaButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AudioCtaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: secondary.withOpacity(0.55), width: 1.6),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.mic_rounded, color: secondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ضبط صدای موتور',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اگر نوشتن سخت است، صدا را بفرستید',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: theme.hintColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// پیام به مکانیک‌ها — شریک، نه رقیب
// ─────────────────────────────────────────────────────────────────────────────
class _MechanicAllyCard extends StatelessWidget {
  const _MechanicAllyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orange = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            orange.withOpacity(0.32),
            theme.cardColor.withOpacity(0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: orange.withOpacity(0.45), width: 1.4),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.handshake_rounded, color: orange, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'مکانیک هستی؟',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'مکانیک هوشمند آمده تا به تو کمک کند — رقیبت نیست.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w800,
              color: orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'مشتری با شرح واضح و تشخیص اولیه می‌آید؛ '
            'تعمیر و نظر نهایی کار توست. با هم ماشین را زودتر راه می‌اندازیم.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: theme.colorScheme.onSurface.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// بخش متقاعدسازی — بعد از مراحل عیب‌یابی
// کاهش اضطراب، حس کنترل، جلوگیری از ضرر، دعوت به پلن
// ─────────────────────────────────────────────────────────────────────────────
class _WhyItWorksSection extends StatelessWidget {
  const _WhyItWorksSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final auth = context.watch<AuthProvider>();
    final golden = auth.isAuthenticated && auth.isGoldenActive;

    final points = const [
      (
        icon: Icons.verified_user_rounded,
        title: 'با چشم باز برو تعمیرگاه',
        subtitle:
            'وقتی علت احتمالی را می‌دانی، گفتگو با مکانیک شفاف‌تر می‌شود و کار زودتر جلو می‌رود.',
      ),
      (
        icon: Icons.savings_rounded,
        title: 'جلوی تعویض قطعه اشتباه را بگیر',
        subtitle:
            'یک حدس غلط گران تمام می‌شود. اشتراک طلایی کمتر از یک تعویض روغن در ماه است.',
      ),
      (
        icon: Icons.nightlight_round,
        title: 'نیمه‌شب و وسط جاده هم تنها نیستی',
        subtitle:
            'قبل از اینکه اضطراب بالا برود، در چند ثانیه تصویر روشنی از مشکل می‌گیری.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                secondary.withOpacity(0.16),
                theme.cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: secondary.withOpacity(0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandLogo(size: 28, showGlow: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'چرا مکانیک هوشمند؟',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'بیشتر راننده‌ها با شنیدن صدای عجیب، مضطرب می‌شوند و چشم‌بسته می‌روند تعمیرگاه. '
                'اینجا اول می‌فهمی ماجرا از چه قرار است — بعد تصمیم می‌گیری.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.65,
                  color: theme.colorScheme.onSurface.withOpacity(0.82),
                ),
              ),
              const SizedBox(height: 16),
              ...points.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: secondary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(p.icon, color: secondary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p.subtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.canvasColor.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  golden
                      ? 'اشتراک طلایی‌ات فعاله. از عیب‌یابی نامحدود استفاده کن و اگر دوستت هم ماشین داره، معرفیش کن.'
                      : 'راننده‌هایی که قبل از مراجعه عیب‌یابی می‌کنند، با اعتماد بیشتری کنار مکانیک می‌ایستند و کارشان سریع‌تر جلو می‌رود.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.88),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (golden) {
                      ShareService.shareApp(
                        referralCode: auth.referralCode,
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShopScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(
                    golden ? 'معرفی به دوستان' : 'پلن مناسبت را انتخاب کن',
                  ),
                ),
              ),
              if (!golden) ...[
                const SizedBox(height: 8),
                Text(
                  'طلایی ۳۰ روزه: عیب‌یابی نامحدود — کمتر از هزینه یک حدس اشتباه در تعمیرگاه.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// کارت حمایت از استارتاپ + شیت پیشنهادها
// ─────────────────────────────────────────────────────────────────────────────
class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            secondary.withOpacity(0.15),
            theme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.favorite_rounded, color: secondary, size: 32),
          const SizedBox(height: 10),
          Text(
            'ما یک استارتاپ نوپا هستیم',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'حمایت تو یعنی سرور پایدارتر، تشخیص دقیق‌تر، و این‌که این ابزار برای راننده‌های بیشتری زنده بماند. '
            'حتی یک اشتراک‌گذاری ساده هم برای ما خیلی می‌ارزد.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.hintColor,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _showSupportActions(context),
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: const Text(
                'چطور حمایت کنم؟',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showSupportActions(BuildContext context) {
  final theme = Theme.of(context);
  final auth = context.read<AuthProvider>();
  final code = auth.referralCode;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'چند راه ساده برای حمایت',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'هر کدام را که راحت‌تری انتخاب کن — همه به رشد این ابزار کمک می‌کند.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.hintColor, height: 1.45),
              ),
              const SizedBox(height: 14),
              _SupportActionTile(
                icon: Icons.share_rounded,
                title: 'معرفی به دوستان',
                subtitle: 'برای کسی بفرست که ماشینش صدا می‌دهد',
                onTap: () {
                  Navigator.pop(ctx);
                  ShareService.shareApp(referralCode: code);
                },
              ),
              _SupportActionTile(
                icon: Icons.chat_rounded,
                title: 'وضعیت واتساپ',
                subtitle: 'متن آماده را در استوری واتساپ بگذار',
                onTap: () async {
                  Navigator.pop(ctx);
                  final text = ShareService.whatsappStatus(referralCode: code);
                  await ShareService.copy(text);
                  await ShareService.shareToWhatsApp(text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'متن کپی شد. می‌توانی آن را در وضعیت واتساپ هم بچسبانی.',
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                },
              ),
              _SupportActionTile(
                icon: Icons.badge_rounded,
                title: 'پروفایل واتساپ',
                subtitle: 'متن «درباره» را کپی کن و در پروفایل بچسبان',
                onTap: () async {
                  Navigator.pop(ctx);
                  await ShareService.copy(ShareService.whatsappAbout());
                  if (!context.mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('متن پروفایل آماده است'),
                      content: const Text(
                        'متن معرفی کپی شد.\n\n'
                        'واتساپ → تنظیمات → نمایه → درباره\n'
                        'متن را بچسبان تا دوستانت مکانیک هوشمند را ببینند.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('باشه'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            ShareService.shareToWhatsApp(
                              ShareService.whatsappAbout(),
                            );
                          },
                          child: const Text('باز کردن واتساپ'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _SupportActionTile(
                icon: Icons.workspace_premium_rounded,
                title: 'خرید پلن',
                subtitle: 'مستقیم‌ترین حمایت؛ عیب‌یابی نامحدود برای خودت',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  );
                },
              ),
              if (code != null && code.isNotEmpty)
                _SupportActionTile(
                  icon: Icons.card_giftcard_rounded,
                  title: 'دعوت با کد معرف',
                  subtitle: 'کد $code را برای دوستت بفرست؛ هر دو سود می‌برید',
                  onTap: () {
                    Navigator.pop(ctx);
                    ShareService.shareApp(referralCode: code);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class _SupportActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: secondary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: theme.hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String number;
  final String title;

  const _SectionLabel({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: secondary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: secondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final AuthProvider auth;
  const _StatusBanner({required this.auth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    if (!auth.isAuthenticated) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              secondary.withOpacity(0.28),
              theme.cardColor.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: secondary.withOpacity(0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.waving_hand_rounded, color: secondary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سلام! آماده‌ای عیب‌یابی کنی؟',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ورود رایگان — تا ۲ عیب‌یابی هدیه در ماه',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ورود',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final golden = auth.isGoldenActive;
    final free = auth.remainingFree;
    final paid = auth.paidCredits;

    String line;
    if (golden) {
      line = 'اشتراک طلایی فعال است';
    } else if (free > 0 && paid <= 0) {
      line = '$free عیب‌یابی رایگان این ماه باقی مانده';
    } else if (free > 0) {
      line = '$paid اعتبار · $free رایگان این ماه';
    } else if (paid > 0) {
      line = '$paid اعتبار باقی مانده';
    } else {
      line = 'اعتبار تمام شده — برای ادامه شارژ کنید';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        ),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: golden
                ? LinearGradient(
                    colors: [Colors.amber.shade700, Colors.orange.shade800],
                  )
                : null,
            color: golden ? null : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: golden
                  ? Colors.amberAccent
                  : (paid <= 0 && free <= 0)
                      ? theme.colorScheme.error.withOpacity(0.4)
                      : theme.dividerColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                golden
                    ? Icons.workspace_premium_rounded
                    : Icons.account_balance_wallet_rounded,
                color: golden ? Colors.white : secondary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: golden ? Colors.white : null,
                  ),
                ),
              ),
              if (!golden)
                Text(
                  'شارژ',
                  style: TextStyle(
                    color: secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final bool isCustom;
  final List<Car> cars;
  final Car? selectedCar;
  final bool isLoading;
  final bool hasError;
  final TextEditingController customController;
  final TextEditingController yearController;
  final VoidCallback onRetry;
  final ValueChanged<Car> onCarSelected;
  final VoidCallback onToggleCustom;

  const _CarCard({
    required this.isCustom,
    required this.cars,
    required this.selectedCar,
    required this.isLoading,
    required this.hasError,
    required this.customController,
    required this.yearController,
    required this.onRetry,
    required this.onCarSelected,
    required this.onToggleCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCustom)
            TextField(
              controller: customController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'نام و مدل خودرو',
                hintText: 'مثال: تویوتا کمری یا هوندا ۱۲۵',
                prefixIcon: const Icon(Icons.edit_rounded, size: 20),
                filled: true,
                fillColor: theme.canvasColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            )
          else
            CarSelectorWidget(
              cars: cars,
              selectedCar: selectedCar,
              isLoading: isLoading,
              hasError: hasError,
              onRetry: onRetry,
              onCarSelected: onCarSelected,
            ),
          const SizedBox(height: 12),
          TextField(
            controller: yearController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'سال ساخت',
              hintText: '۱۴۰۲ یا ۲۰۲۳',
              counterText: '',
              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
              filled: true,
              fillColor: theme.canvasColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggleCustom,
              style: TextButton.styleFrom(
                foregroundColor: secondary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                isCustom
                    ? '← بازگشت به لیست وسایل نقلیه'
                    : 'وسیله من در لیست نیست',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
