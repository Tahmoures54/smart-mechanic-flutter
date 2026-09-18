/// مدل نتیجهٔ ساختاریافتهٔ تشخیص — دقیقاً معادل DiagnosisResponseSchema
/// که در بک‌اند (src/lib/prompts.ts) تعریف شده است.
///
/// این مدل هرگز throw نمی‌کند: اگر بک‌اند فیلدی نداشت یا JSON ناقص بود،
/// tryParse مقدار null برمی‌گرداند تا UI با یک fallback امن (نمایش متن ساده)
/// کار خودش را ادامه دهد؛ هیچ‌وقت کل صفحهٔ چت کرش نمی‌کند.
library;

enum ResponseMode { questions, diagnosis }

enum DiagnosisUrgency { green, yellow, red }

enum DiagnosisConfidence { high, medium, low }

enum ProbabilityLevel { high, medium, low }

enum CostBand { low, medium, high }

T _enumFromString<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  if (raw is! String) return fallback;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

String? _nullableString(dynamic raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class DiagnosisQuestionOption {
  final String question;
  final List<String> options;

  const DiagnosisQuestionOption({required this.question, required this.options});

  factory DiagnosisQuestionOption.fromJson(Map<String, dynamic> json) => DiagnosisQuestionOption(
        question: _nullableString(json['question']) ?? '',
        options: _stringList(json['options']),
      );
}

class DiagnosisCause {
  final String title;
  final ProbabilityLevel probability;
  final String why;
  final CostBand costBand;
  final String? costEstimate;
  final String? diyCheck;

  const DiagnosisCause({
    required this.title,
    required this.probability,
    required this.why,
    required this.costBand,
    this.costEstimate,
    this.diyCheck,
  });

  factory DiagnosisCause.fromJson(Map<String, dynamic> json) => DiagnosisCause(
        title: _nullableString(json['title']) ?? '',
        probability:
            _enumFromString(ProbabilityLevel.values, json['probability'], ProbabilityLevel.low),
        why: _nullableString(json['why']) ?? '',
        costBand: _enumFromString(CostBand.values, json['costBand'], CostBand.medium),
        costEstimate: _nullableString(json['costEstimate']),
        diyCheck: _nullableString(json['diyCheck']),
      );
}

class DiagnosisResult {
  final ResponseMode responseMode;
  final int followUpRound;
  final List<String> missingInfo;
  final List<String> followUpQuestions;
  final List<DiagnosisQuestionOption> questionOptions;
  final DiagnosisUrgency urgency;
  final DiagnosisConfidence confidence;
  final bool? safeToDrive;
  final List<String> evidence;
  final String statusSummary;
  final List<DiagnosisCause> causes;
  final List<String> mechanicQuestions;
  final List<String> warnings;
  final String nextStep;
  final String footer;

  const DiagnosisResult({
    required this.responseMode,
    required this.followUpRound,
    required this.missingInfo,
    required this.followUpQuestions,
    required this.questionOptions,
    required this.urgency,
    required this.confidence,
    required this.safeToDrive,
    required this.evidence,
    required this.statusSummary,
    required this.causes,
    required this.mechanicQuestions,
    required this.warnings,
    required this.nextStep,
    required this.footer,
  });

  bool get isUrgent => urgency == DiagnosisUrgency.red;

  /// پارس محافظه‌کارانه. اگر ورودی نامعتبر بود null برمی‌گرداند تا UI
  /// به‌جای کرش، از fallback متنی استفاده کند.
  static DiagnosisResult? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final causesRaw = json['causes'];
      final causes = causesRaw is List
          ? causesRaw
              .whereType<Map>()
              .map((e) => DiagnosisCause.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.title.isNotEmpty)
              .toList()
          : <DiagnosisCause>[];

      final parsed = DiagnosisResult(
        responseMode:
            _enumFromString(ResponseMode.values, json['responseMode'], ResponseMode.diagnosis),
        followUpRound: (json['followUpRound'] as num?)?.toInt() ?? 0,
        missingInfo: _stringList(json['missingInfo']),
        followUpQuestions: _stringList(json['followUpQuestions']),
        questionOptions: json['questionOptions'] is List
            ? (json['questionOptions'] as List)
                .whereType<Map>()
                .map((e) => DiagnosisQuestionOption.fromJson(Map<String, dynamic>.from(e)))
                .where((e) => e.question.isNotEmpty && e.options.length >= 2)
                .take(6)
                .toList()
            : const [],
        // در ابهام، جانب احتیاط را می‌گیریم: پیش‌فرض «yellow» نه «green».
        urgency: _enumFromString(DiagnosisUrgency.values, json['urgency'], DiagnosisUrgency.yellow),
        confidence:
            _enumFromString(DiagnosisConfidence.values, json['confidence'], DiagnosisConfidence.low),
        safeToDrive: json['safeToDrive'] is bool ? json['safeToDrive'] as bool : null,
        evidence: _stringList(json['evidence']),
        statusSummary: _nullableString(json['statusSummary']) ?? '',
        causes: causes,
        mechanicQuestions: _stringList(json['mechanicQuestions']),
        warnings: _stringList(json['warnings']),
        nextStep: _nullableString(json['nextStep']) ?? '',
        footer: _nullableString(json['footer']) ?? '',
      );
      return parsed.hasRenderableContent ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  /// اگر JSON ساختاری هیچ محتوای قابل‌نمایش نداشت، UI باید به متن ساده برگردد.
  bool get hasRenderableContent =>
      statusSummary.isNotEmpty ||
      causes.isNotEmpty ||
      questionOptions.isNotEmpty ||
      followUpQuestions.isNotEmpty ||
      mechanicQuestions.isNotEmpty ||
      warnings.isNotEmpty ||
      nextStep.isNotEmpty;
}
