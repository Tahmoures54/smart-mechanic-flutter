import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/diagnosis_result.dart';
import 'urgency_and_chips.dart';

/// نمایش غنی نتیجهٔ تشخیص — به‌جای یک پاراگراف متن یکنواخت، اطلاعات
/// ساختاریافته (urgency, safeToDrive, causes, mechanicQuestions) را
/// به‌صورت بصری و قابل‌اسکن نشان می‌دهد.
class DiagnosisResultCard extends StatelessWidget {
  const DiagnosisResultCard({super.key, required this.result, this.onSubmitAnswers});

  final DiagnosisResult result;
  final Future<void> Function(Map<String, String> answers)? onSubmitAnswers;

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
            if (result.followUpQuestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('برای تشخیص دقیق‌تر، به این‌ها جواب بده:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (result.questionOptions.isNotEmpty)
                _TouchQuestionnaire(
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
          if (result.nextStep.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NextStepBox(text: result.nextStep),
          ],
          if (result.footer.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(result.footer, style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
          ],
        ],
      ),
    );
  }
}

class _TouchQuestionnaire extends StatefulWidget {
  const _TouchQuestionnaire({required this.questions, this.onSubmit});
  final List<DiagnosisQuestionOption> questions;
  final Future<void> Function(Map<String, String> answers)? onSubmit;

  @override
  State<_TouchQuestionnaire> createState() => _TouchQuestionnaireState();
}

class _TouchQuestionnaireState extends State<_TouchQuestionnaire> {
  final Map<String, String> _answers = {};
  bool _submitting = false;

  Future<void> _submit() async {
    if (_answers.isEmpty || widget.onSubmit == null || _submitting) return;
    setState(() => _submitting = true);
    await widget.onSubmit!(_answers);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.questions.map((q) {
          final selected = _answers[q.question];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: q.options.map((option) {
                    final active = selected == option;
                    return ChoiceChip(
                      label: Text(option, style: const TextStyle(fontSize: 12)),
                      selected: active,
                      onSelected: _submitting ? null : (_) => setState(() => _answers[q.question] = option),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _answers.isEmpty || _submitting ? null : _submit,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(_submitting ? 'در حال تحلیل...' : 'تحلیل پاسخ‌ها'),
          ),
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
