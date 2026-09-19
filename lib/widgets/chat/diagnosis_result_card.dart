import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/diagnosis_result.dart';
import 'urgency_and_chips.dart';

/// نمایش غنی نتیجهٔ تشخیص.
/// در حالت questions همه سؤال‌های یک دور یکجا نمایش داده می‌شوند و کاربر
/// با یک دکمه «به‌روزرسانی تشخیص» همه پاسخ‌ها را یکجا ارسال می‌کند.
class DiagnosisResultCard extends StatelessWidget {
  const DiagnosisResultCard({
    super.key,
    required this.result,
    this.supplementalText,
    this.onSubmitAnswers,
  });

  final DiagnosisResult result;
  final String? supplementalText;
  final void Function(String combinedAnswers)? onSubmitAnswers;

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
              const Text(
                'برای تشخیص دقیق‌تر، به این‌ها جواب بده:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (result.questionOptions.isNotEmpty)
                _MultiTouchQuestionnaire(
                  questions: result.questionOptions,
                  onSubmit: onSubmitAnswers,
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
          if (result.nextStep.isNotEmpty && result.responseMode != ResponseMode.questions) ...[
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

class _MultiTouchQuestionnaire extends StatefulWidget {
  const _MultiTouchQuestionnaire({required this.questions, this.onSubmit});
  final List<DiagnosisQuestionOption> questions;
  final void Function(String combinedAnswers)? onSubmit;

  @override
  State<_MultiTouchQuestionnaire> createState() => _MultiTouchQuestionnaireState();
}

class _MultiTouchQuestionnaireState extends State<_MultiTouchQuestionnaire> {
  final Map<int, String> _answers = {};
  bool _submitted = false;

  bool get _allAnswered =>
      widget.questions.isNotEmpty && _answers.length == widget.questions.length;

  void _select(int index, String option) {
    if (_submitted) return;
    setState(() => _answers[index] = option);
  }

  void _submit() {
    if (!_allAnswered || _submitted || widget.onSubmit == null) return;
    setState(() => _submitted = true);
    final lines = <String>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final a = _answers[i];
      if (a != null) lines.add('${q.question}: $a');
    }
    widget.onSubmit!(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.questions.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Text(
            widget.questions[i].question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: widget.questions[i].options.map((option) {
              final selected = _answers[i] == option;
              return ChoiceChip(
                label: Text(option, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: _submitted ? null : (_) => _select(i, option),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_allAnswered && !_submitted) ? _submit : null,
            icon: Icon(
              _submitted ? Icons.check_rounded : Icons.auto_awesome_rounded,
              size: 18,
            ),
            label: Text(
              _submitted ? 'در حال به‌روزرسانی…' : 'به‌روزرسانی تشخیص',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (!_allAnswered && !_submitted) ...[
          const SizedBox(height: 8),
          Text(
            'همه گزینه‌ها را انتخاب کن، سپس دکمه بالا را بزن.',
            style: TextStyle(fontSize: 11.5, color: theme.hintColor),
          ),
        ],
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
