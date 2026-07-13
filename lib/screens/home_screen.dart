import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/car.dart';
import 'login_screen.dart';
import 'shop_screen.dart';
import 'history_screen.dart';
import 'result_screen.dart';
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
  bool _isLoading = false;
  bool _isLoadingCars = true; // اضافه شدن استیت لودینگ برای لیست ماشین‌ها

  @override
  void initState() {
    super.initState();
    // استفاده از PostFrameCallback برای دسترسی امن به context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCars();
    });
  }

  @override
  void dispose() {
    // رفع نشتی حافظه
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCars() async {
    setState(() => _isLoadingCars = true);
    try {
      final api = context.read<ApiService>();
      final cars = await api.getCars();
      if (mounted) {
        setState(() {
          _cars = cars;
          if (cars.isNotEmpty) _selectedCar = cars.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading cars: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در دریافت لیست خودروها. لطفاً بعداً تلاش کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCars = false);
    }
  }

  Future<void> _diagnose() async {
    final auth = context.read<AuthProvider>();
    
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      return;
    }

    if (_selectedCar == null || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً خودرو و شرح خرابی را مشخص کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.diagnoseByDescription(
        auth.token!,
        _selectedCar!.id,
        _descController.text,
      );
      
      if (!mounted) return;
      
      auth.fetchProfile(); // به‌روزرسانی اعتبار
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ResultScreen(resultText: result)),
      );
      
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        _showNoCreditDialog();
      } else if (e.statusCode == 401) {
        auth.logout();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نشست شما منقضی شده، لطفاً دوباره وارد شوید.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Diagnose network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطای شبکه. اتصال اینترنت خود را بررسی کنید.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNoCreditDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text('اعتبار ناکافی', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        content: Text('برای پرسش سوال، نیاز به خرید اعتبار دارید.',
            style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopScreen()));
            },
            child: Text('فروشگاه', style: TextStyle(color: theme.colorScheme.secondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>(); // استفاده از watch به جای Provider.of
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('مکانیک هوشمند'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
            )
          else
            TextButton(
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (context) => const LoginScreen())),
              child: Text('ورود', style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.isAuthenticated)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: auth.isGolden ? Colors.amber[800] : theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      auth.isGolden ? 'اشتراک طلایی فعال است' : 'اعتبار شما: ${auth.credits} سوال',
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                    ),
                    if (!auth.isGolden)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (context) => const ShopScreen())),
                        child: const Text('ارتقا / خرید'),
                      ),
                  ],
                ),
              ),
            Text('خودروی خود را انتخاب کنید:', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            // نمایش لودینگ برای Dropdown ماشین‌ها
            _isLoadingCars
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.secondary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Car>(
                        dropdownColor: theme.cardColor,
                        value: _selectedCar,
                        isExpanded: true,
                        items: _cars.map((car) {
                          return DropdownMenuItem<Car>(
                            value: car,
                            child: Text(car.fullName, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCar = val),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            Text('شرح خرابی:', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'مثلاً: ماشین موقع استارت زدن صدای تق تق میده...',
                hintStyle: TextStyle(color: theme.hintColor),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _diagnose,
              child: _isLoading
                  ? CircularProgressIndicator(color: theme.colorScheme.onSecondary)
                  : Text('عیب‌یابی کن',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSecondary)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('شروع ضبط صدا برای عیب‌یابی'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordScreen()),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}   
