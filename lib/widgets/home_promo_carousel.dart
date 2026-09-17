import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/brand.dart';

typedef PromoAction = void Function();

class HomePromoCarousel extends StatefulWidget {
  final PromoAction onDiagnose;
  final PromoAction onAudio;

  const HomePromoCarousel({
    super.key,
    required this.onDiagnose,
    required this.onAudio,
  });

  @override
  State<HomePromoCarousel> createState() => _HomePromoCarouselState();
}

class _PromoSlide {
  final String eyebrow;
  final String title;
  final String body;
  final String cta;
  final IconData icon;
  final PromoAction action;

  const _PromoSlide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.cta,
    required this.icon,
    required this.action,
  });
}

class _HomePromoCarouselState extends State<HomePromoCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _active = 0;
  bool _paused = false;

  List<_PromoSlide> _slides() => [
        _PromoSlide(
          eyebrow: 'اپلیکیشن مکانیک هوشمند',
          title: 'مکانیک هوشمند، همیشه همراه شما',
          body: 'عیب‌یابی و راهنمایی فنی را روی موبایل در دسترس داشته باش؛ سریع، ساده و کاربردی.',
          cta: 'شروع عیب‌یابی',
          icon: Icons.smartphone_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'عیب‌یابی با صدا',
          title: 'صدای موتور را بفرست',
          body: 'نشانه‌های صوتی را ثبت کن تا علت‌های محتمل را سریع‌تر و منظم‌تر بررسی کنی.',
          cta: 'تحلیل صدا',
          icon: Icons.graphic_eq_rounded,
          action: widget.onAudio,
        ),
        _PromoSlide(
          eyebrow: 'کنترل هزینه',
          title: 'قبل از تعمیرگاه، آگاه‌تر تصمیم بگیر',
          body: 'مشکل احتمالی و هزینه‌های مرتبط را بهتر بشناس و با آمادگی بیشتری درباره تعمیر تصمیم بگیر.',
          cta: 'بررسی مشکل',
          icon: Icons.account_balance_wallet_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'دانش خودرویی',
          title: 'یک گنجینه برای خودرو',
          body: 'اطلاعات فنی و راهنمایی‌های کاربردی را برای شناخت بهتر علائم و مشکلات خودرو در دسترس داشته باش.',
          cta: 'کشف دانش فنی',
          icon: Icons.menu_book_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'خودروهای سبک و سواری',
          title: 'برای خودروهای روزمره، دقیق‌تر تصمیم بگیر',
          body: 'از خودروهای شهری و سواری تا مدل‌های پرتیراژ؛ مشکل را شرح بده و مسیر بررسی را روشن‌تر کن.',
          cta: 'شروع عیب‌یابی',
          icon: Icons.directions_car_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'شاسی‌بلند و آفرود',
          title: 'برای مسیرهای سخت، آماده‌تر باش',
          body: 'علائم موتور، انتقال قدرت و مشکلات رایج خودروهای شاسی‌بلند و آفرود را بهتر بررسی کن.',
          cta: 'بررسی خودرو',
          icon: Icons.terrain_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'کامیون و اتوبوس',
          title: 'وقتی وسیله سنگین است، تشخیص مهم‌تر می‌شود',
          body: 'برای ناوگان، کامیون و اتوبوس، شرح دقیق علائم می‌تواند شروع بهتری برای بررسی فنی باشد.',
          cta: 'شروع بررسی',
          icon: Icons.local_shipping_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'جرثقیل و ماشین‌آلات سنگین',
          title: 'ماشین‌آلات سنگین را هوشمندتر بررسی کن',
          body: 'برای تجهیزات عمرانی و کارگاهی، علائم فنی را ثبت کن و قبل از توقف طولانی مسیر بررسی را مشخص‌تر کن.',
          cta: 'راهنمایی فنی',
          icon: Icons.construction_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'ژنراتور و تجهیزات تولید برق',
          title: 'تجهیزات تولید برق هم نیاز به تشخیص دارند',
          body: 'علائم موتور، لرزش، صدا یا افت عملکرد ژنراتور را ثبت کن و بررسی اولیه را منظم‌تر شروع کن.',
          cta: 'شروع بررسی',
          icon: Icons.bolt_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'آمادگی برای تعمیرگاه',
          title: 'با اطلاعات بیشتر وارد تعمیرگاه شو',
          body: 'قبل از تعویض قطعه، سؤال‌های درست را بشناس و تصمیم آگاهانه‌تری بگیر.',
          cta: 'راهنمایی بگیر',
          icon: Icons.verified_user_rounded,
          action: widget.onDiagnose,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_paused || !mounted) return;
      final next = (_active + 1) % _slides().length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final slides = _slides();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 370;
        final bannerHeight = compact ? 238.0 : 224.0;
        final iconSize = compact ? 50.0 : 56.0;
        final titleSize = compact ? 17.0 : 19.0;
        final bodySize = compact ? 11.5 : 12.5;

        return Column(
          children: [
            MouseRegion(
              onEnter: (_) => setState(() => _paused = true),
              onExit: (_) => setState(() => _paused = false),
              child: Focus(
                onFocusChange: (focused) => setState(() => _paused = focused),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: secondary.withOpacity(0.16)),
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        const Color(0xFF21130C),
                        theme.cardColor,
                        const Color(0xFF101114),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.24),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -65,
                        top: -70,
                        child: _Glow(color: secondary.withOpacity(0.12), size: 165),
                      ),
                      Positioned(
                        right: -25,
                        bottom: -75,
                        child: _Glow(color: BrandColors.gold.withOpacity(0.08), size: 150),
                      ),
                      SizedBox(
                        height: bannerHeight,
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: slides.length,
                          onPageChanged: (index) {
                            if (mounted) setState(() => _active = index);
                          },
                          itemBuilder: (context, index) {
                            final slide = slides[index];
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 15 : 18,
                                compact ? 16 : 18,
                                compact ? 15 : 18,
                                compact ? 14 : 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: iconSize,
                                        height: iconSize,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          color: secondary.withOpacity(0.11),
                                          border: Border.all(color: secondary.withOpacity(0.16)),
                                        ),
                                        child: Icon(slide.icon, color: secondary, size: compact ? 25 : 27),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Text(
                                          slide.eyebrow,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: secondary,
                                            fontSize: compact ? 11 : 12,
                                            height: 1.35,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    slide.title,
                                    maxLines: compact ? 2 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: titleSize,
                                      height: 1.3,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Expanded(
                                    child: Text(
                                      slide.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.62),
                                        fontSize: bodySize,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: compact ? width * 0.62 : width * 0.58),
                                      child: FilledButton.icon(
                                        onPressed: slide.action,
                                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                        label: Text(
                                          slide.cta,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          backgroundColor: secondary,
                                          foregroundColor: theme.colorScheme.onSecondary,
                                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (index) {
                final selected = index == _active;
                return Semantics(
                  button: true,
                  label: 'اسلاید ${index + 1} از ${slides.length}',
                  selected: selected,
                  child: GestureDetector(
                    onTap: () => _controller.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: selected ? 22 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: selected ? secondary : theme.dividerColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}
