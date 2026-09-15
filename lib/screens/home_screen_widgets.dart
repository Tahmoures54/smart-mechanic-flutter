part of 'home_screen.dart';

// Private UI pieces for HomeScreen (must stay a `part of` — no own imports).

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
      shadowColor: theme.colorScheme.secondary.withOpacity(0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.send_rounded, color: fg, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ارسال به مکانیک هوشمند',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تحلیل فوری با هوش مصنوعی',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg.withOpacity(0.82),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.auto_awesome_rounded, color: fg, size: 22),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.mic_rounded, color: secondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ضبط صدای موتور',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تحلیل صدا برای تشخیص دقیق‌تر',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                  ],
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
          child: Text(
            number,
            style: TextStyle(
              color: theme.colorScheme.onSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const ListTile(
          leading: Icon(Icons.person_outline),
          title: Text('وارد نشده‌اید'),
          subtitle: Text('برای عیب‌یابی با شماره موبایل وارد شوید'),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(auth.isGoldenActive ? Icons.workspace_premium : Icons.account_circle),
        title: Text(auth.displayName),
        subtitle: Text(
          auth.isGoldenActive
              ? 'اشتراک طلایی فعال'
              : 'اعتبار: ${auth.credits} · رایگان ماهانه: ${auth.remainingFree}',
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isCustom)
              CarSelectorWidget(
                cars: cars,
                selectedCar: selectedCar,
                isLoading: isLoading,
                hasError: hasError,
                onRetry: onRetry,
                onCarSelected: onCarSelected,
              )
            else
              TextField(
                controller: customController,
                decoration: const InputDecoration(
                  labelText: 'نام خودرو',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'سال ساخت',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onToggleCustom,
              child: Text(
                isCustom ? 'انتخاب از لیست خودروها' : 'خودروی من در لیست نیست',
              ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const Icon(Icons.favorite_outline),
        title: const Text('حمایت از توسعه'),
        subtitle: const Text('با معرفی به دوستان، به رشد این ابزار کمک کنید'),
        onTap: () {
          ShareService.shareApp();
        },
      ),
    );
  }
}
