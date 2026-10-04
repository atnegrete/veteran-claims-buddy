import 'claim_issue.dart';
import 'claim_sections.dart';
import 'questionnaire_catalog.dart';

/// Which part of an issue the path has open, or null when the list is alone.
String? issuePanelFromPath(String path, String issueId) {
  final marker = '/issues/$issueId/';
  final index = path.indexOf(marker);
  if (index < 0) return null;
  final rest = path.substring(index + marker.length);
  if (rest.startsWith('questions')) return 'questions';
  if (rest.startsWith('evidence')) return 'evidence';
  if (rest.startsWith('connection')) return 'connection';
  if (rest.startsWith('statements/lay')) return 'lay';
  if (rest.startsWith('statements/doctor-draft')) return 'doctor';
  if (rest.startsWith('decisions')) return 'decisions';
  return null;
}

ClaimSectionStatus topicQuestionsStatus({
  required List<CatalogQuestion> questions,
  required Map<String, List<String>> answers,
  required String conditionId,
}) {
  final pageId = catalogPageIdForCondition(questions, conditionId);
  if (pageId == null) return ClaimSectionStatus.notStarted;
  final pages = [
    for (final page in catalogPages(questions, answers))
      if (page.id == pageId) page,
  ];
  if (pages.isEmpty || pages.first.questions.isEmpty) {
    return ClaimSectionStatus.notStarted;
  }
  final visible = pages.first.questions;
  final answered = visible.where((question) {
    return catalogAnswered(question, answers);
  }).length;
  if (answered == 0) return ClaimSectionStatus.notStarted;
  if (answered == visible.length) return ClaimSectionStatus.done;
  return ClaimSectionStatus.inProgress;
}

class EvidenceProgress {
  const EvidenceProgress({required this.added, required this.openLabels});

  final int added;
  final List<String> openLabels;

  bool get complete => added > 0 && openLabels.isEmpty;
}

EvidenceProgress evidenceProgress(List<EvidenceLink> links) {
  final covered = {for (final link in links) link.evidenceType};
  return EvidenceProgress(
    added: links.length,
    openLabels: [
      for (final row in directEvidenceMatrix)
        if (!covered.contains(row.type)) row.label,
    ],
  );
}

ClaimSectionStatus countStatus(int count, {bool complete = false}) {
  if (count <= 0) return ClaimSectionStatus.notStarted;
  if (complete) return ClaimSectionStatus.done;
  return ClaimSectionStatus.inProgress;
}

String? addedLabel(int count) {
  if (count <= 0) return null;
  if (count == 1) return '1 added';
  return '$count added';
}

int filledPartCount({
  required ClaimSectionStatus questions,
  required int evidenceNotes,
  required int connections,
  required bool lay,
  required bool doctorDraft,
  required int decisions,
}) {
  var count = 0;
  if (questions != ClaimSectionStatus.notStarted) count++;
  if (evidenceNotes > 0) count++;
  if (connections > 0) count++;
  if (lay) count++;
  if (doctorDraft) count++;
  if (decisions > 0) count++;
  return count;
}

String issueFilledLabel(int count) {
  if (count <= 0) return 'Nothing filled in yet';
  if (count == 1) return '1 part filled in';
  return '$count parts filled in';
}

bool statementSaved(IssueStatement? statement) {
  final body = statement?.body.trim() ?? '';
  return body.isNotEmpty;
}
