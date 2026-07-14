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
      setState(() {
        _error = 'برای مشاهده تاریخچه ابتدا وارد حساب کاربری خود شوید.';
        _isLoading = false;
      });
      return;
    }

    try {
      final api = context.read<ApiService>();
      final history = await api.getHistory(auth.token!);
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching history: $e');
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
      appBar: AppBar(title: const Text('تاریخچه')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null && _history == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
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

    if (_history == null) return const Center(child: CircularProgressIndicator());

    if (_history!.isEmpty) {
      return Center(child: Text('تاریخچه‌ای وجود ندارد.', style: theme.textTheme.bodyLarge));
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _history!.length,
        itemBuilder: (context, index) {
          final item = _history![index];
          return Card(
            color: theme.cardColor,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(item.carId, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text(
                item.description ?? '',  // رفع خطای String?
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(resultText: item.result),
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
