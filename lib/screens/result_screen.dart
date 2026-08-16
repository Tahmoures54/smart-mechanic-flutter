import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/audio_features.dart'; // ✅ این import اضافه شد
import '../services/ai_diagnostic_service.dart';

class ResultScreen extends StatefulWidget {
  final String? resultText;
  final AudioFeatures? audioFeatures;

  const ResultScreen({
    super.key,
    this.resultText,
    this.audioFeatures,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _gaugeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _gaugeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── اشتراک‌گذاری نتیجه ──
  void _shareResult() {
    if (widget.resultText == null) return;
    Share.share(
      '🔧 نتیجه عیب‌یابی مکانیک هوشمند:\n\n${widget.resultText!}',
      subject: 'نتیجه عیب‌یابی خودرو',
    );
  }

  // ── کپی متن ──
  void _copyResult(BuildContext context) {
    if (widget.resultText == null) return;
    Clipboard.setData(ClipboardData(text: widget.resultText!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('متن نتیجه کپی شد'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── تفسیر RMS ──
  _AudioLevel _interpretRms(double rms) {
    if (rms < 0.05) return _AudioLevel.low;
    if (rms < 0.15) return _AudioLevel.normal;
    if (rms < 0.30) return _AudioLevel.high;
    return _AudioLevel.critical;
  }

  // ── تفسیر فرکانس ──
  String _interpretFrequency(double freq) {
    if (freq < 100) return 'بسیار پایین (ارتعاش)';
    if (freq < 500) return 'پایین (موتور در دور آرام)';
    if (freq < 2000) return 'متوسط (دور معمول)';
    if (freq < 5000) return 'بالا (دور زیاد)';
    return 'بسیار بالا (ناکوبی)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResult = widget.resultText != null;
    final hasAudio = widget.audioFeatures != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('نتیجه عیب‌یابی هوشمند'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (hasResult) ...[
            IconButton(
              tooltip: 'کپی نتیجه',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => _copyResult(context),
            ),
            IconButton(
              tooltip: 'اشتراک‌گذاری',
              icon: const Icon(Icons.share_rounded),
              onPressed: _shareResult,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasResult || hasAudio)
                    _buildSuccessBanner(theme),

                  if (hasResult) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      Icons.medical_information_rounded,
                      'تشخیص و راهکار نهایی',
                      theme,
                    ),
                    _buildResultCard(theme),
                  ],

                  if (hasAudio) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      Icons.analytics_rounded,
                      'داده‌های استخراج‌شده از موتور',
                      theme,
                    ),
                    _buildAudioCard(theme),
                  ],

                  if (!hasResult && !hasAudio)
                    _buildEmptyState(theme),

                  const SizedBox(height: 32),
                  _buildActionButtons(theme),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── بنر موفقیت ──
  Widget _buildSuccessBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondary.withOpacity(0.15),
            theme.colorScheme.primary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: theme.colorScheme.secondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عیب‌یابی با موفقیت انجام شد',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'نتیجه زیر توسط هوش مصنوعی تولید شده است.',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── کارت نتیجه متنی ──
  Widget _buildResultCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shadowColor: theme.colorScheme.primary.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              widget.resultText!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.9,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildChipButton(
                  icon: Icons.copy_rounded,
                  label: 'کپی',
                  onTap: () => _copyResult(context),
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildChipButton(
                  icon: Icons.share_rounded,
                  label: 'اشتراک‌گذاری',
                  onTap: _shareResult,
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.secondary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── کارت داده‌های صوتی ──
  Widget _buildAudioCard(ThemeData theme) {
    final f = widget.audioFeatures!;
    final rmsLevel = _interpretRms(f.rms);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRmsGauge(f.rms, rmsLevel, theme),
            const SizedBox(height: 16),
            const Divider(),

            _buildAudioFeatureRow(
              icon: Icons.graphic_eq_rounded,
              label: 'قدرت سیگنال (RMS)',
              value: f.rms.toStringAsFixed(3),
              interpretation: rmsLevel.label,
              interpretationColor: rmsLevel.color,
              theme: theme,
            ),
            const Divider(height: 1),
            _buildAudioFeatureRow(
              icon: Icons.settings_input_component_rounded,
              label: 'فرکانس غالب',
              value: '${f.dominantFrequency.toStringAsFixed(1)} Hz',
              interpretation: _interpretFrequency(f.dominantFrequency),
              interpretationColor: Colors.blueAccent,
              theme: theme,
            ),
            const Divider(height: 1),
            _buildAudioFeatureRow(
              icon: Icons.center_focus_strong_rounded,
              label: 'مرکز طیف',
              value: f.spectralCentroid.toStringAsFixed(1),
              theme: theme,
            ),
            const Divider(height: 1),
            _buildAudioFeatureRow(
              icon: Icons.linear_scale_rounded,
              label: 'نرخ عبور از صفر',
              value: f.zeroCrossingRate.toStringAsFixed(3),
              theme: theme,
            ),

            const SizedBox(height: 16),
            _buildLegend(theme),
          ],
        ),
      ),
    );
  }

  // ── Gauge بصری برای RMS ──
  Widget _buildRmsGauge(
    double rms,
    _AudioLevel level,
    ThemeData theme,
  ) {
    final normalizedRms = (rms / 0.5).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سطح صدای موتور',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleSmall?.color,
                fontSize: 13,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: level.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: level.color.withOpacity(0.4)),
              ),
              child: Text(
                level.label,
                style: TextStyle(
                  color: level.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _gaugeAnim,
          builder: (context, _) {
            return Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: normalizedRms * _gaugeAnim.value,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.green,
                          Colors.yellow,
                          Colors.orange,
                          Colors.red,
                        ],
                        stops: [0.0, 0.4, 0.7, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: level.color.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('آرام',
                style: TextStyle(color: theme.hintColor, fontSize: 10)),
            Text('بلند',
                style: TextStyle(color: theme.hintColor, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  // ── ردیف داده صوتی ──
  Widget _buildAudioFeatureRow({
    required IconData icon,
    required String label,
    required String value,
    String? interpretation,
    Color? interpretationColor,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.hintColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
                if (interpretation != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    interpretation,
                    style: TextStyle(
                      fontSize: 11,
                      color: interpretationColor ?? theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── راهنمای رنگ‌ها ──
  Widget _buildLegend(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'راهنمای سطح صدا:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: _AudioLevel.values.map((level) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: level.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    level.label,
                    style:
                        TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── حالت خالی ──
  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: theme.hintColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'نتیجه‌ای دریافت نشد',
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'متأسفانه پاسخی از سرور دریافت نشد.\n'
            'لطفاً اتصال اینترنت خود را بررسی کرده و دوباره تلاش کنید.',
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── دکمه‌های اکشن ──
  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.home_rounded),
          label: const Text(
            'بازگشت به صفحه اصلی',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 10),
        if (widget.resultText != null)
          OutlinedButton.icon(
            onPressed: _shareResult,
            icon: const Icon(Icons.share_rounded),
            label: const Text(
              'اشتراک‌گذاری نتیجه',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: theme.colorScheme.secondary,
                width: 1.5,
              ),
              foregroundColor: theme.colorScheme.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ],
    );
  }

  // ── عنوان بخش ──
  Widget _buildSectionTitle(
    IconData icon,
    String title,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── سطح صدا ──
// ─────────────────────────────────────────────────────────────────────────────
enum _AudioLevel {
  low,
  normal,
  high,
  critical;

  String get label => switch (this) {
        _AudioLevel.low => 'خیلی آرام',
        _AudioLevel.normal => 'نرمال',
        _AudioLevel.high => 'بلند',
        _AudioLevel.critical => 'بحرانی',
      };

  Color get color => switch (this) {
        _AudioLevel.low => Colors.blueAccent,
        _AudioLevel.normal => Colors.green,
        _AudioLevel.high => Colors.orange,
        _AudioLevel.critical => Colors.redAccent,
      };
}
