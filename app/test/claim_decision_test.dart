import 'package:flutter_test/flutter_test.dart';

import 'package:app/claim/claim_decision.dart';

void main() {
  test('a letter stays off the claim until it is confirmed', () {
    expect(decisionOnClaim('needsReview'), isFalse);
    expect(decisionOnClaim('confirmed'), isTrue);
  });

  test('one year after the decision date is the deadline shown', () {
    expect(oneYearAfterDecision('2026-03-01'), '2027-03-01');
    expect(oneYearAfterDecision('March'), '');
  });

  test('confirm requires a real date and a condition', () {
    expect(
      decisionConfirmError(
        decisionDate: '2026-03-01',
        receivedDate: '',
        summary: 'Service connection for tinnitus is granted.',
        issues: [
          (
            name: 'Tinnitus',
            outcome: 'granted',
            rating: 10,
            effectiveDate: '2025-01-01',
            findings: ['Noise exposure is conceded.'],
            reasons: [(text: 'The exam linked it.', category: 'nexus')],
          ),
        ],
      ),
      isNull,
    );
    expect(
      decisionConfirmError(
        decisionDate: '2026-03-01',
        receivedDate: '',
        summary: '',
        issues: const [],
      ),
      'This letter has no condition to confirm.',
    );
    expect(
      decisionConfirmError(
        decisionDate: '2026-03-01',
        receivedDate: '',
        summary: '',
        issues: [
          (
            name: 'Knee',
            outcome: 'granted',
            rating: 15,
            effectiveDate: '',
            findings: const <String>[],
            reasons: const <({String text, String category})>[],
          ),
        ],
      ),
      'Choose a rating from the list.',
    );
  });
}
