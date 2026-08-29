import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../models/car.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/car_selector_widget.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'record_screen.dart';
import 'shop_screen.dart';

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
      final cars = await context.read<ApiService>().getCars();
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
    } catch (_) {
      if (mounted) {
        setState(() => _hasCarLoadError = true);
        _snack('لیست خودروها لود نشد. اینترنت را چک کنید.');
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

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'مکانیک هوشمند',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _StatusBanner(auth: auth),
              const SizedBox(height: 20),

              // ── مرحله ۱ ──
              _SectionLabel(
                number: '۱',
                title: 'خودرو را انتخاب کنید',
              ),
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
                onCarSelected: (c) => setState(() => _selectedCar = c),
                onToggleCustom: () => setState(() {
                  _isCustomCar = !_isCustomCar;
                  if (!_isCustomCar && _cars.isNotEmpty) {
                    _selectedCar = _cars.first;
                    _customCarController.clear();
                  } else {
                    _selectedCar = null;
                  }
                }),
              ),

              // مشکلات شایع
              if (!_isCustomCar &&
                  _selectedCar != null &&
                  _selectedCar!.commonIssues
                      .where((e) => !e.contains('اطلاعات دقیقی'))
                      .isNotEmpty) ...[
                const SizedBox(height: 8),
                _CommonIssueChips(
                  issues: _selectedCar!.commonIssues
                      .where((e) => !e.contains('اطلاعات دقیقی'))
                      .toList(),
                  onPick: (s) => setState(() => _descController.text = s),
                ),
              ],

              const SizedBox(height: 22),

              // ── مرحله ۲ ──
              _SectionLabel(
                number: '۲',
                title: 'مشکل را بنویسید',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descController,
                maxLines: 4,
                maxLength: 300,
                textInputAction: TextInputAction.done,
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
                  counterStyle: TextStyle(color: theme.hintColor, fontSize: 11),
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

              // ── مرحله ۳ ──
              _SectionLabel(
                number: '۳',
                title: 'ارسال برای عیب‌یابی',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _diagnose,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 22),
                  label: const Text(
                    'شروع عیب‌یابی هوشمند',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _recordAudio,
                  icon: Icon(Icons.mic_rounded, color: secondary),
                  label: Text(
                    'یا صدای موتور را ضبط کنید',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: secondary.withOpacity(0.5), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تحلیل فقط راهنماست و جای بازدید حضوری مکانیک را نمی‌گیرد.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.hintColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ویجت‌های کمکی صفحه اصلی
// ═══════════════════════════════════════════════════════════

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
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: secondary.withOpacity(0.35)),
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'با ورود: تا ۲ عیب‌یابی رایگان در ماه',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ورود', style: TextStyle(fontWeight: FontWeight.bold)),
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
                hintText: 'مثال: تویوتا کمری',
                prefixIcon: const Icon(Icons.edit_rounded, size: 20),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
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
              fillColor: theme.scaffoldBackgroundColor,
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
                isCustom ? '← بازگشت به لیست خودروها' : 'خودروی من در لیست نیست',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommonIssueChips extends StatelessWidget {
  final List<String> issues;
  final ValueChanged<String> onPick;

  const _CommonIssueChips({required this.issues, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 6),
          child: Text(
            'مشکلات شایع این خودرو — لمس کنید تا پر شود:',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: issues.take(6).map((issue) {
            return ActionChip(
              label: Text(issue, style: TextStyle(fontSize: 12, color: secondary)),
              backgroundColor: secondary.withOpacity(0.1),
              side: BorderSide(color: secondary.withOpacity(0.25)),
              onPressed: () => onPick(issue),
            );
          }).toList(),
        ),
      ],
    );
  }
}
