import 'package:app/claim/claim_document.dart';
import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_review.dart';
import 'package:app/claim/next_action.dart';
import 'package:app/claim/questionnaire_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const questions = <CatalogQuestion>[
    CatalogQuestion(
      id: 'gi',
      prompt: 'Stomach?',
      answerType: 'singleChoice',
      section: 'gates',
      order: 0,
      createsCondition: 'Stomach and bowel',
      options: [
        CatalogChoice(value: 'yes', label: 'Yes'),
        CatalogChoice(value: 'no', label: 'No'),
      ],
    ),
    CatalogQuestion(
      id: 'gi.note',
      prompt: 'How often?',
      answerType: 'singleChoice',
      section: 'gi',
      order: 1,
      showWhen: [CatalogRule(questionId: 'gi', equals: 'yes')],
      options: [CatalogChoice(value: 'daily', label: 'Daily')],
    ),
  ];

  NextAction action({
    bool? firstClaim = true,
    List<ClaimDocument> documents = const [],
    Map<String, List<String>> answers = const {},
    List<ClaimIssue> issues = const [],
  }) {
    return nextActionFor(
      NextActionInput(
        caseId: 'case-1',
        firstClaim: firstClaim,
        documents: documents,
        session: QuestionnaireSession(answers: answers, questions: questions),
        issues: issues,
      ),
    );
  }

  test('an unanswered first claim stays on that question', () {
    expect(action(firstClaim: null).kind, NextActionKind.firstClaim);
  });

  test('an earlier claim without paperwork asks for that file', () {
    final step = action(firstClaim: false);
    expect(step.kind, NextActionKind.earlierPaperwork);
    expect(step.route, '/cases/case-1');
  });

  test('symptom questions come before adding a condition', () {
    final step = action(
      answers: const {
        'gi': ['yes'],
      },
    );
    expect(step.kind, NextActionKind.questions);
    expect(step.route, '/cases/case-1/questions');
  });

  test('a finished questionnaire asks to add the condition', () {
    final step = action(
      answers: const {
        'gi': ['yes'],
        'gi.note': ['daily'],
      },
    );
    expect(step.kind, NextActionKind.addIssue);
    expect(step.title, 'Add Stomach and bowel to this claim');
    expect(step.route, '/cases/case-1/conditions');
  });

  test(
    'a file that needs review comes after the condition is on the claim',
    () {
      final step = action(
        answers: const {
          'gi': ['no'],
        },
        documents: [
          ClaimDocument(
            id: 'doc-1',
            caseId: 'case-1',
            name: 'Decision.pdf',
            documentType: 'decisionLetter',
            uploadStatus: 'uploaded',
            storagePath: 'users/u/documents/doc-1/original.pdf',
            processingStatus: 'needsReview',
          ),
        ],
      );
      expect(step.kind, NextActionKind.reviewFile);
      expect(step.route, '/cases/case-1/evidence/doc-1/facts');
    },
  );

  test('forms stay closed after the questions and issues are in', () {
    final step = action(
      answers: const {
        'gi': ['no'],
      },
    );
    expect(step.kind, NextActionKind.formsLater);
    expect(step.route, isNull);
    expect(step.buttonLabel, isNull);
  });

  test('a denied issue asks for a review before the forms stop', () {
    const candidate = ReviewCandidate(
      decisionId: 'decision-1',
      decisionIssueId: 'issue-1',
      conditionId: null,
      displayName: 'Hearing loss',
      outcome: 'denied',
      decisionDate: '2026-01-15',
    );
    final session = QuestionnaireSession(
      answers: const {
        'gi': ['no'],
      },
      questions: questions,
    );
    final open = nextActionFor(
      NextActionInput(
        caseId: 'case-1',
        firstClaim: true,
        documents: const [],
        session: session,
        issues: const [],
        reviews: const [candidate],
      ),
    );
    expect(open.kind, NextActionKind.decisionReview);
    expect(open.route, '/cases/case-1/prepare');
    expect(open.buttonLabel, 'Choose a review');
    expect(open.title, 'Choose a review for Hearing loss');

    final started = nextActionFor(
      NextActionInput(
        caseId: 'case-1',
        firstClaim: true,
        documents: const [],
        session: session,
        issues: const [],
        reviews: const [candidate],
        reviewDraftIds: const {'issue-1'},
      ),
    );
    expect(started.kind, NextActionKind.formsLater);
  });

  test('a saved review asks the veteran to submit it', () {
    final step = nextActionFor(
      NextActionInput(
        caseId: 'case-1',
        firstClaim: true,
        documents: const [],
        session: QuestionnaireSession(
          answers: const {
            'gi': ['no'],
          },
          questions: questions,
        ),
        issues: const [],
        reviewDrafts: const [
          ClaimReview(
            id: 'review-1',
            caseId: 'case-1',
            type: 'supplementalClaim',
            formId: '20-0995',
            decisionId: 'decision-1',
            decisionIssueId: 'issue-1',
            conditionId: null,
            displayName: 'Hearing loss',
            boardDocket: null,
            informalConference: null,
          ),
        ],
      ),
    );
    expect(step.kind, NextActionKind.selfSubmit);
    expect(step.route, '/cases/case-1/package/submit');
    expect(step.buttonLabel, 'How to submit');
    expect(step.title, 'Submit Hearing loss yourself');
  });
}
