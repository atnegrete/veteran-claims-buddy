import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/disability_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins a connection note and in-service evidence', () {
    final text = disabilityExplanation(
      theories: const [
        ClaimTheory(
          id: 't1',
          type: 'direct',
          summary: 'Twisted it on a run.',
        ),
      ],
      links: const [
        EvidenceLink(
          id: 'l1',
          conditionId: 'knee',
          evidenceType: 'inServiceEvent',
          relationship: 'supports',
          summary: 'The run was during training.',
        ),
        EvidenceLink(
          id: 'l2',
          conditionId: 'knee',
          evidenceType: 'severity',
          relationship: 'supports',
          summary: 'This note is not used.',
        ),
      ],
    );
    expect(
      text,
      'Directly from service. Twisted it on a run. The run was during training.',
    );
  });

  test('is empty when nothing was recorded', () {
    expect(
      disabilityExplanation(
        theories: const [
          ClaimTheory(id: 't1', type: 'direct', summary: '  '),
        ],
        links: const [],
      ),
      isEmpty,
    );
  });
}
