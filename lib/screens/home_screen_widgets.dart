part of 'home_screen.dart';

// Widgets extracted — see repository history for full UI helpers.
// Temporary minimal stubs so the app compiles; replace with full widgets from previous home_screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/share_service.dart';
import '../widgets/car_selector_widget.dart';
import '../models/car.dart';
import 'shop_screen.dart';

class _DiagnoseCtaButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DiagnoseCtaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSecondary;
    return Material(
      color: theme.colorScheme.secondary,
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.send_rounded, color: fg, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'ارسال به مکانیک هوشمند',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioCtaButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AudioCtaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: secondary.withOpacity(0.55), width: 1.6),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.mic_rounded, color: secondary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'ضبط صدای موتور',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String number;
  final String title;
  const _SectionLabel({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.secondary,
          child: Text(number, style: TextStyle(color: theme.colorScheme.onSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final AuthProvider auth;
  const _StatusBanner({required this.auth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!auth.isAuthenticated) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('وارد نشده‌اید'),
          subtitle: const Text('برای عیب‌یابی با شماره موبایل وارد شوید'),
        ),
      );
    }
    final credits = auth.credits;
    final free = auth.remainingFree;
    return Card(
      child: ListTile(
        leading: Icon(auth.isGolden ? Icons.workspace_premium : Icons.account_circle),
        title: Text(auth.phone ?? 'کاربر'),
        subtitle: Text(
          auth.isGolden
              ? 'اشتراک طلایی فعال'
              : 'اعتبار: $credits · رایگان ماهانه: ${free ?? 0}',
        ),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final bool isCustom;
  final List<Car> cars;
  final Car? selectedCar;
  final bool isLoading;
  final bool hasError;
  final TextEditingController customController;
  final TextEditingController yearController;
  final VoidCallback onRetry;
  final ValueChanged<Car> onCarSelected;
  final VoidCallback onToggleCustom;

  const _CarCard({
    required this.isCustom,
    required this.cars,
    required this.selectedCar,
    required this.isLoading,
    required this.hasError,
    required this.customController,
    required this.yearController,
    required this.onRetry,
    required this.onCarSelected,
    required this.onToggleCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (hasError)
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('تلاش مجدد'))
            else if (!isCustom)
              CarSelectorWidget(
                cars: cars,
                selectedCar: selectedCar,
                onSelected: onCarSelected,
              ),
            if (isCustom)
              TextField(
                controller: customController,
                decoration: const InputDecoration(labelText: 'نام خودرو', border: OutlineInputBorder()),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'سال ساخت', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onToggleCustom,
              child: Text(isCustom ? 'انتخاب از لیست خودروها' : 'خودروی من در لیست نیست'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MechanicAllyCard extends StatelessWidget {
  const _MechanicAllyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'مکانیک هوشمند کمکت می‌کند قبل از مراجعه، تصویر روشن‌تری از مشکل داشته باشی — نه جایگزین مکانیک متخصص.',
          style: TextStyle(height: 1.5, color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}

class _WhyItWorksSection extends StatelessWidget {
  const _WhyItWorksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('چرا مکانیک هوشمند؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('• تشخیص اولیه با هوش مصنوعی بر اساس شرح مشکل یا صدای موتور'),
        Text('• هشدارهای کلاهبرداری رایج تعمیرگاه'),
        Text('• لینک به تعمیرگاه‌های نزدیک'),
      ],
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.favorite_outline),
        title: const Text('حمایت از توسعه'),
        subtitle: const Text('با معرفی به دوستان، به رشد این ابزار کمک کنید'),
        onTap: () => ShareService.shareApp(),
      ),
    );
  }
}
