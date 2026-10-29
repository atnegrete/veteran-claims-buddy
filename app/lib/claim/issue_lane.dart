import 'claim_decision.dart';
import 'claim_sections.dart';

/// The filing a condition is prepared for. One condition is in one filing.
enum IssueFiling {
  newClaim,
  increase,
  supplemental,
  higherLevel,
  board,
  pending,
  leave,
  needsAnswer,
}

/// Where a document or a package form is grouped.
enum ClaimPacket { newClaim, supplemental, higherLevel, board, record, shared }

const claimPacketNames = <ClaimPacket, String>{
  ClaimPacket.newClaim: 'newClaim',
  ClaimPacket.supplemental: 'supplemental',
  ClaimPacket.higherLevel: 'higherLevel',
  ClaimPacket.board: 'board',
  ClaimPacket.record: 'record',
  ClaimPacket.shared: 'shared',
};

const claimPacketLabels = <ClaimPacket, String>{
  ClaimPacket.newClaim: 'New claims',
  ClaimPacket.supplemental: 'Supplemental Claim',
  ClaimPacket.higherLevel: 'Higher-Level Review',
  ClaimPacket.board: 'Board Appeal',
  ClaimPacket.record: 'Records',
  ClaimPacket.shared: 'Both',
};

const filingLabels = <IssueFiling, String>{
  IssueFiling.newClaim: 'New claim',
  IssueFiling.increase: 'Increase',
  IssueFiling.supplemental: 'Supplemental Claim',
  IssueFiling.higherLevel: 'Higher-Level Review',
  IssueFiling.board: 'Board Appeal',
  IssueFiling.pending: 'The VA has not finished this',
  IssueFiling.leave: 'Leave this decision',
  IssueFiling.needsAnswer: 'Say what you want to do with this decision',
};

const serviceConnectedOutcomes = <String>{
  'granted',
  'increased',
  'continued',
  'reduced',
};

/// Answers saved on `conditions/{id}/lane/current`.
class LaneAnswers {
  const LaneAnswers({
    this.choice = '',
    this.againPath = '',
    this.hasNewEvidence = false,
    this.lawChanged = false,
    this.medicalLinkMissing = false,
    this.origin = '',
    this.pursue = false,
    this.pursueAnswered = false,
  });

  /// `leave`, `worse`, `disagree`, or empty.
  final String choice;

  /// `supplemental`, `higherLevel`, `board`, or empty.
  final String againPath;

  final bool hasNewEvidence;
  final bool lawChanged;
  final bool medicalLinkMissing;

  /// `new`, `decided`, or empty.
  final String origin;

  /// True when a new condition is being pursued. Ignored unless [origin] is `new`.
  final bool pursue;

  /// True after the pursue cards have been answered.
  final bool pursueAnswered;

  static const empty = LaneAnswers();

  static LaneAnswers fromData(Map<String, dynamic>? data) {
    if (data == null) return empty;
    return LaneAnswers(
      choice: data['choice'] as String? ?? '',
      againPath: data['againPath'] as String? ?? '',
      hasNewEvidence: data['hasNewEvidence'] == true,
      lawChanged: data['lawChanged'] == true,
      medicalLinkMissing: data['medicalLinkMissing'] == true,
      origin: data['origin'] as String? ?? '',
      pursue: data['pursue'] == true,
      pursueAnswered: data['pursueAnswered'] == true,
    );
  }

  LaneAnswers copyWith({
    String? choice,
    String? againPath,
    bool? hasNewEvidence,
    bool? lawChanged,
    bool? medicalLinkMissing,
    String? origin,
    bool? pursue,
    bool? pursueAnswered,
  }) {
    return LaneAnswers(
      choice: choice ?? this.choice,
      againPath: againPath ?? this.againPath,
      hasNewEvidence: hasNewEvidence ?? this.hasNewEvidence,
      lawChanged: lawChanged ?? this.lawChanged,
      medicalLinkMissing: medicalLinkMissing ?? this.medicalLinkMissing,
      origin: origin ?? this.origin,
      pursue: pursue ?? this.pursue,
      pursueAnswered: pursueAnswered ?? this.pursueAnswered,
    );
  }
}

/// The latest confirmed decision used to choose a filing.
class LaneDecision {
  const LaneDecision({
    required this.decisionId,
    required this.decisionIssueId,
    required this.outcome,
    required this.decisionDate,
    required this.displayName,
    this.reasonCategories = const [],
  });

  final String decisionId;
  final String decisionIssueId;
  final String outcome;
  final String decisionDate;
  final String displayName;
  final List<String> reasonCategories;
}

class IssueLaneResult {
  const IssueLaneResult({
    required this.issueId,
    required this.displayName,
    required this.filing,
    required this.packet,
    required this.withinYear,
    required this.reviewClosesOn,
    required this.needsNexus,
    required this.nexusKind,
    required this.label,
    this.decision,
    this.boardDocket,
  });

  final String issueId;
  final String displayName;
  final IssueFiling filing;

  /// Null when this condition is not in a filing yet.
  final ClaimPacket? packet;
  final bool withinYear;
  final String reviewClosesOn;
  final bool needsNexus;

  /// `direct`, `secondary`, `aggravation`, `supplemental`, or empty.
  final String nexusKind;
  final String label;
  final LaneDecision? decision;
  final String? boardDocket;

  bool get acceptsEvidence {
    if (packet == ClaimPacket.newClaim || packet == ClaimPacket.supplemental) {
      return true;
    }
    if (packet == ClaimPacket.board) {
      return boardDocket == 'evidence' || boardDocket == 'hearing';
    }
    return false;
  }
}

/// True through the anniversary of the decision date.
bool decisionWithinReviewYear(String decisionDate, DateTime today) {
  final closes = oneYearAfterDecision(decisionDate);
  if (closes.isEmpty) return false;
  final iso = isoDate(today);
  return iso.compareTo(closes) <= 0;
}

String isoDate(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

ClaimPacket? packetForFiling(IssueFiling filing) {
  return switch (filing) {
    IssueFiling.newClaim || IssueFiling.increase => ClaimPacket.newClaim,
    IssueFiling.supplemental => ClaimPacket.supplemental,
    IssueFiling.higherLevel => ClaimPacket.higherLevel,
    IssueFiling.board => ClaimPacket.board,
    IssueFiling.pending || IssueFiling.leave || IssueFiling.needsAnswer => null,
  };
}

/// A new claim needs a doctor's draft unless the only theory is presumptive.
({bool needs, String kind}) nexusForTheories(Set<String> theoryTypes) {
  final types = theoryTypes.where((type) => type != 'increase').toSet();
  if (types.isEmpty) {
    if (theoryTypes.contains('increase')) return (needs: false, kind: '');
    return (needs: true, kind: 'direct');
  }
  if (types.length == 1 && types.contains('presumptive')) {
    return (needs: false, kind: '');
  }
  if (types.contains('secondary')) return (needs: true, kind: 'secondary');
  if (types.contains('aggravation')) return (needs: true, kind: 'aggravation');
  if (types.contains('direct')) return (needs: true, kind: 'direct');
  return (needs: false, kind: '');
}

bool supplementalNeedsNexus({
  required List<String> reasonCategories,
  required LaneAnswers answers,
}) {
  if (answers.lawChanged) return false;
  if (reasonCategories.contains('nexus')) return true;
  if (reasonCategories.isEmpty && answers.medicalLinkMissing) return true;
  return false;
}

String nexusMultiplicityKey({
  required String issueId,
  required String nexusKind,
}) {
  final prefix = nexusKind == 'supplemental' ? '995' : '526';
  return '$prefix:$issueId';
}

/// The filing for one condition. [boardDocket] comes from a started Board draft.
IssueLaneResult resolveIssueLane({
  required String issueId,
  required String displayName,
  required LaneDecision? decision,
  required LaneAnswers answers,
  required Set<String> theoryTypes,
  required DateTime today,
  String? boardDocket,
}) {
  if (answers.origin != 'new' && answers.origin != 'decided') {
    return IssueLaneResult(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.needsAnswer,
      packet: null,
      withinYear: false,
      reviewClosesOn: '',
      needsNexus: false,
      nexusKind: '',
      label: 'Choose whether this is new or already decided',
    );
  }
  if (answers.origin == 'new') {
    if (!answers.pursueAnswered) {
      return IssueLaneResult(
        issueId: issueId,
        displayName: displayName,
        filing: IssueFiling.needsAnswer,
        packet: null,
        withinYear: false,
        reviewClosesOn: '',
        needsNexus: false,
        nexusKind: '',
        label: 'Say whether to pursue this condition',
      );
    }
    if (!answers.pursue) {
      return IssueLaneResult(
        issueId: issueId,
        displayName: displayName,
        filing: IssueFiling.leave,
        packet: null,
        withinYear: false,
        reviewClosesOn: '',
        needsNexus: false,
        nexusKind: '',
        label: 'Not pursuing this',
      );
    }
    final nexus = nexusForTheories(theoryTypes);
    return IssueLaneResult(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.newClaim,
      packet: ClaimPacket.newClaim,
      withinYear: false,
      reviewClosesOn: '',
      needsNexus: nexus.needs,
      nexusKind: nexus.kind,
      label: filingLabels[IssueFiling.newClaim]!,
    );
  }
  if (decision == null) {
    return IssueLaneResult(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.needsAnswer,
      packet: null,
      withinYear: false,
      reviewClosesOn: '',
      needsNexus: false,
      nexusKind: '',
      label: 'Record the decision you already received',
    );
  }
  final within = decisionWithinReviewYear(decision.decisionDate, today);
  final closes = oneYearAfterDecision(decision.decisionDate);
  if (decision.outcome == 'deferred') {
    return IssueLaneResult(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.pending,
      packet: null,
      withinYear: within,
      reviewClosesOn: closes,
      needsNexus: false,
      nexusKind: '',
      label: filingLabels[IssueFiling.pending]!,
      decision: decision,
    );
  }
  final connected = serviceConnectedOutcomes.contains(decision.outcome);
  if (answers.choice == 'worse' && connected) {
    return _result(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.increase,
      within: within,
      closes: closes,
      decision: decision,
      needsNexus: false,
      nexusKind: '',
    );
  }
  if (answers.choice != 'disagree') {
    final filing = answers.choice == 'leave'
        ? IssueFiling.leave
        : IssueFiling.needsAnswer;
    return _result(
      issueId: issueId,
      displayName: displayName,
      filing: filing,
      within: within,
      closes: closes,
      decision: decision,
      needsNexus: false,
      nexusKind: '',
    );
  }
  if (answers.againPath == 'higherLevel' &&
      within &&
      !answers.hasNewEvidence &&
      !answers.lawChanged) {
    return _result(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.higherLevel,
      within: within,
      closes: closes,
      decision: decision,
      needsNexus: false,
      nexusKind: '',
    );
  }
  if (answers.againPath == 'board' && within && !answers.lawChanged) {
    final needs =
        (boardDocket == 'evidence' || boardDocket == 'hearing') &&
        supplementalNeedsNexus(
          reasonCategories: decision.reasonCategories,
          answers: answers,
        );
    return _result(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.board,
      within: within,
      closes: closes,
      decision: decision,
      needsNexus: needs,
      nexusKind: needs ? 'supplemental' : '',
      boardDocket: boardDocket,
    );
  }
  final wantsSupplemental =
      answers.lawChanged ||
      answers.hasNewEvidence ||
      answers.againPath == 'supplemental';
  if (wantsSupplemental) {
    final needs = supplementalNeedsNexus(
      reasonCategories: decision.reasonCategories,
      answers: answers,
    );
    return _result(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.supplemental,
      within: within,
      closes: closes,
      decision: decision,
      needsNexus: needs,
      nexusKind: needs ? 'supplemental' : '',
    );
  }
  if (!within) {
    return _result(
      issueId: issueId,
      displayName: displayName,
      filing: IssueFiling.leave,
      within: within,
      closes: closes,
      decision: decision,
      needsNexus: false,
      nexusKind: '',
      label:
          'The year to ask for a Higher-Level Review or a Board Appeal ended on $closes',
    );
  }
  return _result(
    issueId: issueId,
    displayName: displayName,
    filing: IssueFiling.needsAnswer,
    within: within,
    closes: closes,
    decision: decision,
    needsNexus: false,
    nexusKind: '',
  );
}

IssueLaneResult _result({
  required String issueId,
  required String displayName,
  required IssueFiling filing,
  required bool within,
  required String closes,
  required LaneDecision decision,
  required bool needsNexus,
  required String nexusKind,
  String? label,
  String? boardDocket,
}) {
  return IssueLaneResult(
    issueId: issueId,
    displayName: displayName,
    filing: filing,
    packet: packetForFiling(filing),
    withinYear: within,
    reviewClosesOn: closes,
    needsNexus: needsNexus,
    nexusKind: nexusKind,
    label: label ?? filingLabels[filing]!,
    decision: decision,
    boardDocket: boardDocket,
  );
}

/// The claim-issue id to open, when the match is a condition already on the claim.
String? matchingClaimIssueId({
  required String name,
  required List<({String conditionId, String displayName, String outcome})>
  decided,
}) {
  final key = name.trim().toLowerCase();
  if (key.isEmpty) return null;
  for (final item in decided) {
    if (item.displayName.trim().toLowerCase() != key) continue;
    if (item.outcome != 'denied' && item.outcome != 'reduced') continue;
    if (item.conditionId.isEmpty) continue;
    return item.conditionId;
  }
  return null;
}

/// Whether the new-or-decided step has an answer that can prepare forms.
ClaimSectionStatus pursueStepStatus(LaneAnswers answers, {int decisions = 0}) {
  if (answers.origin.isEmpty) return ClaimSectionStatus.notStarted;
  if (answers.origin == 'new') {
    return answers.pursueAnswered
        ? ClaimSectionStatus.done
        : ClaimSectionStatus.inProgress;
  }
  if (decisions == 0) return ClaimSectionStatus.inProgress;
  if (answers.choice == 'leave' || answers.choice == 'worse') {
    return ClaimSectionStatus.done;
  }
  if (answers.choice == 'disagree' &&
      (answers.hasNewEvidence ||
          answers.lawChanged ||
          answers.againPath.isNotEmpty)) {
    return ClaimSectionStatus.done;
  }
  return ClaimSectionStatus.inProgress;
}

String? claimPacketFromName(String? value) {
  if (value == null || value.isEmpty) return null;
  for (final entry in claimPacketNames.entries) {
    if (entry.value == value) return entry.value;
  }
  return null;
}

/// A missing stored packet. A decision letter or DD214 is a record.
String packetNameForDocument({
  required String? stored,
  required String documentType,
}) {
  final known = claimPacketFromName(stored);
  if (known != null) return known;
  if (documentType == 'decisionLetter' || documentType == 'dd214') {
    return 'record';
  }
  return 'newClaim';
}

bool documentListedIn({
  required String documentPacket,
  required ClaimPacket section,
  required bool sectionAcceptsEvidence,
}) {
  if (documentPacket == 'record') return section == ClaimPacket.record;
  if (documentPacket == 'shared') return sectionAcceptsEvidence;
  final sectionName = claimPacketNames[section];
  if (documentPacket != sectionName) return false;
  if (section == ClaimPacket.board || section == ClaimPacket.higherLevel) {
    return sectionAcceptsEvidence;
  }
  return true;
}

/// Packets that can take an uploaded file, in display order.
List<ClaimPacket> evidencePackets(Iterable<IssueLaneResult> lanes) {
  final packets = <ClaimPacket>[];
  for (final packet in const [
    ClaimPacket.newClaim,
    ClaimPacket.supplemental,
    ClaimPacket.board,
  ]) {
    if (lanes.any((lane) => lane.packet == packet && lane.acceptsEvidence)) {
      packets.add(packet);
    }
  }
  return packets;
}
