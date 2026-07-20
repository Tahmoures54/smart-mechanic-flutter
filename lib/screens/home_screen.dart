import 'package:flutter/material.dart';
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
  
  bool _isLoadingCars = true;
  bool _isRefreshing = false; // 👈 برای تشخیص اینکه رفرش است یا لود اولیه
  bool _hasCarLoadError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCars());
  }

  @override
  void dispose() {
    _descController.dispose();
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
      
      setState(() {
        _cars = cars;
        if (cars.isNotEmpty && _selectedCar == null) {
          _selectedCar = cars.first; 
        }
      });
    } catch (e) {
      debugPrint('Error loading cars: $e');
      if (mounted) {
        setState(() => _hasCarLoadError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در دریافت لیست خودروها. اینترنت را بررسی کنید.')),
        );
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

  void _diagnose() {
    FocusManager.instance.primaryFocus?.unfocus();

    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (!auth.isAuthenticated) {
      navigator.push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (_selectedCar == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا خودروی خود را انتخاب کنید.')),
      );
      return;
    }

    // 👈 کاهش محدودیت به ۵ حرف تا کاربر اذیت نشود (مثلاً: ریپ زدن)
    if (_descController.text.trim().length < 5) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('لطفاً مشکل را کمی واضح‌تر بنویسید.')),
      );
      return;
    }

    if (!auth.isGolden && auth.credits <= 0) {
      _showNoCreditDialog();
      return;
    }

    final userMessage = _descController.text.trim();
    _descController.clear();

    navigator.push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        carName: _selectedCar!.fullName,
        carId: _selectedCar!.id,
        initialUserMessage: userMessage,
      ),
    ));
  }

  void _onVoiceRecordTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    final auth = context.read<AuthProvider>();

    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً قبل از ضبط صدا، مدل خودرو را انتخاب کنید.')),
      );
      return;
    }

    if (!auth.isGolden && auth.credits <= 0) {
      _showNoCreditDialog();
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RecordScreen(
        carName: _selectedCar!.fullName,
        carId: _selectedCar!.id,
      ),
    ));
  }

  // 👈 دیالوگ امن شد (بررسی mounted قبل از هدایت به صفحه فروشگاه)
  void _showNoCreditDialog() {
    final theme = Theme.of(context);
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text('اعتبار ناکافی', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        content: Text('برای ادامه گفتگو و عیب‌یابی دقیق، نیاز به تهیه اعتبار دارید.',
            style: theme.textTheme.bodyMedium),
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
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
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
          title: const Text('مکانیک هوشمند', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
          elevation: 0,
          actions: [
            if (auth.isAuthenticated)
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'تاریخچه عیب‌یابی',
                onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              )
            else
              TextButton(
                onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: Text('ورود',
                    style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
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

                Text('۱. خودروی خود را انتخاب کنید:',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                
                // 👈 حالا اگر کاربر رفرش کند، باکس ماشین غیب نمی‌شود!
                _buildCarSelector(theme),

                const SizedBox(height: 24),

                Text('۲. شرح خرابی را بنویسید:',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _buildDescriptionField(theme),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 28),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: _diagnose,
                  label: Text('ارسال به مکانیک هوشمند',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondary)),
                ),

                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.hintColor.withOpacity(0.2), thickness: 1.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.hintColor.withOpacity(0.2))
                      ),
                      child: Text('یا روش دقیق‌تر', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: theme.hintColor.withOpacity(0.2), thickness: 1.5)),
                  ],
                ),
                
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  icon: const Icon(Icons.mic_none_rounded, size: 30),
                  label: const Text('شروع ضبط صدای موتور / خودرو'),
                  onPressed: _onVoiceRecordTap,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 65),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    backgroundColor: theme.scaffoldBackgroundColor, 
                    foregroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: theme.colorScheme.primary, width: 2),
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            style: TextButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text('ورود', style: TextStyle(fontWeight: FontWeight.bold)),
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
          colors: [theme.colorScheme.primary.withOpacity(0.15), Colors.black87],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: theme.colorScheme.secondary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text('چرا مکانیک هوشمند؟',
                  style: TextStyle(color: theme.colorScheme.secondary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'هوش مصنوعی ما با تحلیل میلیون‌ها دادهٔ تعمیرگاهی آموزش دیده است تا دقیق‌ترین تشخیص را به شما ارائه دهد و خیالتان را راحت کند.',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 24),
          _buildPromoItem(theme, icon: Icons.savings_rounded, title: 'پیشگیری بهتر از تعمیر', desc: 'با آگاهی و تشخیص زودهنگام، نگذارید یک ایراد کوچک به موتور آسیب جدی وارد کند.'),
          const SizedBox(height: 16),
          _buildPromoItem(theme, icon: Icons.handshake_rounded, title: 'دستیار هوشمند مکانیک شما', desc: 'تشخیص دقیق اولین قدم است؛ با داشتن گزارش کامل، به مکانیک خود کمک کنید.'),
          const SizedBox(height: 16),
          _buildPromoItem(theme, icon: Icons.timer_rounded, title: 'صرفه‌جویی در زمان', desc: 'بدون سردرگمی، در کمتر از ۱۰ ثانیه ریشه مشکل را بررسی کنید.'),
        ],
      ),
    );
  }

  Widget _buildPromoItem(ThemeData theme, {required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: theme.cardColor.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4)),
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
          colors: auth.isGolden ? [Colors.amber.shade700, Colors.orange.shade900] : [theme.cardColor, theme.cardColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: auth.isGolden ? Colors.amberAccent : theme.dividerColor, width: auth.isGolden ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(auth.isGolden ? Icons.workspace_premium_rounded : Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.isGolden ? 'اشتراک طلایی (نامحدود)' : 'موجودی اعتبار شما',
                        style: TextStyle(color: auth.isGolden ? Colors.white : theme.textTheme.bodySmall?.color, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(auth.isGolden ? 'فعال می‌باشد' : '${auth.credits} بار عیب‌یابی',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!auth.isGolden)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary, foregroundColor: theme.colorScheme.onSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopScreen())),
              child: const Text('شارژ حساب', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // 👈 منطق نمایش باگ‌گیری شد تا در هنگام رفرش، لیست غیب نشود
  Widget _buildCarSelector(ThemeData theme) {
    if (_isLoadingCars && !_isRefreshing) {
      return Container(
        height: 60, decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasCarLoadError && _cars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('خطا در بارگذاری خودروها', style: TextStyle(color: Colors.redAccent, fontSize: 13))),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18), label: const Text('تلاش مجدد'),
              onPressed: () => _loadCars(),
            )
          ],
        ),
      );
    }

    if (_cars.isEmpty && !_isLoadingCars) {
      return Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Text('هیچ خودرویی یافت نشد.\nبرای بارگذاری مجدد، صفحه را به پایین بکشید.',
          textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(16), color: theme.cardColor),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Car>(
          dropdownColor: theme.scaffoldBackgroundColor, value: _selectedCar, isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.secondary),
          hint: const Text('خودرویی انتخاب نشده'),
          items: _cars.map((car) {
            return DropdownMenuItem<Car>(
              value: car, child: Text(car.fullName, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w600, fontSize: 15)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedCar = val),
        ),
      ),
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextField(
      controller: _descController, maxLines: 4, maxLength: 300,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, height: 1.5),
      decoration: InputDecoration(
        hintText: 'مثال: صبح‌ها که هوا سرده، موقع استارت زدن ماشین ریپ میزنه...',
        hintStyle: TextStyle(color: theme.hintColor, fontSize: 14), filled: true, fillColor: theme.cardColor, contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.5)),
      ),
    );
  }
}
