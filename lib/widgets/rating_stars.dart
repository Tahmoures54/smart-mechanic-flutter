import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// ویجت امتیاز ستاره‌ای ۱–۵ برای نتیجه عیب‌یابی
class RatingStars extends StatefulWidget {
  final int? diagnosticId;
  final int? initialRating;
  final bool compact;
  final ValueChanged<int>? onRated;

  const RatingStars({
    super.key,
    this.diagnosticId,
    this.initialRating,
    this.compact = false,
    this.onRated,
  });

  @override
  State<RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<RatingStars> {
  int _selected = 0;
  bool _submitted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRating != null && widget.initialRating! >= 1) {
      _selected = widget.initialRating!.clamp(1, 5);
      _submitted = true;
    }
  }

  Future<void> _onTap(int rating) async {
    if (_submitted || _loading) return;

    setState(() {
      _selected = rating;
      _loading = true;
    });

    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();
    final token = auth.token;
    final id = widget.diagnosticId;

    if (token == null || id == null) {
      // بدون سرور فقط UI را ثبت کن
      setState(() {
        _submitted = true;
        _loading = false;
      });
      widget.onRated?.call(rating);
      _snack('ممنون از نظرت! 🙏');
      return;
    }

    try {
      await api.submitFeedback(
        token,
        diagnosticId: id,
        rating: rating,
      );
      await api.trackEvent(
        'feedback_submit',
        token: token,
        properties: {'diagnosticId': id, 'rating': rating},
      );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _loading = false;
      });
      widget.onRated?.call(rating);
      _snack(_thankYou(rating));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _selected = 0;
        _loading = false;
      });
      _snack(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selected = 0;
        _loading = false;
      });
      _snack('خطا در ثبت نظر. دوباره تلاش کنید.', error: true);
    }
  }

  String _thankYou(int r) {
    if (r >= 4) return 'عالی! نظرت ثبت شد 🌟';
    if (r == 3) return 'ممنون — سعی می‌کنیم بهتر بشیم';
    return 'ممنون از بازخوردت؛ کمکت می‌کنه بهتر بشیم';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final starSize = widget.compact ? 26.0 : 34.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12 : 16,
        vertical: widget.compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.22),
        ),
      ),
      child: Column(
        children: [
          Text(
            _submitted ? 'نظر شما ثبت شد' : 'این تحلیل چقدر مفید بود؟',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: widget.compact ? 13 : 14,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = star <= _selected;
              return GestureDetector(
                onTap: _submitted || _loading ? null : () => _onTap(star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: filled && !_submitted ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: starSize,
                      color: filled
                          ? Colors.amber.shade600
                          : theme.hintColor.withOpacity(0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_loading) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
          if (_submitted && !widget.compact) ...[
            const SizedBox(height: 6),
            Text(
              'کمکت برای بهبود مکانیک هوشمند ارزشمنده 💛',
              style: TextStyle(fontSize: 11, color: theme.hintColor),
            ),
          ],
        ],
      ),
    );
  }
}
