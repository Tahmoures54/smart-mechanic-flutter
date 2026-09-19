import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/diagnosis_result.dart';
import '../../providers/auth_provider.dart';
import '../../services/share_service.dart';
import 'urgency_and_chips.dart';

/// نمایش غنی نتیجهٔ تشخیص — همیشه به‌صورت «مقالهٔ کامل».
///
/// سیاست «پاسخ مستقیم»: کارت دیگر هیچ فرم پرسش‌وپاسخ اجباری (چیپ‌های
/// سؤال + دکمهٔ به‌روزرسانی تشخیص) ندارد. اگر بک‌اندِ قدیمی هنوز سؤال
/// بفرستد، آن سؤال‌ها صرفاً به‌صورت «راهنمای اختیاری» و بدون هیچ قفلی
/// نمایش داده می‌شوند. در پایان هر کارت هم بخش «ادامهٔ گفتگو» با
/// پیشنهادهای آماده، کاربر را به ادامهٔ مکالمه تشویق می‌کند و امکان
/// اشتراک‌گذاری نتیجه (با کد معرف کاربر) فراهم است.
class DiagnosisResultCard extends StatelessWidget {
  const DiagnosisResultCard({
    super.key,
    required this.result,
    this.supplementalText,
    this.onSuggestionTap,
    this.carName,
    this.year,
  });

  final DiagnosisResult result;
  final String? supplementalText;

  /// لمس یکی از پیشنهادهای «ادامهٔ گفتگو» — کادر ورودی چت را پر می‌کند.
  final ValueChanged<String>? onSuggestionTap;

  /// برای متن اشتراک‌گذاری نتیجه.
  final String? carName;
  final String? year;

  String? get _garagePromoText {
    final text = supplementalText;
    if (text == null) return null;
    const marker = '## 🔧 تعمیرگاه‌های پیشنهادی';
    final start = text.indexOf(marker);
    if (start < 0) return null;
    return text.substring(start).trim();
  }

  /// متن اصلی نتیجه بدون بخش تبلیغ تعمیرگاه‌ها — برای اشتراک‌گذاری.
  String get _shareableText {
    final raw = supplementalText ?? '';
    const marker = '## 🔧 تعمیرگاه‌های پیشنهادی';
    final cut = raw.indexOf(marker);
    var body = (cut >= 0 ? raw.substring(0, cut) : raw).trim();
    body = DiagnosisPolicy.stripDirective(body);
    if (body.isEmpty) {
      body = [
        if (result.statusSummary.isNotEmpty) result.statusSummary,
        ...result.causes.take(3).map((c) => '• ${c.title}'),
        if (result.nextStep.isNotEmpty) result.nextStep,
      ].join('\n');
    }
    if (body.length > 1200) body = '${body.substring(0, 1200)}…';
    return body;
  }

  Future<void> _shareResult(BuildContext context) async {
    try {
      final auth = context.read<AuthProvider>();
      await ShareService.shareDiagnosis(
        result: _shareableText,
        carName: carName,
        year: year,
        referralCode: auth.referralCode,
      );
    } catch (e) {
      debugPrint('[DiagnosisResultCard] share failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hints = result.optionalHints;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: urgencyColor(result.urgency).withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              UrgencyBadge(urgency: result.urgency),
              ConfidenceChip(confidence: result.confidence),
            ],
          ),
          if (result.safeToDrive == false) ...[
            const SizedBox(height: 10),
            _SafetyBanner(text: 'توصیه می‌شود با این وضعیت رانندگی نکنید.'),
          ],
          if (result.statusSummary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              result.statusSummary,
              style: const TextStyle(fontSize: 14, height: 1.55, fontWeight: FontWeight.w600),
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...result.warnings.map((w) => _WarningLine(text: w)),
          ],
          if (result.causes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('علت‌های محتمل:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...result.causes.map((c) => _CauseTile(cause: c)),
          ],
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 10),
            _OptionalHintsSection(hints: hints),
          ],
          if (result.mechanicQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MechanicChecklist(items: result.mechanicQuestions),
          ],
          if (result.nextStep.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NextStepBox(text: result.nextStep),
          ],
          // ── تشویق به ادامهٔ مکالمه (همیشه نمایش داده می‌شود) ──
          const SizedBox(height: 12),
          _ContinueChatSection(
            onSuggestionTap: onSuggestionTap,
            onShare: () => _shareResult(context),
          ),
          if (result.footer.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(result.footer, style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
          ],
          if (_garagePromoText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
              ),
              child: MarkdownBody(
                data: _garagePromoText!,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: const TextStyle(fontSize: 12.5, height: 1.55),
                  h2: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// بخش «ادامهٔ گفتگو» — انتهای هر کارت تشخیص.
/// کاربر را دعوت می‌کند سؤال بعدی را بپرسد و با یک لمس، پیشنهاد آماده را
/// در کادر ورودی می‌گذارد (بدون ارسال خودکار).
class _ContinueChatSection extends StatelessWidget {
  const _ContinueChatSection({this.onSuggestionTap, this.onShare});

  final ValueChanged<String>? onSuggestionTap;

  /// اشتراک‌گذاری نتیجه (رشد از طریق دعوت دوستان).
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  DiagnosisPolicy.encouragementText,
                  style: const TextStyle(fontSize: 12.5, height: 1.6, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: DiagnosisPolicy.followUpSuggestions
                .map(
                  (suggestion) => ActionChip(
                    label: Text(suggestion, style: const TextStyle(fontSize: 11.5)),
                    avatar: Icon(Icons.arrow_forward_rounded,
                        size: 13, color: theme.colorScheme.primary),
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.35)),
                    onPressed: onSuggestionTap == null ? null : () => onSuggestionTap!(suggestion),
                  ),
                )
                .toList(),
          ),
          if (onShare != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text(
                  'اشتراک‌گذاری این نتیجه',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// راهنمای اختیاری — فقط وقتی بک‌اندِ قدیمی هنوز سؤال برگردانده باشد
/// ظاهر می‌شود؛ صرفاً اطلاع‌رسانی است و هیچ ورودی اجباری نمی‌خواهد.
class _OptionalHintsSection extends StatelessWidget {
  const _OptionalHintsSection({required this.hints});

  final List<String> hints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اگر این جزئیات را هم بگویی، پاسخ بعدی دقیق‌تر می‌شود (اختیاری):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ...hints.asMap().entries.map(
                (e) => _NumberedLine(index: e.key + 1, text: e.value),
              ),
        ],
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dangerous_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5))),
        ],
      ),
    );
  }
}

class _NumberedLine extends StatelessWidget {
  const _NumberedLine({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$index.', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }
}

class _CauseTile extends StatelessWidget {
  const _CauseTile({required this.cause});
  final DiagnosisCause cause;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(cause.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
              const SizedBox(width: 6),
              ProbabilityChip(level: cause.probability),
            ],
          ),
          if (cause.why.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(cause.why, style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ],
          if (cause.diyCheck != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.build_circle_outlined, size: 14, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(cause.diyCheck!,
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                ),
              ],
            ),
          ],
          if (cause.costEstimate != null) ...[
            const SizedBox(height: 4),
            Text(cause.costEstimate!, style: const TextStyle(fontSize: 11.5, color: Colors.orange)),
          ],
        ],
      ),
    );
  }
}

class _MechanicChecklist extends StatelessWidget {
  const _MechanicChecklist({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('چک‌لیست برای تعمیرگاه',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: 'کپی چک‌لیست',
                onPressed: () {
                  final text = items.map((e) => '- $e').join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('چک‌لیست کپی شد')));
                },
              ),
            ],
          ),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(fontSize: 13)),
                  Expanded(child: Text(e, style: const TextStyle(fontSize: 12.5, height: 1.5))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepBox extends StatelessWidget {
  const _NextStepBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_left_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
