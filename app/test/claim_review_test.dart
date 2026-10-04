import 'package:app/claim/claim_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const denied = ReviewCandidate(
    decisionId: 'decision-1',
    decisionIssueId: 'issue-1',
    claimIssueId: 'claim-1',
    displayName: 'Hearing loss',
    outcome: 'denied',
    decisionDate: '2026-01-15',
  );

  test('a granted issue cannot start a review', () {
    expect(reviewOutcomeEligible('denied'), isTrue);
    expect(reviewOutcomeEligible('deferred'), isTrue);
    expect(reviewOutcomeEligible('reduced'), isTrue);
    expect(reviewOutcomeEligible('other'), isTrue);
    expect(reviewOutcomeEligible('granted'), isFalse);
    expect(reviewOutcomeEligible('increased'), isFalse);
    expect(reviewOutcomeEligible('continued'), isFalse);
  });

  test('a supplemental draft needs an eligible issue and no extra choices', () {
    expect(
      reviewDraftError(
        path: ReviewPath.supplemental,
        issue: denied,
        boardDocket: null,
        informalConference: null,
      ),
      isNull,
    );
    expect(
      reviewDraftError(
        path: ReviewPath.supplemental,
        issue: null,
        boardDocket: null,
        informalConference: null,
      ),
      'Choose an issue from a confirmed decision.',
    );
    expect(
      reviewDraftError(
        path: ReviewPath.board,
        issue: denied,
        boardDocket: 'hearing',
        informalConference: null,
      ),
      isNull,
    );
    expect(
      reviewDraftError(
        path: ReviewPath.higherLevel,
        issue: denied,
        boardDocket: null,
        informalConference: false,
      ),
      isNull,
    );
  });

  test('only a draft review is read back', () {
    final review = ClaimReview.fromData('review-1', {
      'status': 'draft',
      'type': 'boardAppeal',
      'formIds': ['10182'],
      'caseId': 'case-1',
      'decisionId': 'decision-1',
      'decisionIssueId': 'issue-1',
      'claimIssueId': 'claim-1',
      'displayName': 'Hearing loss',
      'boardDocket': 'direct',
      'informalConference': null,
    });
    expect(review?.formId, '10182');
    expect(review?.boardDocket, 'direct');
    expect(
      ClaimReview.fromData('review-2', {
        'status': 'submitted',
        'type': 'supplementalClaim',
      }),
      isNull,
    );
  });
}
