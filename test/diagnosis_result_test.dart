import 'package:flutter_test/flutter_test.dart';
import 'package:smart_mechanic/models/diagnosis_result.dart';

void main() {
  test('tryParse returns null for empty structured payloads', () {
    expect(DiagnosisResult.tryParse(null), isNull);
    expect(DiagnosisResult.tryParse(const {}), isNull);
    expect(
      DiagnosisResult.tryParse(const {'responseMode': 'diagnosis'}),
      isNull,
    );
  });

  test('tryParse keeps questionnaires and causes from loosely typed maps', () {
    final parsed = DiagnosisResult.tryParse({
      'responseMode': 'questions',
      'statusSummary': 'نیاز به اطلاعات بیشتر',
      'questionOptions': [
        <dynamic, dynamic>{
          'question': 'صدا از کجاست؟',
          'options': ['موتور', 'گیربکس'],
        },
      ],
      'causes': [
        <dynamic, dynamic>{
          'title': 'تسمه دینام',
          'probability': 'high',
          'why': 'صدای جیرجیر',
        },
      ],
    });

    expect(parsed, isNotNull);
    expect(parsed!.responseMode, ResponseMode.questions);
    expect(parsed.questionOptions, hasLength(1));
    expect(parsed.questionOptions.first.options, ['موتور', 'گیربکس']);
    expect(parsed.causes, hasLength(1));
    expect(parsed.causes.first.title, 'تسمه دینام');
  });
}
