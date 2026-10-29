import 'claim_issue.dart';
import 'claim_sections.dart';
import 'questionnaire_catalog.dart';

/// Which part of an issue the path has open, or null when the list is alone.
String? issuePanelFromPath(String path, String issueId) {
  final marker = '/conditions/$issueId/';
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

const conditionPanelOrder = [
  'questions',
  'decisions',
  'connection',
  'lay',
  'doctor',
];

/// The next open condition part after [from].
///
/// Null means this is the last open part. [laterClosed] skips the connection,
/// the statement, and the doctor draft.
String? nextConditionPanel(String from, {required bool laterClosed}) {
  final start = conditionPanelOrder.indexOf(from);
  if (start < 0) return null;
  for (var index = start + 1; index < conditionPanelOrder.length; index++) {
    final panel = conditionPanelOrder[index];
    if (laterClosed && panel != 'questions' && panel != 'decisions') continue;
    return panel;
  }
  return null;
}

/// The first open part that is not [ClaimSectionStatus.done].
///
/// Closed parts are skipped. When every open part is done, this is the last
/// open part. A missing status counts as not done.
String firstUnfinishedConditionPanel({
  required Map<String, ClaimSectionStatus> status,
  required bool laterClosed,
  bool skipDoctor = false,
}) {
  final open = <String>[
    for (final panel in conditionPanelOrder)
      if (_conditionPanelOpen(
        panel,
        laterClosed: laterClosed,
        skipDoctor: skipDoctor,
      ))
        panel,
  ];
  for (final panel in open) {
    if (status[panel] != ClaimSectionStatus.done) return panel;
  }
  return open.last;
}

bool _conditionPanelOpen(
  String panel, {
  required bool laterClosed,
  required bool skipDoctor,
}) {
  if (laterClosed && panel != 'questions' && panel != 'decisions') {
    return false;
  }
  if (skipDoctor && panel == 'doctor') return false;
  return true;
}

/// Questions about this, for choosing where a condition opens.
///
/// A condition with no topic questions is done, so the flow moves on.
ClaimSectionStatus conditionQuestionsFill({
  required List<CatalogQuestion> questions,
  required Map<String, List<String>> answers,
  required String conditionId,
}) {
  final pageId = catalogPageIdForCondition(questions, conditionId);
  if (pageId == null) return ClaimSectionStatus.done;
  final status = topicQuestionsStatus(
    questions: questions,
    answers: answers,
    conditionId: conditionId,
  );
  if (status != ClaimSectionStatus.notStarted) return status;
  final pages = [
    for (final page in catalogPages(questions, answers))
      if (page.id == pageId) page,
  ];
  if (pages.isEmpty || pages.first.questions.isEmpty) {
    return ClaimSectionStatus.done;
  }
  return status;
}

/// The previous open condition part before [from].
///
/// Null means [from] is Questions about this. [laterClosed] skips the
/// connection, the statement, and the doctor draft.
String? previousConditionPanel(String from, {required bool laterClosed}) {
  final start = conditionPanelOrder.indexOf(from);
  if (start <= 0) return null;
  for (var index = start - 1; index >= 0; index--) {
    final panel = conditionPanelOrder[index];
    if (laterClosed && panel != 'questions' && panel != 'decisions') continue;
    return panel;
  }
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
