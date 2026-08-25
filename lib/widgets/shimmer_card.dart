import 'package:flutter/material.dart';

/// کارت شیمیر برای حالت بارگذاری لیست
class ShimmerCard extends StatefulWidget {
  final ThemeData theme;
  const ShimmerCard({super.key, required this.theme});

  @override
  State<ShimmerCard> createState() => ShimmerCardState();
}

class ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Opacity(
          opacity: 0.5 + (_ctrl.value * 0.5),
          child: Container(
            height: 90,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.theme.dividerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: widget.theme.dividerColor,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 11,
                        width: 160,
                        decoration: BoxDecoration(
                          color: widget.theme.dividerColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
