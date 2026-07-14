import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart'; // شامل ApiException نیز هست
import '../models/car.dart';
import 'login_screen.dart';
import 'shop_screen.dart';
import 'history_screen.dart';
import 'result_screen.dart';
import 'record_screen.dart'; // صفحهٔ ضبط صدا

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
  bool _isLoadingCars = true;

  @override
  void initState() {
    super.initState();
    // بارگذاری خودروها پس از ساخته شدن ویجت
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCars());
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCars() async {
    setState(() => _isLoadingCars = true);
    try {
      final api = context.read<ApiService>();
      final cars = await api.getCars();
      if (!mounted) return;
      setState(() {
        _cars = cars;
        if (cars.isNotEmpty) {
          _selectedCar = cars.first;
        } else {
          _selectedCar = null;
        }
      });
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
    // بستن کیبورد برای دیدن بهتر نتیجه یا لودینگ (بهبود UX)
    FocusManager.instance.primaryFocus?.unfocus();

    final auth = context.read<AuthProvider>();

    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا خودروی خود را انتخاب کنید.')),
      );
      return;
    }

    // اعتبارسنجی دقیق تر طول متن
    if (_descController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً شرح خرابی را کامل‌تر (حداقل ۱۰ حرف) بنویسید.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.diagnose(
        auth.token!,
        _selectedCar!.id,
        _descController.text.trim(),
      );

      if (!mounted) return;

      // به‌روزرسانی موجودی اعتبار پس از تشخیص
      auth.fetchProfile();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(resultText: result),
        ),
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
      debugPrint('Diagnose error: $e');
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
        title: Text('اعتبار ناکافی',
            style: TextStyle(color: theme.textTheme.titleLarge?.color)),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShopScreen()),
              );
            },
            child: Text('فروشگاه',
                style: TextStyle(color: theme.colorScheme.secondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return GestureDetector(
      // اگر کاربر جای خالی کلیک کرد کیبورد بسته شود
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('مکانیک هوشمند'),
          backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
          actions: [
            if (auth.isAuthenticated)
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'تاریخچه',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                ),
              )
            else
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
                child: Text('ورود',
                    style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadCars,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // کارت اعتبار / اشتراک
                if (auth.isAuthenticated) _buildCreditCard(auth, theme),
                const SizedBox(height: 20),

                // بخش انتخاب خودرو
                Text('خودروی خود را انتخاب کنید:',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildCarSelector(theme),

                const SizedBox(height: 20),

                // شرح خرابی
                Text('شرح خرابی:',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDescriptionField(theme),

                const SizedBox(height: 24),

                // دکمهٔ عیب‌یابی متنی
                ElevatedButton.icon(
                  icon: _isLoading 
                      ? const SizedBox.shrink() 
                      : const Icon(Icons.build_circle_outlined),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _diagnose,
                  label: _isLoading
                      ? SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: theme.colorScheme.onSecondary, strokeWidth: 3),
                        )
                      : Text('عیب‌یابی از طریق متن',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondary)),
                ),

                const SizedBox(height: 16),
                
                // خط جداکننده زیبا
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.hintColor.withOpacity(0.3), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('یا', style: TextStyle(color: theme.hintColor)),
                    ),
                    Expanded(child: Divider(color: theme.hintColor.withOpacity(0.3), thickness: 1)),
                  ],
                ),
                
                const SizedBox(height: 16),

                // دکمهٔ ضبط صدا (غیرفعال در زمان لودینگ بالا)
                ElevatedButton.icon(
                  icon: const Icon(Icons.mic, size: 28),
                  label: const Text('شروع ضبط صدای خودرو'),
                  onPressed: _isLoading ? null : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecordScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    backgroundColor: theme.colorScheme.surfaceVariant, // رنگ متمایز نسبت به دکمه بالا
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCard(AuthProvider auth, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: auth.isGolden ? Colors.amber[800] : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  auth.isGolden ? Icons.star : Icons.account_balance_wallet,
                  color: auth.isGolden ? Colors.white : theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auth.isGolden
                        ? 'اشتراک طلایی فعال است'
                        : 'اعتبار شما: ${auth.credits} سوال',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!auth.isGolden)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShopScreen()),
              ),
              child: const Text('ارتقا / خرید'),
            ),
        ],
      ),
    );
  }

  Widget _buildCarSelector(ThemeData theme) {
    if (_isLoadingCars) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_cars.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'هیچ خودرویی یافت نشد.\nبرای بارگذاری مجدد، انگشت خود را به پایین بکشید.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
        color: theme.cardColor,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Car>(
          dropdownColor: theme.cardColor,
          value: _selectedCar,
          isExpanded: true,
          icon: Icon(Icons.directions_car, color: theme.colorScheme.secondary),
          hint: const Text('خودرویی انتخاب نشده'),
          items: _cars.map((car) {
            return DropdownMenuItem<Car>(
              value: car,
              child: Text(
                car.fullName,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedCar = val),
        ),
      ),
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextField(
      controller: _descController,
      maxLines: 5,
      maxLength: 300, // محدودیت طول کاراکتر تا الکی دیتای سنگین سرور ارسال نشود
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: 'مثلاً: ماشین موقع استارت زدن در هوای سرد صدای تق تق میده...',
        hintStyle: TextStyle(color: theme.hintColor),
        filled: true,
        fillColor: theme.cardColor,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2)),
      ),
    );
  }
}
