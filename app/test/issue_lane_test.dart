import 'package:app/claim/claim_file_sections.dart';
import 'package:app/claim/issue_lane.dart';
import 'package:flutter_test/flutter_test.dart';

LaneDecision decided({
  String outcome = 'denied',
  String date = '2026-06-01',
  List<String> reasons = const [],
  String name = 'Knee',
}) {
  return LaneDecision(
    decisionId: 'd1',
    decisionIssueId: 'di1',
    outcome: outcome,
    decisionDate: date,
    displayName: name,
    reasonCategories: reasons,
  );
}

LaneAnswers decidedAnswers(LaneAnswers answers) {
  if (answers.origin.isNotEmpty) return answers;
  return answers.copyWith(origin: 'decided');
}

IssueLaneResult lane({
  LaneDecision? decision,
  LaneAnswers answers = LaneAnswers.empty,
  Set<String> theories = const {},
  DateTime? today,
  String? boardDocket,
}) {
  return resolveIssueLane(
    issueId: 'knee',
    displayName: 'Knee',
    decision: decision,
    answers: decision == null ? answers : decidedAnswers(answers),
    theoryTypes: theories,
    today: today ?? DateTime.utc(2026, 10, 12),
    boardDocket: boardDocket,
  );
}

const pursuedNew = LaneAnswers(
  origin: 'new',
  pursue: true,
  pursueAnswered: true,
);

void main() {
  test('an unanswered condition prepares nothing', () {
    final result = lane();
    expect(result.filing, IssueFiling.needsAnswer);
    expect(result.packet, isNull);
    expect(result.needsNexus, isFalse);
  });

  test('a pursued new condition is a new claim', () {
    final result = lane(answers: pursuedNew);
    expect(result.filing, IssueFiling.newClaim);
    expect(result.packet, ClaimPacket.newClaim);
    expect(result.needsNexus, isTrue);
    expect(result.nexusKind, 'direct');
  });

  test('a new condition that is not pursued prepares nothing', () {
    final result = lane(
      answers: const LaneAnswers(
        origin: 'new',
        pursue: false,
        pursueAnswered: true,
      ),
    );
    expect(result.packet, isNull);
    expect(result.needsNexus, isFalse);
    expect(result.label, 'Not pursuing this');
  });

  test('a presumptive theory does not need a nexus letter', () {
    final result = lane(answers: pursuedNew, theories: {'presumptive'});
    expect(result.needsNexus, isFalse);
  });

  test('an increase-only theory does not need a nexus letter', () {
    final result = lane(answers: pursuedNew, theories: {'increase'});
    expect(result.needsNexus, isFalse);
    expect(result.nexusKind, isEmpty);
  });

  test('a secondary theory links to the other condition', () {
    final result = lane(answers: pursuedNew, theories: {'secondary'});
    expect(result.nexusKind, 'secondary');
  });

  test('a denied condition cannot become an increase', () {
    final result = lane(
      decision: decided(),
      answers: const LaneAnswers(choice: 'worse'),
    );
    expect(result.filing, isNot(IssueFiling.increase));
  });

  test('a service-connected condition that got worse is an increase', () {
    final result = lane(
      decision: decided(outcome: 'granted'),
      answers: const LaneAnswers(choice: 'worse'),
    );
    expect(result.filing, IssueFiling.increase);
    expect(result.packet, ClaimPacket.newClaim);
    expect(result.needsNexus, isFalse);
  });

  test('a deferred decision stays pending', () {
    final result = lane(decision: decided(outcome: 'deferred'));
    expect(result.filing, IssueFiling.pending);
    expect(result.packet, isNull);
  });

  test('new evidence inside the year is a Supplemental Claim', () {
    final result = lane(
      decision: decided(reasons: ['nexus']),
      answers: const LaneAnswers(choice: 'disagree', hasNewEvidence: true),
    );
    expect(result.filing, IssueFiling.supplemental);
    expect(result.needsNexus, isTrue);
    expect(result.nexusKind, 'supplemental');
  });

  test('a change in law is a Supplemental Claim without a nexus letter', () {
    final result = lane(
      decision: decided(date: '2020-01-01', reasons: ['nexus']),
      answers: const LaneAnswers(choice: 'disagree', lawChanged: true),
    );
    expect(result.filing, IssueFiling.supplemental);
    expect(result.needsNexus, isFalse);
  });

  test('a 995 nexus is omitted unless the reason was the medical link', () {
    final result = lane(
      decision: decided(reasons: ['diagnosis']),
      answers: const LaneAnswers(choice: 'disagree', hasNewEvidence: true),
    );
    expect(result.filing, IssueFiling.supplemental);
    expect(result.needsNexus, isFalse);
  });

  test('nothing new inside the year is a Higher-Level Review', () {
    final result = lane(
      decision: decided(),
      answers: const LaneAnswers(choice: 'disagree', againPath: 'higherLevel'),
    );
    expect(result.withinYear, isTrue);
    expect(result.filing, IssueFiling.higherLevel);
    expect(result.acceptsEvidence, isFalse);
  });

  test('the one-year cutoff hides Higher-Level Review and Board', () {
    final answers = const LaneAnswers(
      choice: 'disagree',
      againPath: 'higherLevel',
    );
    final old = lane(
      decision: decided(date: '2024-01-01'),
      answers: answers,
    );
    expect(old.withinYear, isFalse);
    expect(old.filing, IssueFiling.leave);
    expect(old.packet, isNull);

    final board = lane(
      decision: decided(date: '2024-01-01'),
      answers: const LaneAnswers(choice: 'disagree', againPath: 'board'),
    );
    expect(board.filing, IssueFiling.leave);
  });

  test('Board direct takes no nexus letter', () {
    final result = lane(
      decision: decided(reasons: ['nexus']),
      answers: const LaneAnswers(choice: 'disagree', againPath: 'board'),
      boardDocket: 'direct',
    );
    expect(result.filing, IssueFiling.board);
    expect(result.needsNexus, isFalse);
    expect(result.acceptsEvidence, isFalse);
  });

  test('Board evidence can take a nexus letter', () {
    final result = lane(
      decision: decided(reasons: ['nexus']),
      answers: const LaneAnswers(choice: 'disagree', againPath: 'board'),
      boardDocket: 'evidence',
    );
    expect(result.needsNexus, isTrue);
    expect(result.acceptsEvidence, isTrue);
  });

  test('a shared file is not listed under Higher-Level Review', () {
    expect(
      documentListedIn(
        documentPacket: 'shared',
        section: ClaimPacket.higherLevel,
        sectionAcceptsEvidence: false,
      ),
      isFalse,
    );
    expect(
      documentListedIn(
        documentPacket: 'shared',
        section: ClaimPacket.supplemental,
        sectionAcceptsEvidence: true,
      ),
      isTrue,
    );
    expect(
      documentListedIn(
        documentPacket: 'record',
        section: ClaimPacket.record,
        sectionAcceptsEvidence: false,
      ),
      isTrue,
    );
  });

  test('a matching denied name opens the existing condition', () {
    expect(
      matchingClaimIssueId(
        name: ' knee ',
        decided: [
          (conditionId: 'knee', displayName: 'Knee', outcome: 'denied'),
        ],
      ),
      'knee',
    );
    expect(
      matchingClaimIssueId(
        name: 'Knee',
        decided: [
          (conditionId: 'knee', displayName: 'Knee', outcome: 'granted'),
        ],
      ),
      isNull,
    );
  });

  test('an earlier claim shows new claims and supplemental claim', () {
    final sections = claimFileSections(
      earlierClaim: true,
      lanes: const [],
      documents: const [],
    );
    expect(sections.map((section) => section.packet), [
      ClaimPacket.newClaim,
      ClaimPacket.supplemental,
    ]);
    expect(sections.every((section) => section.showDropTarget), isTrue);
  });

  test('a first claim does not add an empty supplemental section', () {
    final sections = claimFileSections(
      earlierClaim: false,
      lanes: const [],
      documents: const [],
    );
    expect(sections.map((section) => section.packet), [ClaimPacket.newClaim]);
    expect(sections.single.showDropTarget, isTrue);
  });
}
