import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:collection/collection.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/car.dart';
import 'login_screen.dart';
import 'shop_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import 'record_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/car_selector_widget.dart';

// NOTE: File restored. See repo history f5b19995 for full UI if truncated.
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
    } catch (e) {
      if (mounted) {
        setState(() => _hasCarLoadError = true);
        _showSnack('خطا در دریافت لیست خودروها.');
      }
    } finally {
      if (mounted) setState(() { _isLoadingCars = false; _isRefreshing = false; });
    }
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  bool _validateYear(String year) {
    final n = int.tryParse(year);
    if (n == null) return false;
    return (n >= 1340 && n <= 1420) || (n >= 1960 && n <= 2040);
  }

  bool _validateInputs({required bool requireDescription}) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return false;
    }
    if (!_isCustomCar && _selectedCar == null) {
      _showSnack('لطفاً خودرو را انتخاب کنید.');
      return false;
    }
    if (_isCustomCar && _customCarController.text.trim().length < 2) {
      _showSnack('نام خودرو را بنویسید.');
      return false;
    }
    final year = _yearController.text.trim();
    if (year.isEmpty || !_validateYear(year)) {
      _showSnack('سال ساخت را وارد کنید.');
      return false;
    }
    if (requireDescription && _descController.text.trim().length < 5) {
      _showSnack('مشکل را کمی واضح‌تر بنویسید.');
      return false;
    }
    if (!auth.canDiagnose) {
      _showNoCreditDialog();
      return false;
    }
    return true;
  }

  ({String id, String name, String year}) _getCarInfo() => (
    id: _isCustomCar ? 'custom' : (_selectedCar?.id ?? 'custom'),
    name: _isCustomCar ? _customCarController.text.trim() : (_selectedCar?.fullName ?? ''),
    year: _yearController.text.trim(),
  );

  void _diagnose() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateInputs(requireDescription: true)) return;
    final car = _getCarInfo();
    final msg = _descController.text.trim();
    _descController.clear();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        carName: car.name, carId: car.id, year: car.year,
        initialUserMessage: msg, isCustomCar: _isCustomCar,
      ),
    ));
  }

  void _onVoiceRecordTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateInputs(requireDescription: false)) return;
    final car = _getCarInfo();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RecordScreen(carName: car.name, carId: car.id, year: car.year),
    ));
  }

  void _showNoCreditDialog() {
    final theme = Theme.of(context);
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اعتبار تمام شده'),
        content: const Text('سهمیه رایگان این ماه تمام شده. بسته اعتبار یا اشتراک طلایی بگیرید.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بعداً')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مشاهده بسته‌ها'),
          ),
        ],
      ),
    ).then((go) {
      if (go == true && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('مکانیک هوشمند', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            )
          else
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('ورود'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCars(isRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (auth.isAuthenticated)
              ListTile(
                tileColor: theme.cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(auth.isGoldenActive ? 'اشتراک طلایی' : 'موجودی: ${auth.credits}'),
                subtitle: Text(auth.remainingFree > 0 ? '${auth.remainingFree} عیب‌یابی رایگان این ماه' : 'برای شارژ به فروشگاه بروید'),
                trailing: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
                  child: const Text('فروشگاه'),
                ),
              )
            else
              ListTile(
                title: const Text('با ورود تا ۲ عیب‌یابی رایگان در ماه + اعتبار هدیه'),
                trailing: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('شروع'),
                ),
              ),
            const SizedBox(height: 16),
            const Text('۱. مشخصات خودرو', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 7,
                child: _isCustomCar
                    ? TextField(
                        controller: _customCarController,
                        decoration: const InputDecoration(hintText: 'نام خودرو', border: OutlineInputBorder()),
                      )
                    : CarSelectorWidget(
                        cars: _cars,
                        selectedCar: _selectedCar,
                        isLoading: _isLoadingCars && !_isRefreshing,
                        hasError: _hasCarLoadError && _cars.isEmpty,
                        onRetry: () => _loadCars(),
                        onCarSelected: (car) => setState(() { _selectedCar = car; _showCommonIssues = false; }),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'سال *', counterText: '', border: OutlineInputBorder()),
                ),
              ),
            ]),
            TextButton(
              onPressed: () => setState(() {
                _isCustomCar = !_isCustomCar;
                if (!_isCustomCar && _cars.isNotEmpty) _selectedCar = _cars.first;
              }),
              child: Text(_isCustomCar ? 'بازگشت به لیست' : 'خودروی من در لیست نیست'),
            ),
            const SizedBox(height: 16),
            const Text('۲. شرح خرابی', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'مثال: صبح‌ها ماشین ریپ می‌زند...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _diagnose,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('ارسال به مکانیک هوشمند'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _onVoiceRecordTap,
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('ضبط صدای موتور'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
