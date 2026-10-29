import 'questionnaire_catalog.dart';
import 'discovery_questions.dart';

enum ClaimSectionStatus { notStarted, inProgress, done }

ClaimSectionStatus firstClaimStatus(
  bool? firstClaim, {
  int supplementalCount = 0,
}) {
  if (firstClaim == null) return ClaimSectionStatus.notStarted;
  if (firstClaim) return ClaimSectionStatus.done;
  if (supplementalCount > 0) return ClaimSectionStatus.done;
  return ClaimSectionStatus.inProgress;
}

ClaimSectionStatus questionsStatus(QuestionnaireSession session) {
  final visible = visibleCatalogQuestions(session.questions, session.answers);
  if (visible.isEmpty) return ClaimSectionStatus.notStarted;
  final answered = visible
      .where((question) => session.answers.containsKey(question.id))
      .length;
  if (answered == 0) return ClaimSectionStatus.notStarted;
  if (answered == visible.length) return ClaimSectionStatus.done;
  return ClaimSectionStatus.inProgress;
}

ClaimSectionStatus documentsStatus(int count) {
  if (count == 0) return ClaimSectionStatus.notStarted;
  return ClaimSectionStatus.inProgress;
}

ClaimSectionStatus examsStatus(int count) {
  if (count == 0) return ClaimSectionStatus.notStarted;
  return ClaimSectionStatus.inProgress;
}

ClaimSectionStatus decisionsStatus(int count) {
  if (count == 0) return ClaimSectionStatus.notStarted;
  return ClaimSectionStatus.inProgress;
}

ClaimSectionStatus formsStatus(int count) {
  if (count == 0) return ClaimSectionStatus.notStarted;
  return ClaimSectionStatus.inProgress;
}

ClaimSectionStatus packageStatus(bool started) {
  if (!started) return ClaimSectionStatus.notStarted;
  return ClaimSectionStatus.inProgress;
}

ClaimSectionStatus issuesStatus({
  required List<DiscoveryCondition> conditions,
  required Set<String> claimedIds,
}) {
  if (conditions.isEmpty) return ClaimSectionStatus.notStarted;
  final open = conditions.where(
    (condition) => !claimedIds.contains(condition.id),
  );
  if (open.isEmpty) return ClaimSectionStatus.done;
  return ClaimSectionStatus.inProgress;
}

String firstClaimLabel(bool? firstClaim) {
  if (firstClaim == null) return 'Case Info';
  return 'Case Info';
}
