import '../forms/iso_date_field.dart';
import 'claim_issue.dart';
import 'va_rules.dart';

const decisionSummaryMax = 2000;
const decisionNameMax = 120;
const decisionFindingMax = 2000;
const decisionReasonMax = 2000;
const decisionEvidenceMax = 200;

const letterOutcomes = <String, String>{...decisionOutcomes, 'other': 'Other'};

const decisionReasonCategories = <String, String>{
  'nexus': 'Connection',
  'diagnosis': 'Diagnosis',
  'inServiceEvent': 'In-service event',
  'severity': 'Severity',
  'other': 'Other',
};

class DecisionFinding {
  const DecisionFinding({required this.text, this.page});

  final String text;
  final int? page;

  static DecisionFinding? fromData(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    final page = raw['page'];
    return DecisionFinding(text: text, page: page is int ? page : null);
  }
}

class DecisionReason {
  const DecisionReason({required this.text, required this.category, this.page});

  final String text;
  final String category;
  final int? page;

  static DecisionReason? fromData(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    final category = raw['category'] as String?;
    final page = raw['page'];
    return DecisionReason(
      text: text,
      category: decisionReasonCategories.containsKey(category)
          ? category!
          : 'other',
      page: page is int ? page : null,
    );
  }
}

class ClaimDecision {
  const ClaimDecision({
    required this.id,
    required this.caseId,
    required this.decisionDate,
    required this.receivedDate,
    required this.sourceDocumentId,
    required this.sourceType,
    required this.status,
    required this.overallSummary,
  });

  final String id;
  final String caseId;
  final String decisionDate;
  final String? receivedDate;
  final String? sourceDocumentId;
  final String sourceType;
  final String status;
  final String overallSummary;

  bool get needsReview => status == 'needsReview';

  static ClaimDecision fromData(String id, Map<String, dynamic> data) {
    final received = data['receivedDate'];
    final source = data['sourceDocumentId'];
    return ClaimDecision(
      id: id,
      caseId: data['caseId'] as String? ?? '',
      decisionDate: data['decisionDate'] as String? ?? '',
      receivedDate: received is String && received.isNotEmpty ? received : null,
      sourceDocumentId: source is String && source.isNotEmpty ? source : null,
      sourceType: data['sourceType'] as String? ?? '',
      status: data['status'] as String? ?? '',
      overallSummary: data['overallSummary'] as String? ?? '',
    );
  }
}

class ClaimDecisionIssue {
  const ClaimDecisionIssue({
    required this.id,
    required this.decisionId,
    required this.conditionId,
    required this.displayName,
    required this.outcome,
    required this.ratingPercent,
    required this.effectiveDate,
    required this.findings,
    required this.reasons,
    required this.evidence,
    required this.confidence,
    required this.userConfirmed,
  });

  final String id;
  final String decisionId;
  final String? conditionId;
  final String displayName;
  final String outcome;
  final int? ratingPercent;
  final String? effectiveDate;
  final List<DecisionFinding> findings;
  final List<DecisionReason> reasons;
  final List<String> evidence;
  final double? confidence;
  final bool userConfirmed;

  static ClaimDecisionIssue fromData(String id, Map<String, dynamic> data) {
    final conditionId = data['conditionId'];
    final rating = data['ratingPercent'];
    final effective = data['effectiveDate'];
    final confidence = data['extractionConfidence'];
    return ClaimDecisionIssue(
      id: id,
      decisionId: data['decisionId'] as String? ?? '',
      conditionId: conditionId is String && conditionId.isNotEmpty
          ? conditionId
          : null,
      displayName: data['displayName'] as String? ?? '',
      outcome: data['outcome'] as String? ?? 'other',
      ratingPercent: rating is int ? rating : null,
      effectiveDate: effective is String && effective.isNotEmpty
          ? effective
          : null,
      findings: _rows(data['favorableFindings'], DecisionFinding.fromData),
      reasons: _rows(data['reasons'], DecisionReason.fromData),
      evidence: [
        for (final item in data['evidenceConsidered'] as List? ?? const [])
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ],
      confidence: confidence is num ? confidence.toDouble() : null,
      userConfirmed: data['userConfirmed'] == true,
    );
  }
}

String oneYearAfterDecision(String isoDate) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(isoDate);
  if (match == null) return '';
  final date = DateTime.utc(
    int.parse(match.group(1)!) + reviewDeadlineYears,
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String? decisionConfirmError({
  required String decisionDate,
  required String receivedDate,
  required String summary,
  required List<
    ({
      String name,
      String outcome,
      int? rating,
      String effectiveDate,
      List<String> findings,
      List<({String text, String category})> reasons,
    })
  >
  issues,
}) {
  if (!validIsoDate(decisionDate)) {
    return 'Enter the decision date as YYYY-MM-DD.';
  }
  if (receivedDate.isNotEmpty && !validIsoDate(receivedDate)) {
    return 'Enter the received date as YYYY-MM-DD.';
  }
  if (summary.trim().length > decisionSummaryMax) {
    return 'Shorten the summary.';
  }
  if (issues.isEmpty) return 'This letter has no condition to confirm.';
  for (final issue in issues) {
    final name = issue.name.trim();
    if (name.isEmpty || name.length > decisionNameMax) {
      return 'Enter the condition name.';
    }
    if (!letterOutcomes.containsKey(issue.outcome)) {
      return 'Choose the outcome.';
    }
    final rating = issue.rating;
    if (rating != null && (rating < 0 || rating > 100 || rating % 10 != 0)) {
      return 'Choose a rating from the list.';
    }
    if (issue.effectiveDate.isNotEmpty && !validIsoDate(issue.effectiveDate)) {
      return 'Enter the effective date as YYYY-MM-DD.';
    }
    for (final finding in issue.findings) {
      if (finding.trim().length > decisionFindingMax) {
        return 'Shorten a favorable finding.';
      }
    }
    for (final reason in issue.reasons) {
      if (reason.text.trim().length > decisionReasonMax) {
        return 'Shorten a reason.';
      }
    }
  }
  return null;
}

/// A parsed letter stays off the claim until it is confirmed.
bool decisionOnClaim(String status) => status == 'confirmed';

List<T> _rows<T>(Object? raw, T? Function(Object? item) read) {
  if (raw is! List) return <T>[];
  final rows = <T>[];
  for (final item in raw) {
    final row = read(item);
    if (row != null) rows.add(row);
  }
  return rows;
}
