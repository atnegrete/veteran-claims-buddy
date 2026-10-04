/// A condition the Veteran chose to pursue on one claim.
///
/// This is not a filing, a rating, or a chance of approval.
class ClaimIssue {
  const ClaimIssue({
    required this.id,
    required this.conditionId,
    required this.displayName,
    required this.activeCaseId,
    required this.status,
  });

  final String id;
  final String conditionId;
  final String displayName;
  final String activeCaseId;
  final String status;

  static ClaimIssue fromData(String id, Map<String, dynamic> data) {
    return ClaimIssue(
      id: id,
      conditionId: data['conditionId'] as String? ?? id,
      displayName: data['displayName'] as String? ?? '',
      activeCaseId: data['activeCaseId'] as String? ?? '',
      status: data['status'] as String? ?? 'potential',
    );
  }
}

/// One row of the direct evidence matrix. [detail] says what is still missing.
class EvidenceNeed {
  const EvidenceNeed({
    required this.type,
    required this.label,
    required this.detail,
  });

  final String type;
  final String label;
  final String detail;
}

/// Completeness of a direct claim. Not a predicted outcome.
const directEvidenceMatrix = <EvidenceNeed>[
  EvidenceNeed(
    type: 'currentDiagnosis',
    label: 'Current disability',
    detail: 'Not added yet',
  ),
  EvidenceNeed(
    type: 'inServiceEvent',
    label: 'In-service event',
    detail: 'Not added yet',
  ),
  EvidenceNeed(type: 'nexus', label: 'Relationship', detail: 'Not added yet'),
  EvidenceNeed(
    type: 'severity',
    label: 'Current severity',
    detail: 'Not added yet',
  ),
  EvidenceNeed(
    type: 'functionalImpact',
    label: 'Functional impact',
    detail: 'Not added yet',
  ),
];

/// A note the Veteran tied to one row. A blank row stays "Not added yet."
List<EvidenceNeed> evidenceNeedsFor(List<EvidenceLink> links) {
  return [
    for (final row in directEvidenceMatrix)
      EvidenceNeed(
        type: row.type,
        label: row.label,
        detail: _evidenceDetail(links, row.type),
      ),
  ];
}

String _evidenceDetail(List<EvidenceLink> links, String type) {
  final notes = [
    for (final link in links)
      if (link.evidenceType == type && link.summary.trim().isNotEmpty)
        link.summary.trim(),
  ];
  if (notes.isEmpty) return 'Not added yet';
  return notes.join('\n');
}

ClaimIssue? findClaimIssue(
  List<ClaimIssue> issues,
  String caseId,
  String issueId,
) {
  for (final issue in issues) {
    if (issue.id == issueId && issue.activeCaseId == caseId) return issue;
  }
  return null;
}

class EvidenceLink {
  const EvidenceLink({
    required this.id,
    required this.claimIssueId,
    required this.evidenceType,
    required this.relationship,
    required this.summary,
  });

  final String id;
  final String claimIssueId;
  final String evidenceType;
  final String relationship;
  final String summary;

  static EvidenceLink fromData(String id, Map<String, dynamic> data) {
    return EvidenceLink(
      id: id,
      claimIssueId: data['claimIssueId'] as String? ?? '',
      evidenceType: data['evidenceType'] as String? ?? '',
      relationship: data['relationship'] as String? ?? 'supports',
      summary: data['summary'] as String? ?? '',
    );
  }
}

const connectionTypes = <String, String>{
  'direct': 'Directly from service',
  'secondary': 'Connected to another condition on this claim',
  'aggravation': 'Made worse in service',
  'presumptive': 'One service may presume',
  'increase': 'A higher rating than one already granted',
};

const evidenceRelationships = <String, String>{
  'supports': 'Supports',
  'conflicts': 'Conflicts',
  'neutral': 'Neutral',
};

const decisionOutcomes = <String, String>{
  'granted': 'Granted',
  'denied': 'Denied',
  'deferred': 'Deferred',
  'increased': 'Increased',
  'continued': 'Continued',
  'reduced': 'Reduced',
};

class ClaimTheory {
  const ClaimTheory({
    required this.id,
    required this.type,
    required this.summary,
    this.relatedClaimIssueId,
  });

  final String id;
  final String type;
  final String summary;
  final String? relatedClaimIssueId;

  static ClaimTheory fromData(String id, Map<String, dynamic> data) {
    final related = data['relatedClaimIssueId'];
    return ClaimTheory(
      id: id,
      type: data['type'] as String? ?? 'direct',
      summary: data['summary'] as String? ?? '',
      relatedClaimIssueId: related is String && related.isNotEmpty
          ? related
          : null,
    );
  }
}

class IssueStatement {
  const IssueStatement({required this.kind, required this.body});

  final String kind;
  final String body;

  static IssueStatement fromData(String id, Map<String, dynamic> data) {
    return IssueStatement(
      kind: data['kind'] as String? ?? id,
      body: data['body'] as String? ?? '',
    );
  }
}

class RecordedDecision {
  const RecordedDecision({
    required this.id,
    required this.decisionDate,
    required this.outcome,
    required this.displayName,
    this.ratingPercent,
    this.effectiveDate,
  });

  final String id;
  final String decisionDate;
  final String outcome;
  final String displayName;
  final int? ratingPercent;
  final String? effectiveDate;

  static RecordedDecision fromIssue(
    String id,
    Map<String, dynamic> data, {
    required String decisionDate,
  }) {
    final rating = data['ratingPercent'];
    final effective = data['effectiveDate'];
    return RecordedDecision(
      id: id,
      decisionDate: decisionDate,
      outcome: data['outcome'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      ratingPercent: rating is int ? rating : null,
      effectiveDate: effective is String && effective.isNotEmpty
          ? effective
          : null,
    );
  }
}
