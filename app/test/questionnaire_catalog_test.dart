import 'dart:convert';
import 'dart:io';

import 'package:app/claim/claim_sections.dart';
import 'package:app/claim/questionnaire_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a body-system yes does not create a condition', () {
    const head = CatalogQuestion(
      id: 'head',
      prompt: 'Head?',
      answerType: 'singleChoice',
      order: 3,
      options: [
        CatalogChoice(value: 'yes', label: 'Yes'),
        CatalogChoice(value: 'no', label: 'No'),
      ],
    );
    const heart = CatalogQuestion(
      id: 'heart.which',
      prompt: 'Which heart problem?',
      answerType: 'multiChoice',
      order: 1,
      section: 'heart',
      showWhen: [CatalogRule(questionId: 'cardiovascular', equals: 'yes')],
      createsEachOption: true,
      options: [
        CatalogChoice(value: 'heart_attack', label: 'Heart attack'),
        CatalogChoice(value: 'none', label: 'None of these'),
      ],
    );
    const gate = CatalogQuestion(
      id: 'cardiovascular',
      prompt: 'Heart?',
      answerType: 'singleChoice',
      order: 0,
      options: [
        CatalogChoice(value: 'yes', label: 'Yes'),
        CatalogChoice(value: 'no', label: 'No'),
      ],
    );
    final questions = [gate, head, heart];
    final no = applyCatalogAnswer(questions, const {}, 'cardiovascular', [
      'no',
    ]);
    expect(visibleCatalogQuestions(questions, no).map((q) => q.id), [
      'cardiovascular',
      'head',
    ]);
    expect(catalogConditions(questions, no), isEmpty);

    final yes = applyCatalogAnswer(questions, const {}, 'cardiovascular', [
      'yes',
    ]);
    expect(
      nextCatalogQuestionId(questions, yes, 'cardiovascular'),
      'heart.which',
    );
    final checked = applyCatalogAnswer(questions, yes, 'heart.which', [
      'heart_attack',
      'none',
    ]);
    expect(catalogConditions(questions, checked).map((c) => c.name), [
      'Heart attack',
    ]);
    expect(
      catalogConditions(questions, checked).single.id,
      'heart.which__heart_attack',
    );
  });

  test('changing a gate to no drops the follow-up', () {
    const gate = CatalogQuestion(
      id: 'cardiovascular',
      prompt: 'Heart?',
      answerType: 'singleChoice',
      order: 0,
      options: [
        CatalogChoice(value: 'yes', label: 'Yes'),
        CatalogChoice(value: 'no', label: 'No'),
      ],
    );
    const heart = CatalogQuestion(
      id: 'heart.which',
      prompt: 'Which?',
      answerType: 'multiChoice',
      order: 1,
      showWhen: [CatalogRule(questionId: 'cardiovascular', equals: 'yes')],
      createsEachOption: true,
      options: [
        CatalogChoice(value: 'heart_attack', label: 'Heart attack'),
        CatalogChoice(value: 'none', label: 'None of these'),
      ],
    );
    var answers = applyCatalogAnswer(
      [gate, heart],
      const {},
      'cardiovascular',
      ['yes'],
    );
    answers = applyCatalogAnswer(
      [gate, heart],
      answers,
      'heart.which',
      ['heart_attack'],
    );
    answers = applyCatalogAnswer(
      [gate, heart],
      answers,
      'cardiovascular',
      ['no'],
    );
    expect(answers.containsKey('heart.which'), isFalse);
    expect(catalogConditions([gate, heart], answers), isEmpty);
  });

  test(
    'spina bifida stays out of the intake and a gate does not name a condition',
    () {
      final file = File('../questionnaires/condition-discovery-v2.json');
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final questions = [
        for (final item in raw['questions'] as List)
          catalogQuestionFromMap(
            Map<String, dynamic>.from(item as Map),
            item['id'] as String,
          ),
      ];
      final head = questions.singleWhere((question) => question.id == 'head');
      expect(head.createsCondition, isNull);
      expect(head.createsEachOption, isFalse);
      final muscle = questions.singleWhere(
        (question) => question.id == 'muscle.which',
      );
      expect(muscle.options.length, greaterThanOrEqualTo(23));
      final child = questions.singleWhere(
        (question) => question.id == 'sb.type',
      );
      expect(child.includeInIntake, isFalse);
      expect(
        visibleCatalogQuestions(questions, const {}).map((q) => q.id),
        isNot(contains('sb.type')),
      );
    },
  );

  test('gates share a page and a yes opens the next body system', () {
    const gate = CatalogQuestion(
      id: 'cardiovascular',
      prompt: 'Heart?',
      answerType: 'singleChoice',
      order: 0,
      section: 'gates',
      options: [
        CatalogChoice(value: 'yes', label: 'Yes'),
        CatalogChoice(value: 'no', label: 'No'),
      ],
    );
    const eyes = CatalogQuestion(
      id: 'eyes',
      prompt: 'Eyes?',
      answerType: 'singleChoice',
      order: 1,
      section: 'gates',
      options: [
        CatalogChoice(value: 'yes', label: 'Yes'),
        CatalogChoice(value: 'no', label: 'No'),
      ],
    );
    const heart = CatalogQuestion(
      id: 'heart.which',
      prompt: 'Which?',
      answerType: 'multiChoice',
      order: 2,
      section: 'heart',
      showWhen: [CatalogRule(questionId: 'cardiovascular', equals: 'yes')],
      createsEachOption: true,
      options: [
        CatalogChoice(value: 'heart_attack', label: 'Heart attack'),
        CatalogChoice(value: 'none', label: 'None of these'),
      ],
    );
    final questions = [gate, eyes, heart];
    final start = catalogPages(questions, const {});
    expect(start.map((page) => page.id), ['gates']);
    expect(start.single.questions.map((q) => q.id), ['cardiovascular', 'eyes']);
    final yes = applyCatalogAnswer(questions, const {}, 'cardiovascular', [
      'yes',
    ]);
    expect(catalogPages(questions, yes).map((page) => page.id), [
      'gates',
      'heart',
    ]);
    const detail = CatalogQuestion(
      id: 'heart.start',
      prompt: 'When?',
      answerType: 'yearMonth',
      order: 3,
      showWhen: [CatalogRule(questionId: 'cardiovascular', equals: 'yes')],
    );
    final withDetail = catalogPages([gate, eyes, heart, detail], yes);
    expect(withDetail.map((page) => page.id), ['gates', 'heart']);
    expect(withDetail.first.questions.map((question) => question.id), [
      'cardiovascular',
      'eyes',
    ]);
    expect(
      withDetail.last.questions.map((question) => question.id),
      contains('heart.start'),
    );
    expect(resumeCatalogPageId(questions, yes), 'gates');
    final both = applyCatalogAnswer(questions, yes, 'eyes', ['no']);
    expect(resumeCatalogPageId(questions, both), 'heart');
  });

  test('a save writes only answers that changed', () {
    final diff = diffAnswers(
      const {
        'head': ['yes'],
        'eyes': ['no'],
      },
      const {
        'head': ['yes'],
        'sleep': ['yes'],
      },
    );
    expect(diff.changed.keys, ['sleep']);
    expect(diff.removed, {'eyes'});
  });

  test('section status uses the saved answers', () {
    expect(firstClaimStatus(null), ClaimSectionStatus.notStarted);
    expect(firstClaimStatus(true), ClaimSectionStatus.done);
    expect(firstClaimStatus(false), ClaimSectionStatus.inProgress);
    expect(
      firstClaimStatus(false, supplementalCount: 1),
      ClaimSectionStatus.done,
    );
    expect(firstClaimLabel(null), 'Case Info');
    expect(firstClaimLabel(false), 'Case Info');
    expect(firstClaimLabel(true), 'Case Info');
    final session = QuestionnaireSession(
      answers: const {
        'head': ['yes'],
      },
      questions: widgetPreviewCatalog,
    );
    expect(questionsStatus(session), ClaimSectionStatus.inProgress);
    expect(
      questionsStatus(
        const QuestionnaireSession(
          answers: {
            'head': ['no'],
            'eyes': ['no'],
          },
          questions: widgetPreviewCatalog,
        ),
      ),
      ClaimSectionStatus.done,
    );
    expect(
      issuesStatus(conditions: const [], claimedIds: const {}),
      ClaimSectionStatus.notStarted,
    );
  });

  test('includesAny shows the question when any listed choice is checked', () {
    final night = catalogQuestionFromMap(const {
      'prompt': 'How many times do you get up at night to urinate?',
      'answerType': 'singleChoice',
      'showWhen': [
        {
          'questionId': 'head.which',
          'includesAny': ['parkinsons', 'ms', 'als'],
        },
      ],
    }, 'neuro.night');
    expect(
      catalogQuestionVisible(night, const {
        'head.which': ['migraine'],
      }),
      isFalse,
    );
    expect(
      catalogQuestionVisible(night, const {
        'head.which': ['ms'],
      }),
      isTrue,
    );
  });

  test('a condition opens the topic page that created it', () {
    const which = CatalogQuestion(
      id: 'heart.which',
      prompt: 'Which heart problem?',
      answerType: 'multiChoice',
      order: 1,
      section: 'heart',
      showWhen: [CatalogRule(questionId: 'cardiovascular', equals: 'yes')],
    );
    expect(
      catalogPageIdForCondition(const [which], 'heart.which__attack'),
      'heart',
    );
    expect(catalogPageIdForCondition(const [which], 'missing'), isNull);
  });

  test('a topic lists follow-ups that do not apply yet', () {
    const gate = CatalogQuestion(
      id: 'gastrointestinal',
      prompt: 'Stomach?',
      answerType: 'singleChoice',
      order: 0,
      section: 'gates',
    );
    const which = CatalogQuestion(
      id: 'gi.which',
      prompt: 'Which of these fit?',
      answerType: 'multiChoice',
      order: 1,
      section: 'gi',
      showWhen: [CatalogRule(questionId: 'gastrointestinal', equals: 'yes')],
    );
    const pain = CatalogQuestion(
      id: 'ibs.pain',
      prompt: 'How often?',
      answerType: 'singleChoice',
      order: 2,
      section: 'gi',
      showWhen: [CatalogRule(questionId: 'gi.which', includes: 'ibs')],
    );
    final questions = [gate, which, pain];
    final yes = applyCatalogAnswer(questions, const {}, 'gastrointestinal', [
      'yes',
    ]);
    expect(
      catalogTopicQuestions(questions, 'gi').map((question) => question.id),
      ['gi.which', 'ibs.pain'],
    );
    expect(
      catalogPages(
        questions,
        yes,
      ).last.questions.map((question) => question.id),
      ['gi.which'],
    );
    expect(
      catalogBlockedLabel(pain, questions, yes),
      "Does not apply based on your answer to 'Which of these fit?'",
    );
    expect(
      catalogBlockedLabel(
        pain,
        questions,
        yes,
        labels: const {'gi.which': '2. Which of these fit?'},
      ),
      "Does not apply based on your answer to '2. Which of these fit?'",
    );
    final ibs = applyCatalogAnswer(questions, yes, 'gi.which', ['ibs']);
    expect(catalogBlockedLabel(pain, questions, ibs), isNull);
  });
}
