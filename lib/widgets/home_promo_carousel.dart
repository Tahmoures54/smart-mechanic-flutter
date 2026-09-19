import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/brand.dart';

typedef PromoAction = void Function();

class HomePromoCarousel extends StatefulWidget {
  final PromoAction onDiagnose;
  final PromoAction onAudio;
  // Kept for compatibility with existing HomeScreen wiring.
  final PromoAction? onShop;

  const HomePromoCarousel({
    super.key,
    required this.onDiagnose,
    required this.onAudio,
    this.onShop,
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
          eyebrow: 'گنجینه اطلاعات فنی',
          title: 'دانش فنی خودرو، همیشه همراه شما',
          body: 'از علائم و قطعات تا نکات نگهداری و راهنمایی‌های کاربردی؛ قبل از هر تصمیم، اطلاعات بیشتری داشته باش.',
          cta: 'کشف دانش فنی',
          icon: Icons.menu_book_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'فقط مخصوص خودروهای سواری نیست',
          title: 'سواری، کامیون، مینی‌بوس، جرثقیل و بیشتر',
          body: 'مکانیک هوشمند برای طیف گسترده‌ای از خودروها و ماشین‌آلات طراحی شده؛ نوع وسیله را بگو و بررسی را شروع کن.',
          cta: 'انتخاب و بررسی',
          icon: Icons.local_shipping_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'ارزش واقعی نرم‌افزار',
          title: 'قبل از خرج کردن، بهتر تصمیم بگیر',
          body: 'کمک می‌کنیم علائم را بهتر بفهمی، سؤال‌های درست‌تری از تعمیرکار بپرسی و از هزینه‌های غیرضروری دور بمانی.',
          cta: 'بررسی مشکل',
          icon: Icons.account_balance_wallet_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'عیب‌یابی با صدا',
          title: 'صدای موتور را هم جدی بگیر',
          body: 'صدای خودرو را ثبت کن تا نشانه‌های صوتی هم در بررسی اولیه وارد شوند و تصویر کامل‌تری از مشکل داشته باشی.',
          cta: 'تحلیل صدا',
          icon: Icons.graphic_eq_rounded,
          action: widget.onAudio,
        ),
        _PromoSlide(
          eyebrow: 'آمادگی برای تعمیرگاه',
          title: 'با اطلاعات بیشتر وارد تعمیرگاه شو',
          body: 'قبل از تعویض قطعه یا پرداخت هزینه، بدان چه چیزهایی را باید بپرسی و چه علائمی را دقیق‌تر توضیح بدهی.',
          cta: 'راهنمایی بگیر',
          icon: Icons.verified_user_rounded,
          action: widget.onDiagnose,
        ),
        _PromoSlide(
          eyebrow: 'همراه دلسوز راننده',
          title: 'قرار نیست تنها بمانی',
          body: 'مکانیک هوشمند جای تعمیرکار را نمی‌گیرد؛ قبل از مراجعه کمک می‌کند سردرگم نباشی و با آرامش بیشتری تصمیم بگیری.',
          cta: 'شروع عیب‌یابی',
          icon: Icons.support_agent_rounded,
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
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_paused || !mounted) return;
      final next = (_active + 1) % _slides().length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
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
                                    maxLines: 2,
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
                                      constraints: BoxConstraints(
                                        maxWidth: compact ? width * 0.62 : width * 0.58,
                                      ),
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
                      duration: const Duration(milliseconds: 280),
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
