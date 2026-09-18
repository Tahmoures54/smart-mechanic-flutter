part of 'home_screen.dart';

// Private UI pieces for HomeScreen (must stay a `part of` — no own imports).

// =============================================================================
// ثابت‌های محلی — شدت‌های opacity در یک‌جا جمع شده تا تغییر رنگ برند در آینده
// فقط با ویرایش همین چند خط ممکن باشد.
// اعداد ۰٫۱۲ و ۰٫۳۸ مطابق توکن‌های استاندارد Material 3 برای حالت غیرفعال است.
// =============================================================================
const double _kIconBgOpacity = 0.14;
const double _kSubtitleOpacity = 0.82;
const double _kShadowOpacity = 0.45;
const double _kBorderOpacity = 0.55;
const double _kSoftBgOpacity = 0.12;
const double _kM3DisabledContainerOpacity = 0.12;
const double _kM3DisabledContentOpacity = 0.38;

/// اگر مقدار null یا خالی بود «—» نشان بده؛ برای جلوگیری از نمایش لفظی
/// "null" وقتی پروفایل هنوز لود نشده یا مقداری برنگشته است.
String _orDash(Object? value) {
  if (value == null) return '—';
  final text = value.toString();
  return text.isEmpty ? '—' : text;
}

/// ارقام فارسی/عربی را حین تایپ به لاتین تبدیل می‌کند و هر کاراکتر غیرعددی
/// را بی‌صدا حذف می‌کند.
///
/// چرا لازم است: `FilteringTextInputFormatter.digitsOnly` فقط ارقام لاتین
/// (0-9) را قبول می‌کند؛ کاربری که با کیبورد فارسی پیش‌فرض «۱۴۰۲» تایپ کند،
/// می‌بیند که هیچ‌چیز در فیلد ظاهر نمی‌شود. این formatter هر دو دسته رقم را
/// می‌پذیرد و بلافاصله به لاتین نرمال می‌کند تا هم تجربهٔ تایپ سالم بماند
/// هم مقدار خروجی همیشه با فرمتی که ولیدیشن انتظار دارد یکی باشد.
class _DigitInputFormatter extends TextInputFormatter {
  const _DigitInputFormatter();

  static const Map<String, String> _toLatin = {
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final ch in newValue.text.split('')) {
      final mapped = _toLatin[ch];
      if (mapped != null) {
        buffer.write(mapped);
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        buffer.write(ch);
      }
      // هر کاراکتر دیگر (حرف، فاصله، نماد) بی‌صدا نادیده گرفته می‌شود.
    }
    final newText = buffer.toString();
    // برای فیلد کوتاهی مثل سال ساخت، نگه‌داشتن مکان‌نما در انتها ساده‌ترین
    // و امن‌ترین رفتار است (مشابه رفتار رایج فیلدهای OTP/مبلغ).
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class _DiagnoseCtaButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _DiagnoseCtaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onPressed == null;
    final bg = disabled
        ? theme.colorScheme.onSurface.withOpacity(_kM3DisabledContainerOpacity)
        : theme.colorScheme.secondary;
    final fg = disabled
        ? theme.colorScheme.onSurface.withOpacity(_kM3DisabledContentOpacity)
        : theme.colorScheme.onSecondary;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: 'ارسال شرح مشکل به مکانیک هوشمند',
      child: Material(
        color: bg,
        elevation: disabled ? 0 : 3,
        shadowColor: theme.colorScheme.secondary.withOpacity(_kShadowOpacity),
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
                    color: Colors.black.withOpacity(_kIconBgOpacity),
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
                        'تحلیل اولیه با کمک هوش مصنوعی',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fg.withOpacity(_kSubtitleOpacity),
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
      ),
    );
  }
}

class _AudioCtaButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _AudioCtaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onPressed == null;
    final secondary = disabled
        ? theme.colorScheme.onSurface.withOpacity(_kM3DisabledContentOpacity)
        : theme.colorScheme.secondary;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: 'ضبط صدای موتور برای تحلیل',
      child: Material(
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: secondary.withOpacity(_kBorderOpacity), width: 1.6),
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
                    color: secondary.withOpacity(_kSoftBgOpacity),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: secondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تحلیل صدا برای بررسی دقیق‌تر',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            style: TextStyle(color: theme.colorScheme.onSecondary, fontSize: 13, fontWeight: FontWeight.bold),
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
        title: Text(
          _orDash(auth.displayName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          auth.isGoldenActive
              ? 'اشتراک طلایی فعال'
              : 'اعتبار: ${_orDash(auth.credits)} · رایگان ماهانه: ${_orDash(auth.remainingFree)}',
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
                textInputAction: TextInputAction.next,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'نام خودرو',
                  hintText: 'مثلاً: تویوتا کمری',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              // به‌جای digitsOnly (که ارقام فارسی/عربی را کاملاً رد می‌کند
              // و باعث می‌شود فیلد برای بخش زیادی از کاربران خالی بماند)،
              // این formatter هر دو دسته رقم را می‌پذیرد و به لاتین تبدیل
              // می‌کند تا هم تایپ روان باشد هم خروجی همیشه یک‌دست بماند.
              inputFormatters: const [_DigitInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'سال ساخت',
                hintText: 'مثلاً ۱۴۰۲ یا 2023',
                counterText: '',
                border: OutlineInputBorder(),
              ),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('چرا مکانیک هوشمند؟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _BenefitRow(
              icon: Icons.psychology_alt_rounded,
              title: 'شروع سریع',
              text: 'شرح مشکل یا صدای موتور را بفرست و مسیر بررسی را روشن‌تر کن.',
            ),
            _BenefitRow(
              icon: Icons.payments_outlined,
              title: 'کنترل هزینه',
              text: 'قبل از مراجعه، سؤال‌های فنی بهتری برای تعمیرگاه آماده کن.',
            ),
            _BenefitRow(
              icon: Icons.location_on_outlined,
              title: 'تکمیل مسیر',
              text: 'در کنار عیب‌یابی، امکان پیدا کردن تعمیرگاه‌های نزدیک را هم داری.',
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _BenefitRow({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(height: 1.45),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  Future<void> _runSupportAction(
    BuildContext context,
    BuildContext sheetContext,
    Future<void> Function() action, {
    String? successMessage,
    bool closeSheet = true,
  }) async {
    try {
      await action();
      if (closeSheet && sheetContext.mounted) Navigator.pop(sheetContext);
      if (successMessage != null && context.mounted) {
        _showSupportSnack(context, successMessage);
      }
    } catch (_) {
      if (closeSheet && sheetContext.mounted) Navigator.pop(sheetContext);
      if (context.mounted) {
        _showSupportSnack(context, 'این عملیات انجام نشد. لطفاً دوباره تلاش کنید.');
      }
    }
  }

  Future<void> _openSupportSheet(BuildContext context) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'چطور از مکانیک هوشمند حمایت کنیم؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'ما یک استارتاپ نوپا هستیم و برای رشد این ابزار به حمایت شما نیاز داریم. لازم نیست هزینه‌ای پرداخت کنید؛ معرفی محصول برای ما بسیار ارزشمند است.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.hintColor, height: 1.55, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _SupportActionTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'لینک را در پروفایل واتساپ بگذارم',
                subtitle: 'متن آماده پروفایل را کپی می‌کند',
                onTap: () => _runSupportAction(
                  context,
                  sheetContext,
                  () => ShareService.copy(ShareService.whatsappAbout()),
                  successMessage: 'متن پروفایل واتساپ کپی شد.',
                ),
              ),
              _SupportActionTile(
                icon: Icons.amp_stories_rounded,
                title: 'برای وضعیت واتساپ آماده کنم',
                subtitle: 'متن کوتاه همراه لینک برای Status',
                onTap: () => _runSupportAction(
                  context,
                  sheetContext,
                  () => ShareService.copy(ShareService.whatsappStatus()),
                  successMessage: 'متن وضعیت واتساپ کپی شد.',
                ),
              ),
              _SupportActionTile(
                icon: Icons.chat_rounded,
                title: 'در واتساپ برای دوستان بفرستم',
                subtitle: 'پیام معرفی آماده ارسال می‌شود',
                onTap: () => _runSupportAction(
                  context,
                  sheetContext,
                  () => ShareService.shareToWhatsApp(ShareService.appPitch()),
                ),
              ),
              _SupportActionTile(
                icon: Icons.share_rounded,
                title: 'در شبکه‌های اجتماعی معرفی کنم',
                subtitle: 'منوی اشتراک‌گذاری گوشی باز می‌شود',
                onTap: () => _runSupportAction(
                  context,
                  sheetContext,
                  () => ShareService.shareApp(),
                ),
              ),
              _SupportActionTile(
                icon: Icons.link_rounded,
                title: 'لینک سایت را کپی کنم',
                subtitle: ShareService.websiteUrl,
                onTap: () => _runSupportAction(
                  context,
                  sheetContext,
                  () => ShareService.copy(ShareService.websiteUrl),
                  successMessage: 'لینک سایت کپی شد.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSupportSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(_kSoftBgOpacity),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.favorite_rounded, color: theme.colorScheme.secondary, size: 27),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('حمایت از یک استارتاپ نوپا', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text(
                          'یک معرفی ساده می‌تواند به رشد مکانیک هوشمند کمک کند.',
                          style: TextStyle(fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'ما یک استارتاپ نوپا هستیم؛ به حمایت شما نیاز داریم. اگر از اپ راضی بودید، لینک آن را در پروفایل یا وضعیت واتساپ و شبکه‌های اجتماعی خود قرار دهید.',
                style: TextStyle(color: theme.hintColor, height: 1.55, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openSupportSheet(context),
                icon: const Icon(Icons.volunteer_activism_rounded, size: 19),
                label: const Text('راه‌های حمایت و معرفی'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        tileColor: theme.cardColor,
        leading: Icon(icon, color: theme.colorScheme.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
        trailing: const Icon(Icons.arrow_back_ios_rounded, size: 14),
        onTap: onTap,
      ),
    );
  }
}
