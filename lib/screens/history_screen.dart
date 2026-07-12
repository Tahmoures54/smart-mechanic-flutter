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

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    try {
      final history = await ApiService().getHistory(auth.token!);
      setState(() => _history = history);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('تاریخچه'), backgroundColor: Colors.orange),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_history == null) return const Center(child: CircularProgressIndicator(color: Colors.orange));
    if (_history!.isEmpty) return const Center(child: Text('تاریخچه‌ای وجود ندارد.', style: TextStyle(color: Colors.white)));

    return ListView.builder(
      itemCount: _history!.length,
      itemBuilder: (context, index) {
        final item = _history![index];
        return Card(
          color: Colors.grey[900],
          child: ListTile(
            title: Text(item.carId, style: const TextStyle(color: Colors.white)),
            subtitle: Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ResultScreen(resultText: item.result)));
            },
          ),
        );
      },
    );
  }
}
