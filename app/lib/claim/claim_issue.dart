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
    required this.conditionId,
    required this.evidenceType,
    required this.relationship,
    required this.summary,
  });

  final String id;
  final String conditionId;
  final String evidenceType;
  final String relationship;
  final String summary;

  static EvidenceLink fromData(String id, Map<String, dynamic> data) {
    return EvidenceLink(
      id: id,
      conditionId: data['conditionId'] as String? ?? '',
      evidenceType: data['evidenceType'] as String? ?? '',
      relationship: data['relationship'] as String? ?? 'supports',
      summary: data['summary'] as String? ?? '',
    );
  }
}

const connectionTypes = <String, String>{
  'direct': 'Directly from service',
  'secondary': 'Connected to another condition',
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
    this.relatedConditionName,
  });

  final String id;
  final String type;
  final String summary;
  final String? relatedConditionName;

  static ClaimTheory fromData(String id, Map<String, dynamic> data) {
    final related = data['relatedConditionName'];
    return ClaimTheory(
      id: id,
      type: data['type'] as String? ?? 'direct',
      summary: data['summary'] as String? ?? '',
      relatedConditionName: related is String && related.isNotEmpty
          ? related
          : null,
    );
  }
}

const layFrequencyLabel = 'How often:';
const layDurationLabel = 'How long:';
const layImpactLabel = 'What it keeps you from doing:';

/// Frequency, duration, and impact saved as one lay-statement body.
class LayEffects {
  const LayEffects({this.frequency = '', this.duration = '', this.impact = ''});

  final String frequency;
  final String duration;
  final String impact;

  bool get isEmpty =>
      frequency.trim().isEmpty &&
      duration.trim().isEmpty &&
      impact.trim().isEmpty;

  String toBody() {
    final parts = <String>[];
    final often = frequency.trim();
    final lasts = duration.trim();
    final limits = impact.trim();
    if (often.isNotEmpty) parts.add('$layFrequencyLabel $often');
    if (lasts.isNotEmpty) parts.add('$layDurationLabel $lasts');
    if (limits.isNotEmpty) parts.add('$layImpactLabel $limits');
    return parts.join('\n\n');
  }

  static LayEffects fromBody(String body) {
    final text = body.trim();
    if (text.isEmpty) return const LayEffects();
    final labeled =
        text.startsWith(layFrequencyLabel) ||
        text.startsWith(layDurationLabel) ||
        text.startsWith(layImpactLabel);
    if (!labeled) return LayEffects(impact: text);

    String take(String label) {
      final start = text.indexOf(label);
      if (start < 0) return '';
      final from = start + label.length;
      var end = text.length;
      for (final other in const [
        layFrequencyLabel,
        layDurationLabel,
        layImpactLabel,
      ]) {
        if (other == label) continue;
        final index = text.indexOf(other, from);
        if (index >= 0 && index < end) end = index;
      }
      return text.substring(from, end).trim();
    }

    return LayEffects(
      frequency: take(layFrequencyLabel),
      duration: take(layDurationLabel),
      impact: take(layImpactLabel),
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
    this.decisionId = '',
    this.ratingPercent,
    this.effectiveDate,
    this.reasonCategories = const [],
  });

  final String id;
  final String decisionDate;
  final String outcome;
  final String displayName;
  final String decisionId;
  final int? ratingPercent;
  final String? effectiveDate;
  final List<String> reasonCategories;

  static RecordedDecision fromIssue(
    String id,
    Map<String, dynamic> data, {
    required String decisionDate,
    String decisionId = '',
  }) {
    final rating = data['ratingPercent'];
    final effective = data['effectiveDate'];
    return RecordedDecision(
      id: id,
      decisionDate: decisionDate,
      decisionId: decisionId,
      outcome: data['outcome'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      ratingPercent: rating is int ? rating : null,
      effectiveDate: effective is String && effective.isNotEmpty
          ? effective
          : null,
      reasonCategories: reasonCategoriesFrom(data['reasons']),
    );
  }
}

List<String> reasonCategoriesFrom(Object? raw) {
  if (raw is! List) return const [];
  final categories = <String>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final category = item['category'];
    if (category is String && category.isNotEmpty) categories.add(category);
  }
  return categories;
}
