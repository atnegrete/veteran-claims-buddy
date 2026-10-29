import 'package:app/claim/claim_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a secondary path is not limited to this claim', () {
    expect(connectionTypes['secondary'], 'Connected to another condition');
    final theory = ClaimTheory.fromData('t1', {
      'type': 'secondary',
      'summary': 'Left knee',
      'relatedConditionName': 'Left knee',
    });
    expect(theory.relatedConditionName, 'Left knee');
  });

  test(
    'lay effects assemble and reopen as frequency, duration, and impact',
    () {
      final body = const LayEffects(
        frequency: 'Most days',
        duration: 'A few hours',
        impact: 'I miss work',
      ).toBody();
      expect(body, contains('How often: Most days'));
      expect(body, contains('How long: A few hours'));
      expect(body, contains('What it keeps you from doing: I miss work'));
      final parsed = LayEffects.fromBody(body);
      expect(parsed.frequency, 'Most days');
      expect(parsed.duration, 'A few hours');
      expect(parsed.impact, 'I miss work');
    },
  );

  test('a leftover statement opens as impact', () {
    final parsed = LayEffects.fromBody('My back keeps me from lifting.');
    expect(parsed.frequency, isEmpty);
    expect(parsed.duration, isEmpty);
    expect(parsed.impact, 'My back keeps me from lifting.');
  });

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
          conditionId: 'back',
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
