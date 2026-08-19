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

      // ✅ مرتب‌سازی لیست خودروها بر اساس نام (حروف الفبا)
      cars.sort((a, b) => a.fullName.compareTo(b.fullName));

      setState(() {
        _cars = cars;
        if (cars.isNotEmpty && _selectedCar == null && !_isCustomCar) {
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  bool _validateYear(String year) {
    final n = int.tryParse(year);
    if (n == null) return false;
    final shamsi = n >= 1340 && n <= 1410;
    final gregorian = n >= 1960 && n <= 2030;
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
      _showSnack('لطفاً نام و مدل خودروی خود را بنویسید.');
      return false;
    }

    final year = _yearController.text.trim();
    if (year.isEmpty || !_validateYear(year)) {
      _showSnack('سال ساخت را وارد کنید (مثلاً ۱۴۰۳ شمسی یا ۲۰۲۴ میلادی).');
      return false;
    }

    if (requireDescription && _descController.text.trim().length < 5) {
      _showSnack('لطفاً مشکل را کمی واضح‌تر بنویسید.');
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
      id: _isCustomCar ? 'custom' : _selectedCar!.id,
      name: _isCustomCar
          ? _customCarController.text.trim()
          : _selectedCar!.fullName,
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
        title: Text(
          'اعتبار ناکافی',
          style: TextStyle(color: theme.textTheme.titleLarge?.color),
        ),
        content: Text(
          'برای ادامه گفتگو و عیب‌یابی دقیق، نیاز به تهیه اعتبار دارید.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تهیه اعتبار'),
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
                icon: const Icon(Icons.history),
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
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
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
                        if (!_isCustomCar) {
                          _customCarController.clear();
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
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDescriptionField(theme),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 28),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _diagnose,
                  label: Text(
                    'ارسال به مکانیک هوشمند',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: theme.hintColor.withOpacity(0.2),
                        thickness: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.hintColor.withOpacity(0.2),
                        ),
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
                        color: theme.hintColor.withOpacity(0.2),
                        thickness: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.mic_none_rounded, size: 30),
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
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
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
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ✅ بخش انتخاب خودرو (دکمه باز کردن مودال جستجو)
  // ─────────────────────────────────────────
  Widget _buildCarSelector(ThemeData theme) {
    if (_isCustomCar) {
      return SizedBox(
        height: 56,
        child: TextField(
          controller: _customCarController,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
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
                color: theme.colorScheme.secondary.withOpacity(0.5),
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasCarLoadError && _cars.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'خطا در بارگذاری',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => _loadCars(),
            )
          ],
        ),
      );
    }

    if (_cars.isEmpty && !_isLoadingCars) {
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

    // ✅ تبدیل به دکمه برای باز کردن Bottom Sheet جستجو
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  // ─────────────────────────────────────────
  // ✅ مودال جستجو و فیلتر خودروها
  // ─────────────────────────────────────────
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
              setState(() => _selectedCar = car);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildCommonIssues(ThemeData theme) {
    if (_isCustomCar || _selectedCar == null) {
      return const SizedBox.shrink();
    }

    final issues = _selectedCar!.commonIssues
        .where((issue) => !issue.contains('اطلاعات دقیقی'))
        .toList();

    if (issues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مشکلات شایع این خودرو (برای انتخاب ضربه بزنید):',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: issues.map((issue) {
              return ActionChip(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                side: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
                labelStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                ),
                label: Text(issue),
                onPressed: () {
                  setState(() {
                    _descController.text = issue;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextField(
      controller: _descController,
      maxLines: 4,
      maxLength: 300,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, height: 1.5),
      decoration: InputDecoration(
        hintText:
            'مثال: صبح‌ها که هوا سرده، موقع استارت زدن ماشین ریپ میزنه...',
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
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'برای استفاده از هوش مصنوعی و دریافت ۱ اعتبار رایگان، وارد حساب کاربری خود شوید.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            style: TextButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text('ورود',
                style: TextStyle(fontWeight: FontWeight.bold)),
          )
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
            theme.colorScheme.primary.withOpacity(0.9),
            theme.colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
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
            'هوش مصنوعی ما با تحلیل میلیون‌ها دادهٔ تعمیرگاهی آموزش دیده است تا دقیق‌ترین تشخیص را به شما ارائه دهد.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
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
                'با آگاهی و تشخیص زودهنگام، نگذارید یک ایراد کوچک به موتور آسیب جدی وارد کند.',
          ),
          const SizedBox(height: 16),
          _buildPromoItem(
            theme,
            icon: Icons.handshake_rounded,
            title: 'دستیار هوشمند مکانیک شما',
            desc:
                'تشخیص دقیق اولین قدم است؛ با داشتن گزارش کامل، به مکانیک خود کمک کنید.',
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
            color: Colors.white.withOpacity(0.15),
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
                  color: Colors.white.withOpacity(0.8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: auth.isGolden
              ? [Colors.amber.shade700, Colors.orange.shade900]
              : [theme.cardColor, theme.cardColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: auth.isGolden ? Colors.amberAccent : theme.dividerColor,
          width: auth.isGolden ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    auth.isGolden
                        ? Icons.workspace_premium_rounded
                        : Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.isGolden
                            ? 'اشتراک طلایی'
                            : 'موجودی اعتبار شما',
                        style: TextStyle(
                          color: auth.isGolden
                              ? Colors.white
                              : theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.isGolden
                            ? 'فعال می‌باشد'
                            : '${auth.credits} بار عیب‌یابی',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!auth.isGolden)
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
                MaterialPageRoute(builder: (context) => const ShopScreen()),
              ),
              child: const Text(
                'شارژ حساب',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ ویجت مجزا برای شیت پایین صفحه (جستجوی خودرو)
// ─────────────────────────────────────────────────────────────────────────────
class _CarSearchSheet extends StatefulWidget {
  final List<Car> cars;
  final Car? selectedCar;
  final ThemeData theme;
  final Function(Car) onCarSelected;

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
  List<Car> _filteredCars = [];

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

  void _filterCars() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredCars = widget.cars.where((car) {
        return car.fullName.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // ── هدر شیت ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: widget.theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: widget.theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'انتخاب خودرو',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'نام خودرو را جستجو کنید... (مثلاً پژو ۲۰۶)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: widget.theme.scaffoldBackgroundColor,
                  ),
                ),
              ],
            ),
          ),
          // ── لیست خودروها ──
          Expanded(
            child: _filteredCars.isEmpty
                ? Center(
                    child: Text(
                      'خودرویی با این نام یافت نشد',
                      style: TextStyle(color: widget.theme.hintColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredCars.length,
                    itemBuilder: (context, index) {
                      final car = _filteredCars[index];
                      final isSelected = car.id == widget.selectedCar?.id;
                      return Container(
                        color: isSelected
                            ? widget.theme.colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        child: ListTile(
                          title: Text(
                            car.fullName,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? widget.theme.colorScheme.primary
                                  : widget.theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  color: widget.theme.colorScheme.primary)
                              : null,
                          onTap: () => widget.onCarSelected(car),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
