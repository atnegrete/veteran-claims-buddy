import 'package:app/claim/claim_issue.dart';
import 'package:app/screens/shell/connection_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only an aggravation path keeps the before-service note', () {
    const theories = [
      ClaimTheory(id: 'direct', type: 'direct', summary: 'Fell on a ruck.'),
      ClaimTheory(
        id: 'secondary',
        type: 'secondary',
        summary: 'Left knee',
        relatedConditionName: 'Left knee',
      ),
      ClaimTheory(id: 'worse', type: 'aggravation', summary: 'Night marches'),
    ];
    const links = [
      EvidenceLink(
        id: 'before',
        conditionId: 'back',
        evidenceType: 'inServiceEvent',
        relationship: 'supports',
        summary: 'A sore back from high school.',
      ),
      EvidenceLink(
        id: 'old-diagnosis',
        conditionId: 'back',
        evidenceType: 'currentDiagnosis',
        relationship: 'supports',
        summary: 'Lumbar strain',
      ),
    ];
    final grouped = pairConnectionNotes(theories: theories, links: links);
    expect(grouped.paired, hasLength(3));
    expect(grouped.paired[0].links, isEmpty);
    expect(grouped.paired[1].links, isEmpty);
    expect(
      grouped.paired[2].links.single.summary,
      'A sore back from high school.',
    );
    expect(grouped.leftOver.single.evidenceType, 'currentDiagnosis');
  });
}
