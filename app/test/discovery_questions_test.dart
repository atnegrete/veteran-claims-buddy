import 'package:app/claim/discovery_questions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a no hides the follow-up and does not add a condition', () {
    final answers = applyDiscoveryAnswer(const {}, 'back', 'no');
    expect(nextDiscoveryQuestionId(answers, 'back'), 'nerves');
    expect(
      visibleDiscoveryQuestions(answers)
          .any((question) => question.id == 'back_radiation'),
      isFalse,
    );
    expect(discoveryConditionNames(answers), isEmpty);
  });

  test('back pain opens the leg question and records both conditions', () {
    var answers = applyDiscoveryAnswer(const {}, 'back', 'yes');
    expect(nextDiscoveryQuestionId(answers, 'back'), 'back_radiation');
    answers = applyDiscoveryAnswer(answers, 'back_radiation', 'yes');
    expect(
      nextDiscoveryQuestionId(answers, 'back_radiation'),
      'back_radiation_side',
    );
    answers = applyDiscoveryAnswer(answers, 'back_radiation_side', 'left');
    expect(
      discoveryConditionNames(answers),
      containsAll(['Recurring back pain', 'Pain traveling down the left leg']),
    );
    expect(
      potentialDiscoveryConditions(answers).map((condition) => condition.id),
      containsAll(['back', 'back_radiation']),
    );
  });

  test('changing back pain to no drops the leg answers', () {
    var answers = applyDiscoveryAnswer(const {}, 'back', 'yes');
    answers = applyDiscoveryAnswer(answers, 'back_radiation', 'yes');
    answers = applyDiscoveryAnswer(answers, 'back', 'no');
    expect(answers.containsKey('back_radiation'), isFalse);
    expect(discoveryConditionNames(answers), isEmpty);
  });
}
