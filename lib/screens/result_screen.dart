import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ai_response.dart';
import '../models/audio_features.dart';
import '../models/garage.dart';
import '../widgets/audio_wave.dart'; // ویجت اختصاصی برای نمایش طیف فرکانس

class ResultScreen extends StatelessWidget {
  final String? resultText;                // نتیجهٔ متنی عیب‌یابی ساده
  final AIResponse? aiResponse;            // پاسخ کامل هوش مصنوعی
  final AudioFeatures? audioFeatures;       // ویژگی‌های صوتی (برای نمودار)
  final List<Garage>? garages;              // لیست تعمیرگاه‌های نزدیک

  const ResultScreen({
    super.key,
    this.resultText,
    this.aiResponse,
    this.audioFeatures,
    this.garages,
  });

  /// متن قابل اشتراک‌گذاری: اگر نتیجهٔ متنی موجود باشد همان، وگرنه از AIResponse ساخته می‌شود.
  String get _shareText {
    if (resultText != null) return resultText!;
    if (aiResponse != null) {
      return 'تشخیص: ${aiResponse!.diagnosis}\n'
          'درصد اطمینان: ${(aiResponse!.confidence * 100).toStringAsFixed(1)}%';
    }
    return 'نتیجه‌ای برای اشتراک‌گذاری موجود نیست.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('نتیجه عیب‌یابی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(_shareText),
          ),
        ],
      ),
      body: resultText != null ? _buildMarkdownView() : _buildAIResultView(context),
    );
  }

  /// نمایش نتیجهٔ متنی با Markdown (همان نسخهٔ اول)
  Widget _buildMarkdownView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: resultText!,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(color: Colors.white, fontSize: 16),
          h1: const TextStyle(color: Colors.orange, fontSize: 22),
          h2: const TextStyle(color: Colors.orange, fontSize: 20),
          strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
          code: const TextStyle(backgroundColor: Colors.grey),
        ),
      ),
    );
  }

  /// نمایش نتیجهٔ تحلیل هوش مصنوعی (نسخهٔ دوم)
  Widget _buildAIResultView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aiResponse != null) ...[
            Text('تشخیص هوش مصنوعی:', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(aiResponse!.diagnosis, style: const TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              'میزان اطمینان: ${(aiResponse!.confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: aiResponse!.confidence > 0.8 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (audioFeatures != null) ...[
            Text('نمودار فرکانس موتور:', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            AudioWave(spectrum: audioFeatures!.frequencySpectrum), // ویجت اختصاصی
            const SizedBox(height: 20),
          ],
          if (garages != null && garages!.isNotEmpty) ...[
            Text('تعمیرگاه‌های پیشنهاد شده:', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: garages!.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(garages![i].name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('امتیاز: ${garages![i].rating}', style: const TextStyle(color: Colors.white70)),
                onTap: () => _navigateToMap(context, garages![i].location),
              ),
            ),
          ],
          if (aiResponse == null && audioFeatures == null && (garages == null || garages!.isEmpty))
            const Center(child: Text('نتیجه‌ای برای نمایش وجود ندارد.', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  /// هدایت به نقشه برای نمایش موقعیت تعمیرگاه (پیاده‌سازی واقعی بستگی به نقشه شما دارد)
  void _navigateToMap(BuildContext context, dynamic location) {
    // TODO: باز کردن نقشه با مختصات location
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('باز کردن نقشه...')),
    );
  }
}
