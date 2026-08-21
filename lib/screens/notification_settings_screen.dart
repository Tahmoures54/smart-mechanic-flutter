import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// صفحه تنظیمات اعلان‌ها
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _svc = NotificationService.instance;

  bool _enabled = true;
  bool _lowCredits = true;
  bool _golden = true;
  bool _checkup = true;
  bool _referral = true;
  bool _permissionGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final granted = await _svc.isPermissionGranted;
    setState(() {
      _enabled = _svc.notificationsEnabled;
      _lowCredits = _svc.isTypeEnabled(NotificationPrefs.lowCredits);
      _golden = _svc.isTypeEnabled(NotificationPrefs.golden);
      _checkup = _svc.isTypeEnabled(NotificationPrefs.checkup);
      _referral = _svc.isTypeEnabled(NotificationPrefs.referral);
      _permissionGranted = granted;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    final ok = await _svc.requestPermission();
    setState(() => _permissionGranted = ok);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مجوز اعلان فعال شد')),
      );
    }
  }

  Future<void> _testNotification() async {
    await _svc.show(
      type: AppNotificationType.general,
      title: 'تست اعلان',
      body: 'اگر این پیام را می‌بینی، نوتیفیکیشن درست کار می‌کند.',
      payload: 'home',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تنظیمات اعلان')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات اعلان'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (!_permissionGranted)
            Card(
              margin: const EdgeInsets.all(16),
              color: theme.colorScheme.secondary.withOpacity(0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'برای دریافت یادآوری‌ها، مجوز اعلان لازم است.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _requestPermission,
                      child: const Text('فعال‌سازی مجوز'),
                    ),
                  ],
                ),
              ),
            ),

          SwitchListTile(
            title: const Text('فعال بودن اعلان‌ها'),
            subtitle: const Text('خاموش کردن همه یادآوری‌ها'),
            value: _enabled,
            onChanged: (v) async {
              await _svc.setNotificationsEnabled(v);
              setState(() => _enabled = v);
              if (v) {
                await _svc.scheduleWeeklyCheckup();
              }
            },
          ),
          const Divider(),

          SwitchListTile(
            title: const Text('اعتبار کم'),
            subtitle: const Text('یادآوری ملایم وقتی اعتبار رو به اتمام است'),
            value: _lowCredits && _enabled,
            onChanged: !_enabled
                ? null
                : (v) async {
                    await _svc.setTypeEnabled(NotificationPrefs.lowCredits, v);
                    setState(() => _lowCredits = v);
                  },
          ),
          SwitchListTile(
            title: const Text('انقضای اشتراک طلایی'),
            subtitle: const Text('چند روز قبل از پایان اشتراک'),
            value: _golden && _enabled,
            onChanged: !_enabled
                ? null
                : (v) async {
                    await _svc.setTypeEnabled(NotificationPrefs.golden, v);
                    setState(() => _golden = v);
                  },
          ),
          SwitchListTile(
            title: const Text('چکاپ دوره‌ای خودرو'),
            subtitle: const Text('یادآوری هفتگی برای بررسی وضعیت ماشین'),
            value: _checkup && _enabled,
            onChanged: !_enabled
                ? null
                : (v) async {
                    await _svc.setTypeEnabled(NotificationPrefs.checkup, v);
                    setState(() => _checkup = v);
                    if (v) {
                      await _svc.scheduleWeeklyCheckup();
                    } else {
                      await _svc.cancel(AppNotificationType.checkupReminder);
                    }
                  },
          ),
          SwitchListTile(
            title: const Text('پیشرفت معرفی'),
            subtitle: const Text('وقتی به مراحل برداشت نزدیک می‌شوی'),
            value: _referral && _enabled,
            onChanged: !_enabled
                ? null
                : (v) async {
                    await _svc.setTypeEnabled(NotificationPrefs.referral, v);
                    setState(() => _referral = v);
                  },
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('ارسال اعلان تست'),
            subtitle: const Text('برای اطمینان از صحت تنظیمات'),
            onTap: _enabled ? _testNotification : null,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'اعلان‌ها با لحن آرام و بدون فشار طراحی شده‌اند تا فقط وقتی مفیدند یادآوری کنند.',
              style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
