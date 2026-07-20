import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/diagnostic.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Diagnostic>? _history;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchHistory());
  }

  Future<void> _fetchHistory() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.token == null) {
      if (!mounted) return;
      setState(() {
        _error = 'برای مشاهده تاریخچه ابتدا وارد حساب کاربری خود شوید.';
        _isLoading = false;
      });
      return;
    }

    try {
      final api = context.read<ApiService>();
      final history = await api.getHistory(auth.token!);
      
      // جلوگیری از خطای setState بعد از بسته شدن صفحه
      if (!mounted) return; 
      
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (!mounted) return;
      setState(() {
        _error = 'خطا در دریافت اطلاعات. لطفاً اتصال اینترنت خود را بررسی کرده و دوباره تلاش کنید.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('تاریخچه عیب‌یابی', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // حالت خطا
    if (_error != null && _history == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded, color: theme.colorScheme.error, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                _error!, 
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _fetchHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تلاش مجدد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    // حالت در حال بارگذاری
    if (_history == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // حالت لیست خالی
    if (_history!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 80, color: theme.hintColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'هنوز هیچ عیب‌یابی ثبت نکرده‌اید.', 
              style: TextStyle(color: theme.hintColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // لیست تاریخچه
    return RefreshIndicator(
      color: theme.colorScheme.secondary,
      onRefresh: _fetchHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: _history!.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _history![index];
          return Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 1),
            ),
            color: theme.cardColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(resultText: item.result),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // آیکون کنار هر آیتم
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.directions_car_rounded, color: theme.colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    // متن‌ها
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.carId, 
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description ?? 'بدون توضیحات',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // فلش انتهای لیست
                    Icon(
                      Icons.arrow_forward_ios_rounded, 
                      size: 16, 
                      color: theme.hintColor.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
