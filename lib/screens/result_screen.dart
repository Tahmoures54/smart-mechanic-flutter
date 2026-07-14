import 'package:flutter/material.dart';
import '../models/audio_features.dart';

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
      appBar: AppBar(title: const Text('نتیجه عیب‌یابی')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resultText != null) ...[
              Text('نتیجه تحلیل:', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                resultText!,
                style: theme.textTheme.bodyLarge,
              ),
            ],
            if (audioFeatures != null) ...[
              const SizedBox(height: 20),
              Text('ویژگی‌های صوتی:', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildAudioFeature('RMS', audioFeatures!.rms.toStringAsFixed(3), theme),
              _buildAudioFeature('فرکانس غالب', '${audioFeatures!.dominantFrequency.toStringAsFixed(1)} هرتز', theme),
              _buildAudioFeature('مرکز طیف', audioFeatures!.spectralCentroid.toStringAsFixed(1), theme),
              _buildAudioFeature('نرخ عبور از صفر', audioFeatures!.zeroCrossingRate.toStringAsFixed(3), theme),
              // در صورت نیاز می‌توانید نمودار frequencySpectrum را با یک CustomPaint رسم کنید
            ],
            if (resultText == null && audioFeatures == null)
              const Center(child: Text('نتیجه‌ای برای نمایش وجود ندارد.')),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioFeature(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
