import 'claim_issue.dart';

/// The paragraph that fills "how this disability relates to an event, exposure,
/// or injury" when the Veteran has not reviewed an AI draft. Built only from
/// the connection notes and the in-service or nexus evidence already saved.
/// Empty when none of that exists. Mirrors `assembleDisabilityExplanation` in
/// `functions/form_sections.js`.
String disabilityExplanation({
  required List<ClaimTheory> theories,
  required List<EvidenceLink> links,
}) {
  final parts = <String>[];
  for (final theory in theories) {
    final summary = theory.summary.trim();
    if (summary.isEmpty) continue;
    final label = connectionTypes[theory.type];
    parts.add(label == null ? summary : '$label. $summary');
  }
  for (final link in links) {
    if (link.evidenceType != 'inServiceEvent' &&
        link.evidenceType != 'nexus') {
      continue;
    }
    final summary = link.summary.trim();
    if (summary.isNotEmpty) parts.add(summary);
  }
  return parts.join(' ');
}
