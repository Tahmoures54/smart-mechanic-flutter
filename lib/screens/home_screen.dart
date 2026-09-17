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
import '../widgets/enamad_badge.dart';
import '../widgets/home_promo_carousel.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'record_screen.dart';
import 'shop_screen.dart';
import 'terms_screen.dart';

part 'home_screen_widgets.dart';

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
              const SizedBox(height: 12),
              HomePromoCarousel(
                onDiagnose: _diagnose,
                onAudio: _recordAudio,
                onShop: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
              ),
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

              const _WhyItWorksSection(),
              const SizedBox(height: 18),

              const _SupportCard(),
              const SizedBox(height: 20),
              const Center(child: EnamadBadge()),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
