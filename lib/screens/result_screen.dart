import 'package:flutter/material.dart';
// فرض بر این است که مدل‌ها در مسیر زیر هستند
import '../services/ai_diagnostic_service.dart';

class ResultScreen extends StatelessWidget {
  final String? resultText;
  final AudioFeatures? audioFeatures;

  const ResultScreen({
    super.key,
    this.resultText,
    this.audioFeatures,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('نتیجه عیب‌یابی هوشمند'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (resultText != null) ...[
              _buildSectionTitle(Icons.medical_information_rounded, 'تشخیص و راهکار نهایی', theme),
              Card(
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(
                    resultText!,
                    textAlign: TextAlign.right, // راست‌چین کردن اجباری برای فارسی
                    textDirection: TextDirection.rtl, // جهت متن فارسی
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15, 
                      height: 1.8, // فاصله خطوط برای خوانایی بهتر
                      color: Colors.white.withOpacity(0.9)
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (audioFeatures != null) ...[
              _buildSectionTitle(Icons.analytics_rounded, 'داده‌های استخراج شده از موتور', theme),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildAudioFeature(Icons.graphic_eq_rounded, 'RMS (قدرت سیگنال)', audioFeatures!.rms.toStringAsFixed(3), theme),
                      const Divider(),
                      _buildAudioFeature(Icons.settings_input_component_rounded, 'فرکانس غالب', '${audioFeatures!.dominantFrequency.toStringAsFixed(1)} هرتز', theme),
                      const Divider(),
                      _buildAudioFeature(Icons.center_focus_strong_rounded, 'مرکز طیف', audioFeatures!.spectralCentroid.toStringAsFixed(1), theme),
                      const Divider(),
                      _buildAudioFeature(Icons.linear_scale_rounded, 'نرخ عبور از صفر', audioFeatures!.zeroCrossingRate.toStringAsFixed(3), theme),
                    ],
                  ),
                ),
              ),
            ],

            if (resultText == null && audioFeatures == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Text('متاسفانه نتیجه‌ای از سرور دریافت نشد.', style: TextStyle(color: theme.hintColor)),
                ),
              ),
            
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home_rounded),
              label: const Text('بازگشت به صفحه اصلی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 24),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
        ],
      ),
    );
  }

  Widget _buildAudioFeature(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.hintColor),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber)),
        ],
      ),
    );
  }
}
