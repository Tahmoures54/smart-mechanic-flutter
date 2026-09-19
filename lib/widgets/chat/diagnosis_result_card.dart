import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/diagnosis_result.dart';
import 'urgency_and_chips.dart';

/// نمایش غنی نتیجهٔ تشخیص — به‌جای یک پاراگراف متن یکنواخت، اطلاعات
/// ساختاریافته (urgency, safeToDrive, causes, mechanicQuestions) را
/// به‌صورت بصری و قابل‌اسکن نشان می‌دهد.
class DiagnosisResultCard extends StatelessWidget {
  const DiagnosisResultCard({
    super.key,
    required this.result,
    this.supplementalText,
    this.onSubmitAnswer,
  });

  final DiagnosisResult result;
  final String? supplementalText;
  final void Function(String question, String answer)? onSubmitAnswer;

  String? get _garagePromoText {
    final text = supplementalText;
    if (text == null) return null;
    const marker = '## 🔧 تعمیرگاه‌های پیشنهادی';
    final start = text.indexOf(marker);
    if (start < 0) return null;
    return text.substring(start).trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          if (result.responseMode == ResponseMode.questions) ...[
            if (result.questionOptions.isNotEmpty || result.followUpQuestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('برای تشخیص دقیق‌تر، به این‌ها جواب بده:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (result.questionOptions.isNotEmpty)
                _TouchQuestionnaire(
                  questions: result.questionOptions,
                  onAnswer: onSubmitAnswer,
                )
              else
                ...result.followUpQuestions.asMap().entries.map(
                      (e) => _NumberedLine(index: e.key + 1, text: e.value),
                    ),
            ],
          ] else ...[
            if (result.causes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('علت‌های محتمل:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...result.causes.map((c) => _CauseTile(cause: c)),
            ],
            if (result.mechanicQuestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MechanicChecklist(items: result.mechanicQuestions),
            ],
          ],
          if (result.nextStep.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NextStepBox(text: result.nextStep),
          ],
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

class _TouchQuestionnaire extends StatefulWidget {
  const _TouchQuestionnaire({required this.questions, this.onAnswer});
  final List<DiagnosisQuestionOption> questions;
  final void Function(String question, String answer)? onAnswer;

  @override
  State<_TouchQuestionnaire> createState() => _TouchQuestionnaireState();
}

class _TouchQuestionnaireState extends State<_TouchQuestionnaire> {
  bool _submitting = false;
  String? _selectedAnswer;

  void _select(DiagnosisQuestionOption question, String answer) {
    if (_submitting || widget.onAnswer == null) return;
    setState(() {
      _submitting = true;
      _selectedAnswer = answer;
    });
    widget.onAnswer!(question.question, answer);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return const SizedBox.shrink();
    final q = widget.questions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: q.options.map((option) {
            return ChoiceChip(
              label: Text(option, style: const TextStyle(fontSize: 12)),
              selected: _selectedAnswer == option,
              onSelected: _submitting ? null : (_) => _select(q, option),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'پس از انتخاب گزینه، متن پاسخ در کادر پایین قرار می‌گیرد؛ برای ادامه دکمه ارسال را بزن.',
          style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor),
        ),
      ],
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
