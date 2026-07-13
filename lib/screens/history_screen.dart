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
    // استفاده از PostFrameCallback برای امنیت دسترسی به context در initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistory();
    });
  }

  Future<void> _fetchHistory() async {
    // جلوگیری از فراخوانی همزمان دو بار
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    
    if (!auth.isAuthenticated || auth.token == null) {
      setState(() {
        _error = 'برای مشاهده تاریخجه ابتدا وارد حساب کاربری خود شوید.';
        _isLoading = false;
      });
      return;
    }

    try {
      // نکته: در پروژه واقعی، ApiService باید از طریق Provider یا get_it تزریق شود
      final history = await ApiService().getHistory(auth.token!);
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      // چاپ خطای واقعی برای دیباگ توسعه‌دهنده
      debugPrint('Error fetching history: $e');
      setState(() {
        // نمایش پیام امن و کاربرپسند به جای e.toString()
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
        title: const Text('تاریخجه'),
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    // حالت لودینگ اولیه
    if (_history == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // حالت لیست خالی
    if (_history!.isEmpty) {
      return Center(
        child: Text('تاریخجه‌ای وجود ندارد.', style: theme.textTheme.bodyLarge),
      );
    }

    // حالت نمایش لیست با قابلیت Pull-to-Refresh
    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.builder(
        // 即使列表很短，也允许滚动以触发RefreshIndicator
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _history!.length,
        itemBuilder: (context, index) {
          final item = _history![index];
          return Card(
            color: theme.cardColor,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(
                item.carId,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                item.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultScreen(resultText: item.result),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
