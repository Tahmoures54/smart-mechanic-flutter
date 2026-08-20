import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/car.dart';
import 'login_screen.dart';
import 'shop_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import 'record_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// HomeScreen temporarily simplified after a bad push.
/// Full UI is being restored — open an issue if you still see this screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مکانیک هوشمند'),
        actions: [
          if (auth.isAuthenticated)
            IconButton(
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
              child: const Text('ورود'),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_circle_rounded,
                  size: 64, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              const Text(
                'در حال بازگردانی صفحه اصلی…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'لطفاً آخرین نسخه کامل را از تاریخچه گیت (قبل از commit خراب) بازیابی کنید\n'
                'یا چند دقیقه دیگر دوباره pull بگیرید.',
                style: TextStyle(color: theme.hintColor, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('فروشگاه اعتبار'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const Icon(Icons.login_rounded),
                label: const Text('ورود'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
