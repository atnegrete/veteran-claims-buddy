import 'package:app/claim/claim_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the evidence matrix lists what is missing and not a predicted outcome',
    () {
      final labels = [for (final row in directEvidenceMatrix) row.label];
      expect(labels, [
        'Current disability',
        'In-service event',
        'Relationship',
        'Current severity',
        'Functional impact',
      ]);
      for (final row in directEvidenceMatrix) {
        expect(row.detail, 'Not added yet');
        expect(row.detail.toLowerCase(), isNot(contains('chance')));
        expect(row.detail, isNot(contains('%')));
      }
      final filled = evidenceNeedsFor(const [
        EvidenceLink(
          id: 'note',
          claimIssueId: 'back',
          evidenceType: 'nexus',
          relationship: 'supports',
          summary: 'A lifting injury in service',
        ),
      ]);
      expect(
        filled.firstWhere((row) => row.type == 'nexus').detail,
        'A lifting injury in service',
      );
      expect(
        filled.firstWhere((row) => row.type == 'severity').detail,
        'Not added yet',
      );
    },
  );
}
