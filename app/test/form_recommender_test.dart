import 'package:app/claim/form_recommender.dart';
import 'package:app/claim/issue_lane.dart';
import 'package:app/forms/package_form.dart';
import 'package:flutter_test/flutter_test.dart';

FormRecommenderInput inputWith({
  bool? firstClaim,
  bool hasIssues = false,
  bool hasMentalHealthCondition = false,
  bool hasOpenReviewCandidate = false,
  bool? privateProvider,
  bool? unableToWork,
  bool? hasWitness,
  bool? filedIntentToFile,
  List<IssueLaneResult> lanes = const [],
}) {
  return FormRecommenderInput(
    caseId: 'case1',
    firstClaim: firstClaim,
    hasIssues: hasIssues,
    hasMentalHealthCondition: hasMentalHealthCondition,
    hasOpenReviewCandidate: hasOpenReviewCandidate,
    privateProvider: privateProvider,
    unableToWork: unableToWork,
    hasWitness: hasWitness,
    filedIntentToFile: filedIntentToFile,
    lanes: lanes,
  );
}

IssueLaneResult pursuedNewClaim() {
  return resolveIssueLane(
    issueId: 'back',
    displayName: 'Back',
    decision: null,
    answers: const LaneAnswers(
      origin: 'new',
      pursue: true,
      pursueAnswered: true,
    ),
    theoryTypes: const {'direct'},
    today: DateTime.utc(2026, 10, 12),
  );
}

FormSuggestion? byId(List<FormSuggestion> list, String id) {
  for (final suggestion in list) {
    if (suggestion.id == id) return suggestion;
  }
  return null;
}

void main() {
  group('recommendForms', () {
    test('a fresh first claim with issues recommends the core forms', () {
      final result = recommendForms(
        inputWith(
          firstClaim: true,
          hasIssues: true,
          lanes: [pursuedNewClaim()],
        ),
      );
      final recommendedIds = result.recommended.map((s) => s.id).toSet();
      expect(recommendedIds, contains('21-526EZ'));
      expect(recommendedIds, contains('21-0966'));
      expect(recommendedIds, contains('21-4138'));
      expect(recommendedIds, contains('21-10210'));
      expect(recommendedIds, contains('nexus-526-back'));
    });

    test('intent to file says to send it first, then softens once it is added', () {
      final result = recommendForms(
        inputWith(hasIssues: true, lanes: [pursuedNewClaim()]),
      );
      final suggestion = byId(result.recommended, '21-0966');
      expect(suggestion, isNotNull);
      expect(
        suggestion!.reason,
        'Send this to the VA before the other forms. If they grant your claim, pay can go back to the day they receive it.',
      );
      expect(
        formListReason(suggestion, 1),
        'In your package. Download it, sign it, and send it. The day the VA receives it is the day that counts.',
      );
    });

    test('intent to file moves to Other once the Veteran has one', () {
      final result = recommendForms(
        inputWith(
          hasIssues: true,
          filedIntentToFile: true,
          lanes: [pursuedNewClaim()],
        ),
      );
      expect(byId(result.recommended, '21-0966'), isNull);
      expect(byId(result.other, '21-0966'), isNotNull);
    });

    test('no pursued condition leaves the new-claim forms off', () {
      final result = recommendForms(inputWith(firstClaim: null));
      expect(byId(result.recommended, '21-526EZ'), isNull);
      expect(byId(result.other, '21-526EZ'), isNull);
      expect(byId(result.recommended, 'nexus-526'), isNull);
      expect(byId(result.recommended, '21-0966'), isNull);
      expect(byId(result.recommended, '21-4138'), isNull);
      expect(byId(result.other, '20-10206'), isNotNull);
    });

    test('a mental-health condition recommends 21-0781', () {
      final yes = recommendForms(
        inputWith(
          hasIssues: true,
          hasMentalHealthCondition: true,
          lanes: [pursuedNewClaim()],
        ),
      );
      expect(byId(yes.recommended, '21-0781'), isNotNull);

      final no = recommendForms(
        inputWith(hasIssues: true, lanes: [pursuedNewClaim()]),
      );
      expect(byId(no.recommended, '21-0781'), isNull);
      expect(byId(no.other, '21-0781'), isNotNull);
    });

    test('gap answers move records release, IU, and buddy statement', () {
      final result = recommendForms(
        inputWith(
          hasIssues: true,
          privateProvider: true,
          unableToWork: true,
          hasWitness: true,
          lanes: [pursuedNewClaim()],
        ),
      );
      expect(byId(result.recommended, '21-4142'), isNotNull);
      expect(byId(result.recommended, '21-8940'), isNotNull);
      expect(byId(result.recommended, '21-10210'), isNotNull);
    });

    test('unanswered gaps leave records release and IU in Other', () {
      final result = recommendForms(
        inputWith(hasIssues: true, lanes: [pursuedNewClaim()]),
      );
      expect(byId(result.other, '21-4142'), isNotNull);
      expect(byId(result.other, '21-8940'), isNotNull);
      expect(byId(result.recommended, '21-10210'), isNotNull);
    });

    test('review forms stay off until a condition chooses that filing', () {
      final none = recommendForms(
        inputWith(hasIssues: true, lanes: [pursuedNewClaim()]),
      );
      expect(byId(none.recommended, '20-0995'), isNull);
      expect(byId(none.other, '20-0995'), isNull);
      expect(byId(none.recommended, '20-0996'), isNull);
      expect(byId(none.recommended, '10182'), isNull);
      expect(byId(none.other, '20-10206')!.isOpen, isFalse);
      expect(byId(none.recommended, '21-0966')!.packet, FormPacket.newClaim);
    });

    test('a mixed claim keeps new claims and a Supplemental Claim apart', () {
      final result = recommendForms(
        inputWith(
          hasIssues: true,
          lanes: [
            resolveIssueLane(
              issueId: 'back',
              displayName: 'Back',
              decision: null,
              answers: const LaneAnswers(
                origin: 'new',
                pursue: true,
                pursueAnswered: true,
              ),
              theoryTypes: const {'direct'},
              today: DateTime.utc(2026, 10, 12),
            ),
            resolveIssueLane(
              issueId: 'knee',
              displayName: 'Knee',
              decision: const LaneDecision(
                decisionId: 'd1',
                decisionIssueId: 'di1',
                outcome: 'denied',
                decisionDate: '2026-06-01',
                displayName: 'Knee',
                reasonCategories: ['nexus'],
              ),
              answers: const LaneAnswers(
                origin: 'decided',
                choice: 'disagree',
                hasNewEvidence: true,
              ),
              theoryTypes: const {},
              today: DateTime.utc(2026, 10, 12),
            ),
          ],
        ),
      );
      expect(byId(result.recommended, '21-526EZ')!.packet, FormPacket.newClaim);
      expect(byId(result.recommended, '21-0966'), isNotNull);
      expect(byId(result.recommended, '20-0995')!.packet, FormPacket.supplemental);
      expect(byId(result.recommended, 'nexus-995-knee'), isNotNull);
      expect(byId(result.recommended, 'nexus-526-back'), isNotNull);
      final statements = result.recommended
          .where((row) => row.id == '21-4138')
          .map((row) => row.packet)
          .toSet();
      expect(statements, {FormPacket.newClaim, FormPacket.supplemental});
    });

    test('Intent to File stays out of a Supplemental Claim only filing', () {
      final result = recommendForms(
        inputWith(
          lanes: [
            resolveIssueLane(
              issueId: 'knee',
              displayName: 'Knee',
              decision: const LaneDecision(
                decisionId: 'd1',
                decisionIssueId: 'di1',
                outcome: 'denied',
                decisionDate: '2026-06-01',
                displayName: 'Knee',
                reasonCategories: ['diagnosis'],
              ),
              answers: const LaneAnswers(
                origin: 'decided',
                choice: 'disagree',
                hasNewEvidence: true,
              ),
              theoryTypes: const {},
              today: DateTime.utc(2026, 10, 12),
            ),
          ],
        ),
      );
      expect(byId(result.recommended, '21-0966'), isNull);
      expect(byId(result.other, '21-0966'), isNull);
      expect(byId(result.recommended, '20-0995'), isNotNull);
      expect(byId(result.recommended, 'nexus-995-knee'), isNull);
    });

    test('Higher-Level Review lists the form and no nexus letter', () {
      final result = recommendForms(
        inputWith(
          lanes: [
            resolveIssueLane(
              issueId: 'knee',
              displayName: 'Knee',
              decision: const LaneDecision(
                decisionId: 'd1',
                decisionIssueId: 'di1',
                outcome: 'denied',
                decisionDate: '2026-06-01',
                displayName: 'Knee',
              ),
              answers: const LaneAnswers(
                origin: 'decided',
                choice: 'disagree',
                againPath: 'higherLevel',
              ),
              theoryTypes: const {},
              today: DateTime.utc(2026, 10, 12),
            ),
          ],
        ),
      );
      expect(byId(result.recommended, '20-0996')!.packet, FormPacket.higherLevel);
      expect(
        result.recommended.where((row) => row.kind == SuggestionKind.evidence),
        isEmpty,
      );
    });

    test('added copies wear a count on the badge', () {
      expect(addedCountLabel(0), isNull);
      expect(addedCountLabel(1), 'Added (1)');
      expect(addedCountLabel(2), 'Added (2)');

      PackageForm copy(String formNumber) {
        return PackageForm(
          id: formNumber,
          caseId: 'case1',
          formNumber: formNumber,
          status: PackageFormStatus.draft,
          multiplicityKey: '',
          displayLabel: '',
          answers: const {},
          sectionDrafts: const {},
          statementStatus: StatementStatus.none,
        );
      }

      final intent = const FormSuggestion(
        id: '21-0966',
        title: 'Intent to File',
        reason: 'Protects the date.',
        track: FormTrack.recommended,
        kind: SuggestionKind.form,
        formNumber: '21-0966',
      );
      final buddy = const FormSuggestion(
        id: '21-10210',
        title: 'Buddy statement',
        reason: 'Someone who saw it.',
        track: FormTrack.recommended,
        kind: SuggestionKind.form,
        formNumber: '21-10210',
      );
      final forms = [copy('21-0966'), copy('21-10210'), copy('21-10210')];
      expect(addedCount(forms, intent), 1);
      expect(addedCount(forms, buddy), 2);
    });

    test('unpursued forms stay in Other Common Forms', () {
      final result = recommendForms(inputWith(firstClaim: null));
      final common = otherCommonForms(result).map((row) => row.id);
      expect(common, contains('20-10206'));
      expect(common, isNot(contains('21-526EZ')));
      expect(
        filingFormSuggestions(result, FormPacket.newClaim),
        isEmpty,
      );
    });

    test('a nexus letter is evidence, never a form number', () {
      final result = recommendForms(
        inputWith(hasIssues: true, lanes: [pursuedNewClaim()]),
      );
      final nexus = byId(result.recommended, 'nexus-526-back')!;
      expect(nexus.kind, SuggestionKind.evidence);
      expect(nexus.formNumber, isNull);
    });
  });
}
