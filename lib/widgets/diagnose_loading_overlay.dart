import 'dart:async';
import 'package:flutter/material.dart';

/// اورلی لودینگ عیب‌یابی — تا کاربر فکر نکند اپ هنگ کرده
class DiagnoseLoadingOverlay extends StatefulWidget {
  final bool visible;
  final String? customMessage;

  const DiagnoseLoadingOverlay({
    super.key,
    required this.visible,
    this.customMessage,
  });

  @override
  State<DiagnoseLoadingOverlay> createState() => _DiagnoseLoadingOverlayState();
}

class _DiagnoseLoadingOverlayState extends State<DiagnoseLoadingOverlay> {
  static const _tips = <String>[
    'در حال بررسی علائم و شرح مشکل…',
    'مقایسه با الگوهای خرابی مشابه…',
    'تحلیل احتمال قطعات معیوب…',
    'آماده‌سازی راهنمای گام‌به‌گام…',
  ];

  int _tipIndex = 0;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant DiagnoseLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _start();
    } else if (!widget.visible && oldWidget.visible) {
      _stop();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.visible) _start();
  }

  void _start() {
    _tipIndex = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _tipIndex = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final tip = widget.customMessage ?? _tips[_tipIndex];
    final theme = Theme.of(context);

    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withOpacity(0.72),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A120E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.15),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'در حال عیب‌یابی…',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.amber.shade50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Text(
                    tip,
                    key: ValueKey(tip),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.amber.shade100.withOpacity(0.75),
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'معمولاً ۱۰ تا ۴۰ ثانیه طول می‌کشد — لطفاً صبر کنید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.amber.shade100.withOpacity(0.4),
                    fontSize: 11,
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
