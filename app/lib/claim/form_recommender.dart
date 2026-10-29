import '../auth/auth_redirect.dart';
import '../forms/form_catalog.dart';
import '../forms/package_form.dart';
import 'claim_review.dart';
import 'issue_lane.dart';

/// Which filing a Forms row belongs to. [side] is not sent as its own filing.
enum FormPacket { newClaim, supplemental, higherLevel, board, side }

FormPacket formPacketFor(ClaimPacket? packet) {
  return switch (packet) {
    ClaimPacket.supplemental => FormPacket.supplemental,
    ClaimPacket.higherLevel => FormPacket.higherLevel,
    ClaimPacket.board => FormPacket.board,
    ClaimPacket.newClaim ||
    ClaimPacket.record ||
    ClaimPacket.shared ||
    null => FormPacket.newClaim,
  };
}

/// The Forms heading for unrecommended new-claim forms and side forms.
const otherCommonFormsTitle = 'Other Common Forms';

const formPacketLabels = <FormPacket, String>{
  FormPacket.newClaim: 'New claims',
  FormPacket.supplemental: 'Supplemental Claim',
  FormPacket.higherLevel: 'Higher-Level Review',
  FormPacket.board: 'Board Appeal',
  FormPacket.side: otherCommonFormsTitle,
};

const formPacketOrder = <FormPacket>[
  FormPacket.newClaim,
  FormPacket.supplemental,
  FormPacket.higherLevel,
  FormPacket.board,
  FormPacket.side,
];

String formPacketName(FormPacket packet) {
  return switch (packet) {
    FormPacket.newClaim => 'newClaim',
    FormPacket.supplemental => 'supplemental',
    FormPacket.higherLevel => 'higherLevel',
    FormPacket.board => 'board',
    FormPacket.side => 'side',
  };
}

/// Which section a suggestion belongs in on the Forms page.
enum FormTrack { recommended, other }

/// A form the app can prepare, or a piece of evidence like a nexus letter.
enum SuggestionKind { form, evidence }

/// One row on the Forms page. The recommendation is deterministic: it is
/// calculated from the claim and a few intake answers, never chosen by a model
/// (handoff 1.6). [route] is non-null only when the Veteran can act on it here.
class FormSuggestion {
  const FormSuggestion({
    required this.id,
    required this.title,
    required this.reason,
    required this.track,
    required this.kind,
    this.formNumber,
    this.route,
    this.packet = FormPacket.newClaim,
    this.multiplicityKey = '',
    this.nexusKind = '',
  });

  final String id;
  final String title;
  final String reason;
  final FormTrack track;
  final SuggestionKind kind;

  /// The VA form number, when this is a form. Null for evidence like a nexus
  /// letter, which has no form number.
  final String? formNumber;

  /// The in-app route this opens, or null when it is not open to prepare here.
  final String? route;

  final FormPacket packet;

  /// Distinguishes one nexus letter, or one statement, from another copy.
  final String multiplicityKey;

  /// `direct`, `secondary`, `aggravation`, `supplemental`, or empty.
  final String nexusKind;

  bool get isOpen => route != null;
}

/// The three decision reviews keep their dedicated, decision-linked flow.
const dedicatedReviewIds = <String>{'20-0995', '20-0996', '10182'};

/// Where a Forms-page row opens. Evidence opens the nexus draft. A supported
/// form opens its detail. The three reviews keep their own screens.
String? routeForFormSuggestion(String caseId, FormSuggestion suggestion) {
  String? route;
  if (suggestion.kind == SuggestionKind.evidence) {
    route = AuthRoutes.casePrepareForm(caseId, nexusFormId);
  } else if (dedicatedReviewIds.contains(suggestion.id)) {
    route = suggestion.route;
  } else if (formDefFor(suggestion.id) != null) {
    route = AuthRoutes.casePrepareForm(caseId, suggestion.id);
  } else {
    route = suggestion.route;
  }
  if (route == null) return null;
  if (suggestion.packet == FormPacket.newClaim &&
      suggestion.multiplicityKey.isEmpty &&
      suggestion.kind != SuggestionKind.evidence) {
    return route;
  }
  final uri = Uri.parse(route);
  final params = Map<String, String>.from(uri.queryParameters);
  if (suggestion.packet != FormPacket.newClaim) {
    params['packet'] = formPacketName(suggestion.packet);
  }
  if (suggestion.multiplicityKey.isNotEmpty) {
    params['copy'] = suggestion.multiplicityKey;
  }
  if (suggestion.nexusKind.isNotEmpty) {
    params['kind'] = suggestion.nexusKind;
  }
  if (params.isEmpty) return route;
  return uri.replace(queryParameters: params).toString();
}

/// How many copies of this suggestion are already on the claim.
int addedCount(Iterable<PackageForm> forms, FormSuggestion suggestion) {
  final id = suggestion.kind == SuggestionKind.evidence
      ? nexusFormId
      : suggestion.id;
  final packet = formPacketName(suggestion.packet);
  var count = 0;
  for (final form in forms) {
    if (form.formNumber != id) continue;
    if (suggestion.multiplicityKey.isNotEmpty &&
        form.multiplicityKey != suggestion.multiplicityKey) {
      continue;
    }
    if (suggestion.packet != FormPacket.side &&
        form.packet.isNotEmpty &&
        form.packet != packet) {
      continue;
    }
    count++;
  }
  return count;
}

/// Badge label for copies already on the claim. Null when none are added.
String? addedCountLabel(int count) => count < 1 ? null : 'Added ($count)';

/// The Forms-list line for one suggestion. Intent to File changes once it is
/// in the package, because adding it is not the same as the VA receiving it.
String formListReason(FormSuggestion suggestion, int addedCount) {
  if (suggestion.formNumber == '21-0966' &&
      addedCount > 0 &&
      suggestion.track == FormTrack.recommended) {
    return 'In your package. Download it, sign it, and send it. The day the VA receives it is the day that counts.';
  }
  return suggestion.reason;
}

/// The two Forms-page sections.
class FormRecommendations {
  const FormRecommendations({required this.recommended, required this.other});

  final List<FormSuggestion> recommended;
  final List<FormSuggestion> other;

  bool get hasNexus => recommended.any(
    (suggestion) => suggestion.kind == SuggestionKind.evidence,
  );
}

/// Rows for one filing, recommended first.
List<FormSuggestion> suggestionsForPacket(
  FormRecommendations result,
  FormPacket packet,
) {
  return [
    for (final row in [...result.recommended, ...result.other])
      if (row.packet == packet) row,
  ];
}

/// Forms listed under a filing heading.
///
/// Unrecommended new-claim forms are listed with [otherCommonForms] instead.
List<FormSuggestion> filingFormSuggestions(
  FormRecommendations result,
  FormPacket packet,
) {
  if (packet == FormPacket.side) return const [];
  final rows = suggestionsForPacket(result, packet);
  if (packet != FormPacket.newClaim) return rows;
  return [
    for (final row in rows)
      if (row.track != FormTrack.other) row,
  ];
}

/// Unrecommended new-claim forms, then the side forms, as one section.
List<FormSuggestion> otherCommonForms(FormRecommendations result) {
  return [
    for (final row in suggestionsForPacket(result, FormPacket.newClaim))
      if (row.track == FormTrack.other) row,
    ...suggestionsForPacket(result, FormPacket.side),
  ];
}

/// The deterministic inputs the recommender reads. Everything comes from what
/// the claim already knows: first claim, issues, mental-health conditions,
/// confirmed decisions, review drafts, and a private-records signal derived
/// from saved documents. The Forms page does not ask the Veteran anything.
///
/// [unableToWork], [hasWitness], and [filedIntentToFile] stay nullable for
/// later phases (F6/F7) that may derive or collect them; null means unknown,
/// which keeps the matching form in Other. [filedIntentToFile] null leaves the
/// time-sensitive Intent to File recommended by default.
class FormRecommenderInput {
  const FormRecommenderInput({
    required this.caseId,
    required this.firstClaim,
    required this.hasIssues,
    required this.hasMentalHealthCondition,
    required this.hasOpenReviewCandidate,
    this.reviewDrafts = const [],
    this.privateProvider,
    this.unableToWork,
    this.hasWitness,
    this.filedIntentToFile,
    this.lanes = const [],
  });

  final String caseId;
  final bool? firstClaim;
  final bool hasIssues;
  final bool hasMentalHealthCondition;

  /// A confirmed decision denied, deferred, or reduced an issue, and no review
  /// draft covers it yet.
  final bool hasOpenReviewCandidate;

  /// The review vehicles already started for this claim. Used to recommend a
  /// nexus letter only in lanes that accept new evidence.
  final List<ClaimReview> reviewDrafts;

  final bool? privateProvider;
  final bool? unableToWork;
  final bool? hasWitness;
  final bool? filedIntentToFile;

  /// One row per condition. Empty means the claim has not chosen filings yet,
  /// so the new-claims forms stay listed and the review forms stay off.
  final List<IssueLaneResult> lanes;
}

/// A Higher-Level Review does not take new evidence. A Board direct review
/// does not either. Those filings are chosen on the issue, not from a draft.
bool reviewLaneAcceptsEvidence(ClaimReview draft) {
  if (draft.type == 'supplementalClaim') return true;
  if (draft.type == 'boardAppeal') {
    return draft.boardDocket == 'evidence' || draft.boardDocket == 'hearing';
  }
  return false;
}

/// Sorts every supported form into Recommended or Other, with a one-line
/// reason, and adds a nexus-letter evidence row for each claim vehicle that
/// accepts new evidence. Pure and deterministic.
FormRecommendations recommendForms(FormRecommenderInput input) {
  final recommended = <FormSuggestion>[];
  final other = <FormSuggestion>[];

  void add({
    required String id,
    required String title,
    required String reason,
    required bool recommend,
    SuggestionKind kind = SuggestionKind.form,
    String? formNumber,
    String? route,
    FormPacket packet = FormPacket.newClaim,
    String multiplicityKey = '',
    String nexusKind = '',
  }) {
    final suggestion = FormSuggestion(
      id: id,
      title: title,
      reason: reason,
      track: recommend ? FormTrack.recommended : FormTrack.other,
      kind: kind,
      formNumber: formNumber,
      route: route,
      packet: packet,
      multiplicityKey: multiplicityKey,
      nexusKind: nexusKind,
    );
    (recommend ? recommended : other).add(suggestion);
  }

  final lanes = input.lanes;
  final hasNewClaims = lanes.any(
    (lane) => lane.packet == ClaimPacket.newClaim,
  );
  final supplemental = [
    for (final lane in lanes)
      if (lane.filing == IssueFiling.supplemental) lane,
  ];
  final higher = [
    for (final lane in lanes)
      if (lane.filing == IssueFiling.higherLevel) lane,
  ];
  final board = [
    for (final lane in lanes)
      if (lane.filing == IssueFiling.board) lane,
  ];
  final statementPackets = <FormPacket>[
    if (hasNewClaims) FormPacket.newClaim,
    if (supplemental.isNotEmpty) FormPacket.supplemental,
    if (board.any((lane) => lane.acceptsEvidence)) FormPacket.board,
  ];

  String namesOf(List<IssueLaneResult> rows) {
    final names = [
      for (final lane in rows)
        if (lane.displayName.isNotEmpty) lane.displayName,
    ];
    if (names.isEmpty) return 'this condition';
    return names.join(', ');
  }

  if (hasNewClaims) {
    // Intent to File belongs only with a new claim or an increase.
    final filedItf = input.filedIntentToFile == true;
    add(
      id: '21-0966',
      title: 'Intent to File',
      formNumber: '21-0966',
      reason: filedItf
          ? 'You said you already filed an Intent to File.'
          : 'Send this to the VA before the other forms. If they grant your claim, pay can go back to the day they receive it.',
      recommend: !filedItf,
    );

    final needs526 = input.hasIssues || input.firstClaim == true || lanes.isNotEmpty;
    add(
      id: '21-526EZ',
      title: 'Disability compensation claim',
      formNumber: '21-526EZ',
      reason: needs526
          ? 'The main claim for the conditions on this claim.'
          : 'The main VA disability compensation claim.',
      recommend: needs526,
    );
  }

  final newClaimNexus = [
    for (final lane in lanes)
      if (lane.packet == ClaimPacket.newClaim && lane.needsNexus) lane,
  ];
  for (final lane in newClaimNexus) {
    add(
      id: 'nexus-526-${lane.issueId}',
      title: 'Nexus letter for ${lane.displayName}',
      reason:
          'A draft for your own doctor linking ${lane.displayName} to your service. It is not a medical opinion.',
      recommend: true,
      kind: SuggestionKind.evidence,
      multiplicityKey: nexusMultiplicityKey(
        issueId: lane.issueId,
        nexusKind: lane.nexusKind,
      ),
      nexusKind: lane.nexusKind,
    );
  }

  for (final packet in statementPackets) {
    add(
      id: '21-4138',
      title: 'Personal statement',
      formNumber: '21-4138',
      reason: input.hasIssues
          ? 'Explain in your own words how a condition affects your life.'
          : 'A written statement in your own words.',
      recommend: true,
      packet: packet,
    );
    final hasWitness = input.hasWitness == true;
    add(
      id: '21-10210',
      title: 'Buddy statement',
      formNumber: '21-10210',
      reason: hasWitness
          ? 'Someone can describe what they saw. This is their lay statement.'
          : 'A statement from someone who witnessed your condition or an event.',
      recommend: true,
      packet: packet,
    );
  }

  final supportPacket = hasNewClaims
      ? FormPacket.newClaim
      : supplemental.isNotEmpty
      ? FormPacket.supplemental
      : null;
  if (supportPacket != null) {
    add(
      id: '21-0781',
      title: 'Mental-health event statement',
      formNumber: '21-0781',
      reason: input.hasMentalHealthCondition
          ? 'You reported a mental-health condition. Use this to describe the in-service event.'
          : 'For a mental-health condition tied to an in-service event.',
      recommend: input.hasMentalHealthCondition,
      packet: supportPacket,
    );
    final privateProvider = input.privateProvider == true;
    add(
      id: '21-4142',
      title: 'Private records release',
      formNumber: '21-4142 / 21-4142a',
      reason: privateProvider
          ? 'You added a private medical record. This lets the VA request more from that provider.'
          : 'Use this if a private (non-VA) doctor or hospital treated you.',
      recommend: privateProvider,
      packet: supportPacket,
    );
    final unableToWork = input.unableToWork == true;
    add(
      id: '21-8940',
      title: 'Individual Unemployability',
      formNumber: '21-8940 / 21-4192',
      reason: unableToWork
          ? 'You said your service-connected conditions keep you from working.'
          : 'For when service-connected conditions keep you from working.',
      recommend: unableToWork,
      packet: supportPacket,
    );
  }

  if (supplemental.isNotEmpty) {
    add(
      id: '20-0995',
      title: 'Supplemental Claim',
      formNumber: '20-0995',
      reason:
          'Asks the VA to look at ${namesOf(supplemental)} again with new evidence. The form is 20-0995.',
      recommend: true,
      packet: FormPacket.supplemental,
      route: AuthRoutes.caseSupplemental(input.caseId),
    );
  }
  for (final lane in supplemental) {
    if (!lane.needsNexus) continue;
    add(
      id: 'nexus-995-${lane.issueId}',
      title: 'Nexus letter for ${lane.displayName}',
      reason:
          'A new draft for your own doctor about why ${lane.displayName} was decided the way it was. It is not a medical opinion.',
      recommend: true,
      kind: SuggestionKind.evidence,
      packet: FormPacket.supplemental,
      multiplicityKey: nexusMultiplicityKey(
        issueId: lane.issueId,
        nexusKind: 'supplemental',
      ),
      nexusKind: 'supplemental',
    );
  }

  if (higher.isNotEmpty) {
    add(
      id: '20-0996',
      title: 'Higher-Level Review',
      formNumber: '20-0996',
      reason:
          'A senior reviewer looks at the same evidence for ${namesOf(higher)}. The VA does not take new files. The form is 20-0996.',
      recommend: true,
      packet: FormPacket.higherLevel,
      route: AuthRoutes.caseHigherLevelReview(input.caseId),
    );
  }

  if (board.isNotEmpty) {
    add(
      id: '10182',
      title: 'Board Appeal',
      formNumber: '10182',
      reason:
          'A Veterans Law Judge reviews ${namesOf(board)}. The form is 10182.',
      recommend: true,
      packet: FormPacket.board,
      route: AuthRoutes.caseBoard(input.caseId),
    );
  }
  for (final lane in board) {
    if (!lane.needsNexus) continue;
    add(
      id: 'nexus-995-${lane.issueId}',
      title: 'Nexus letter for ${lane.displayName}',
      reason:
          'A new draft for your own doctor about why ${lane.displayName} was decided the way it was. It is not a medical opinion.',
      recommend: true,
      kind: SuggestionKind.evidence,
      packet: FormPacket.board,
      multiplicityKey: nexusMultiplicityKey(
        issueId: lane.issueId,
        nexusKind: 'supplemental',
      ),
      nexusKind: 'supplemental',
    );
  }

  add(
    id: '20-10206',
    title: 'Records request',
    formNumber: '20-10206',
    reason: 'Request a copy of your VA claims file.',
    recommend: false,
    packet: FormPacket.side,
  );

  return FormRecommendations(recommended: recommended, other: other);
}
