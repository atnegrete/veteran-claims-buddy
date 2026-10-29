import '../auth/auth_redirect.dart';
import 'claim_document.dart';
import 'claim_issue.dart';
import 'claim_review.dart';
import 'claim_sections.dart';
import 'issue_progress.dart';
import 'questionnaire_catalog.dart';

/// The one step the claim screen shows. Calculated from the claim, not chosen
/// by a model.
enum NextActionKind {
  firstClaim,
  earlierPaperwork,
  questions,
  addIssue,
  issueQuestions,
  reviewFile,
  decisionReview,
  selfSubmit,
  formsLater,
}

class NextAction {
  const NextAction({
    required this.kind,
    required this.type,
    required this.title,
    required this.description,
    required this.caseId,
    this.route,
    this.buttonLabel,
    this.conditionId,
  });

  final NextActionKind kind;

  /// Handoff task type. Not a filing status.
  final String type;
  final String title;
  final String description;
  final String caseId;
  final String? route;
  final String? buttonLabel;
  final String? conditionId;

  String get syncKey => '$kind|$title|$route|$conditionId';
}

class NextActionInput {
  const NextActionInput({
    required this.caseId,
    required this.firstClaim,
    required this.documents,
    required this.session,
    required this.issues,
    this.reviews = const [],
    this.reviewDraftIds = const {},
    this.reviewDrafts = const [],
  });

  final String caseId;
  final bool? firstClaim;
  final List<ClaimDocument> documents;
  final QuestionnaireSession session;
  final List<ClaimIssue> issues;
  final List<ReviewCandidate> reviews;
  final Set<String> reviewDraftIds;
  final List<ClaimReview> reviewDrafts;
}

NextAction nextActionFor(NextActionInput input) {
  final caseId = input.caseId;
  if (input.firstClaim == null) {
    return NextAction(
      kind: NextActionKind.firstClaim,
      type: 'completeQuestionnaire',
      title: 'Is this your first VA disability claim?',
      description: 'A first claim starts with symptoms. An earlier claim starts with that paperwork.',
      caseId: caseId,
      route: caseId.isEmpty ? null : AuthRoutes.caseStep(caseId),
    );
  }
  final saved = [
    for (final document in input.documents)
      if (document.uploadStatus == 'uploaded') document,
  ];
  if (input.firstClaim == false && !saved.any(supportsEarlierClaim)) {
    return NextAction(
      kind: NextActionKind.earlierPaperwork,
      type: 'uploadEvidence',
      title: 'Add the paperwork from your earlier claim',
      description: 'Add the VA decision from the claim you want to pursue again. You can also add it in My Uploads.',
      caseId: caseId,
      route: caseId.isEmpty ? null : AuthRoutes.caseStep(caseId),
      buttonLabel: 'Continue',
    );
  }
  if (questionsStatus(input.session) != ClaimSectionStatus.done) {
    return NextAction(
      kind: NextActionKind.questions,
      type: 'completeQuestionnaire',
      title: 'Continue the symptom questions',
      description: 'The symptom questions for this claim are still open.',
      caseId: caseId,
      route: caseId.isEmpty ? null : AuthRoutes.caseQuestions(caseId),
      buttonLabel: 'Continue',
    );
  }
  final claimed = {
    for (final issue in input.issues)
      if (issue.activeCaseId == caseId) issue.conditionId,
  };
  for (final condition in catalogConditions(
    input.session.questions,
    input.session.answers,
  )) {
    if (claimed.contains(condition.id)) continue;
    return NextAction(
      kind: NextActionKind.addIssue,
      type: 'other',
      title: _fit('Add ${condition.name} to this claim'),
      description: 'A condition is not part of this claim until you add it.',
      caseId: caseId,
      route: caseId.isEmpty ? null : AuthRoutes.caseConditions(caseId),
      buttonLabel: 'Add to this claim',
    );
  }
  for (final issue in input.issues) {
    if (issue.activeCaseId != caseId) continue;
    if (!_topicOpen(input.session, issue.conditionId)) continue;
    return NextAction(
      kind: NextActionKind.issueQuestions,
      type: 'completeQuestionnaire',
      title: _fit('Answer the questions for ${issue.displayName}'),
      description: 'These questions are for this condition.',
      caseId: caseId,
      route: caseId.isEmpty
          ? null
          : AuthRoutes.caseConditionQuestions(caseId, issue.id),
      buttonLabel: 'Continue',
      conditionId: issue.id,
    );
  }
  for (final document in saved) {
    if (document.processingStatus != 'needsReview') continue;
    return NextAction(
      kind: NextActionKind.reviewFile,
      type: 'uploadEvidence',
      title: _fit('Review the statements from ${document.name}'),
      description: 'Confirm, correct, or set aside each statement.',
      caseId: caseId,
      route: caseId.isEmpty
          ? null
          : AuthRoutes.caseDocumentFacts(caseId, document.id),
      buttonLabel: 'Review statements',
    );
  }
  for (final candidate in input.reviews) {
    if (!reviewOutcomeEligible(candidate.outcome)) continue;
    if (input.reviewDraftIds.contains(candidate.decisionIssueId)) continue;
    return NextAction(
      kind: NextActionKind.decisionReview,
      type: 'other',
      title: _fit('Choose a review for ${candidate.displayName}'),
      description:
          'A denied, deferred, or reduced issue can continue in this claim.',
      caseId: caseId,
      route: caseId.isEmpty ? null : AuthRoutes.casePrepare(caseId),
      buttonLabel: 'Choose a review',
      conditionId: candidate.conditionId,
    );
  }
  if (input.reviewDrafts.isNotEmpty) {
    final draft = input.reviewDrafts.first;
    return NextAction(
      kind: NextActionKind.selfSubmit,
      type: 'other',
      title: _fit('Submit ${draft.displayName} yourself'),
      description:
          'This app does not file with the VA. You submit form ${draft.formId} on VA.gov or by mail.',
      caseId: caseId,
      route: caseId.isEmpty ? null : AuthRoutes.casePackageSubmit(caseId),
      buttonLabel: 'How to submit',
      conditionId: draft.conditionId,
    );
  }
  return NextAction(
    kind: NextActionKind.formsLater,
    type: 'other',
    title: 'Forms for this claim are not open yet',
    description: 'The questions and conditions for this claim are in.',
    caseId: caseId,
  );
}

bool _topicOpen(QuestionnaireSession session, String conditionId) {
  final pageId = catalogPageIdForCondition(session.questions, conditionId);
  if (pageId == null) return false;
  final pages = [
    for (final page in catalogPages(session.questions, session.answers))
      if (page.id == pageId) page,
  ];
  if (pages.isEmpty || pages.first.questions.isEmpty) return false;
  return topicQuestionsStatus(
        questions: session.questions,
        answers: session.answers,
        conditionId: conditionId,
      ) !=
      ClaimSectionStatus.done;
}

String _fit(String text) {
  if (text.length <= 120) return text;
  return text.substring(0, 120);
}
