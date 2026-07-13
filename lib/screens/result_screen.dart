import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
// فرض بر این است که LatLng از پکیج گوگل مپس ایمپورت شده است
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import '../models/ai_response.dart';
import '../models/audio_features.dart';
import '../models/garage.dart';
import '../widgets/audio_wave.dart';

class ResultScreen extends StatelessWidget {
  final String? resultText;
  final AIResponse? aiResponse;
  final AudioFeatures? audioFeatures;
  final List<Garage>? garages;

  const ResultScreen({
    super.key,
    this.resultText,
    this.aiResponse,
    this.audioFeatures,
    this.garages,
  });

  /// متن قابل اشتراک‌گذاری
  String? get _shareText {
    if (resultText != null) return resultText;
    if (aiResponse != null) {
      return 'تشخیص: ${aiResponse!.diagnosis}\n'
          'درصد اطمینان: ${(aiResponse!.confidence * 100).toStringAsFixed(1)}%';
    }
    return null; // اگر داده‌ای نیست، نال برمی‌گرداند
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDataToShare = _shareText != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
        title: const Text('نتیجه عیب‌یابی'),
        actions: [
          if (hasDataToShare)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => Share.share(_shareText!),
            ),
        ],
      ),
      // اگر resultText موجود بود، حالت متنی، در غیر این صورت حالت AI
      body: resultText != null ? _buildMarkdownView(context) : _buildAIResultView(context),
    );
  }

  /// نمایش نتیجهٔ متنی با Markdown
  Widget _buildMarkdownView(BuildContext context) {
    final theme = Theme.of(context);
    return Markdown(
      data: resultText!,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16),
        h1: TextStyle(color: theme.colorScheme.primary, fontSize: 22),
        h2: TextStyle(color: theme.colorScheme.primary, fontSize: 20),
        strong: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
        code: TextStyle(backgroundColor: theme.cardColor),
      ),
    );
  }

  /// نمایش نتیجهٔ تحلیل هوش مصنوعی
  Widget _buildAIResultView(BuildContext context) {
    final theme = Theme.of(context);
    
    // استفاده از متغیرهای محلی برای جلوگیری از استفاده مکرر از عملگر ! (Dart 3 Flow Analysis)
    final ai = aiResponse;
    final audio = audioFeatures;
    final garageList = garages;
    
    final bool isEmpty = ai == null && audio == null && (garageList == null || garageList.isEmpty);

    if (isEmpty) {
      return Center(child: Text('نتیجه‌ای برای نمایش وجود ندارد.', style: theme.textTheme.bodyMedium));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ai != null) ...[
            Text('تشخیص هوش مصنوعی:', style: theme.textTheme.headlineSmall?.copyWith(color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            Text(ai.diagnosis, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 10),
            Text(
              'میزان اطمینان: ${(ai.confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: ai.confidence > 0.8 ? Colors.green : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (audio != null) ...[
            Text('نمودار فرکانس موتور:', style: theme.textTheme.titleLarge?.copyWith(color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            AudioWave(spectrum: audio.frequencySpectrum),
            const SizedBox(height: 20),
          ],
          if (garageList != null && garageList.isNotEmpty) ...[
            Text('تعمیرگاه‌های پیشنهاد شده:', style: theme.textTheme.titleLarge?.copyWith(color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            // استفاده از Column به جای ListView برای کارایی بهتر در لیست‌های کوتاه تو در تو
            Column(
              children: garageList.map((garage) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(garage.name, style: theme.textTheme.bodyLarge),
                subtitle: Text('امتیاز: ${garage.rating ?? "بدون امتیاز"}', style: theme.textTheme.bodyMedium),
                onTap: () => _navigateToMap(context, garage.location),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// هدایت به نقشه برای نمایش موقعیت تعمیرگاه
  void _navigateToMap(BuildContext context, LatLng location) {
    // TODO: باز کردن نقشه با مختصات location
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('باز کردن نقشه در مختصات: ${location.latitude}, ${location.longitude}')),
    );
  }
}
