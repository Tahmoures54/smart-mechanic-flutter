import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/car.dart';
import 'login_screen.dart';
import 'shop_screen.dart';
import 'history_screen.dart';
import 'result_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  void _loadCars() async {
    try {
      final cars = await ApiService().getCars();
      setState(() {
        _cars = cars;
        if (cars.isNotEmpty) _selectedCar = cars.first;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت لیست خودروها: $e')),
      );
    }
  }

  void _diagnose() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      return;
    }

    if (_selectedCar == null || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً خودرو و مشکل را مشخص کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiService().diagnose(
        auth.token!,
        _selectedCar!.id.toString(), // ارسال id به جای fullName
        _descController.text,
      );
      if (mounted) {
        auth.fetchProfile(); // به‌روزرسانی اعتبار
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ResultScreen(resultText: result)),
        );
      }
    } on ApiException catch (e) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطای شبکه: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showNoCreditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('اعتبار ناکافی', style: TextStyle(color: Colors.white)),
        content: const Text('برای پرسش سوال، نیاز به خرید اعتبار دارید.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ShopScreen()));
            },
            child: const Text('فروشگاه', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مکانیک هوشمند'),
        backgroundColor: Colors.orange,
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
            )
          else
            TextButton(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
              child: const Text('ورود',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                  color: auth.isGolden ? Colors.amber[800] : Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      auth.isGolden
                          ? 'اشتراک طلایی فعال است'
                          : 'اعتبار شما: ${auth.credits} سوال',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (!auth.isGolden)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (context) => const ShopScreen())),
                        child: const Text('ارتقا / خرید'),
                      ),
                  ],
                ),
              ),
            const Text('خودروی خود را انتخاب کنید:', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Car>(
                  dropdownColor: Colors.grey[900],
                  value: _selectedCar,
                  isExpanded: true,
                  items: _cars.map((car) {
                    return DropdownMenuItem<Car>(
                      value: car,
                      child: Text(car.fullName, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCar = val),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('شرح خرابی:', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثلاً: ماشین موقع استارت زدن صدای تق تق میده...',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _diagnose,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('عیب‌یابی کن',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}