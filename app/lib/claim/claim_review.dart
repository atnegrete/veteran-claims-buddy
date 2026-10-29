const reviewOutcomes = <String>{
  'denied',
  'granted',
  'increased',
  'continued',
  'reduced',
  'other',
};

const boardDockets = <String, String>{
  'direct': 'Direct review',
  'evidence': 'With more evidence',
  'hearing': 'Hearing',
};

enum ReviewPath { supplemental, higherLevel, board }

ReviewPath? reviewPathFromRoute(String path) {
  return switch (path) {
    'supplemental' => ReviewPath.supplemental,
    'higher-level-review' => ReviewPath.higherLevel,
    'board' => ReviewPath.board,
    _ => null,
  };
}

String reviewType(ReviewPath path) {
  return switch (path) {
    ReviewPath.supplemental => 'supplementalClaim',
    ReviewPath.higherLevel => 'higherLevelReview',
    ReviewPath.board => 'boardAppeal',
  };
}

String reviewFormId(ReviewPath path) {
  return switch (path) {
    ReviewPath.supplemental => '20-0995',
    ReviewPath.higherLevel => '20-0996',
    ReviewPath.board => '10182',
  };
}

String reviewTitle(ReviewPath path) {
  return switch (path) {
    ReviewPath.supplemental => 'Supplemental Claim',
    ReviewPath.higherLevel => 'Higher-Level Review',
    ReviewPath.board => 'Board Appeal',
  };
}

String reviewExplanation(ReviewPath path) {
  return switch (path) {
    ReviewPath.supplemental => 'A Supplemental Claim asks the VA to look at this condition again with new and relevant evidence. Add that evidence in My Uploads. The form is 20-0995. This does not file the review.',
    ReviewPath.higherLevel => 'A Higher-Level Review asks a senior reviewer to look at the same evidence. You do not add new evidence on this path. You can ask for an informal conference. The form is 20-0996. This does not file the review.',
    ReviewPath.board => 'A Board Appeal asks the Board of Veterans\' Appeals to review this condition. Direct review adds nothing. Evidence gives you time to add more. A hearing is with a Veterans Law Judge. The form is 10182. This does not file the appeal.',
  };
}

bool reviewOutcomeEligible(String outcome) => reviewOutcomes.contains(outcome);

class ReviewCandidate {
  const ReviewCandidate({
    required this.decisionId,
    required this.decisionIssueId,
    required this.conditionId,
    required this.displayName,
    required this.outcome,
    required this.decisionDate,
  });

  final String decisionId;
  final String decisionIssueId;
  final String? conditionId;
  final String displayName;
  final String outcome;
  final String decisionDate;
}

class ClaimReview {
  const ClaimReview({
    required this.id,
    required this.caseId,
    required this.type,
    required this.formId,
    required this.decisionId,
    required this.decisionIssueId,
    required this.conditionId,
    required this.displayName,
    required this.boardDocket,
    required this.informalConference,
  });

  final String id;
  final String caseId;
  final String type;
  final String formId;
  final String decisionId;
  final String decisionIssueId;
  final String? conditionId;
  final String displayName;
  final String? boardDocket;
  final bool? informalConference;

  static ClaimReview? fromData(String id, Map<String, dynamic> data) {
    if (data['status'] != 'draft') return null;
    final type = data['type'] as String? ?? '';
    if (type != 'supplementalClaim' &&
        type != 'higherLevelReview' &&
        type != 'boardAppeal') {
      return null;
    }
    final forms = data['formIds'];
    final formId = forms is List && forms.isNotEmpty && forms.first is String
        ? forms.first as String
        : '';
    final conditionId = data['conditionId'];
    final docket = data['boardDocket'];
    final conference = data['informalConference'];
    return ClaimReview(
      id: id,
      caseId: data['caseId'] as String? ?? '',
      type: type,
      formId: formId,
      decisionId: data['decisionId'] as String? ?? '',
      decisionIssueId: data['decisionIssueId'] as String? ?? '',
      conditionId: conditionId is String && conditionId.isNotEmpty
          ? conditionId
          : null,
      displayName: data['displayName'] as String? ?? '',
      boardDocket: docket is String && docket.isNotEmpty ? docket : null,
      informalConference: conference is bool ? conference : null,
    );
  }
}

String? reviewDraftError({
  required ReviewPath path,
  required ReviewCandidate? issue,
  required String? boardDocket,
  required bool? informalConference,
}) {
  if (issue == null) return 'Choose a condition from a confirmed decision.';
  if (!reviewOutcomeEligible(issue.outcome)) {
    return 'Choose a condition from a confirmed decision that can be reviewed.';
  }
  if (path == ReviewPath.board && !boardDockets.containsKey(boardDocket)) {
    return 'Choose a Board docket.';
  }
  if (path != ReviewPath.board && boardDocket != null) {
    return 'Choose a Board docket.';
  }
  if (path == ReviewPath.higherLevel && informalConference == null) {
    return 'Say whether you want an informal conference.';
  }
  if (path != ReviewPath.higherLevel && informalConference != null) {
    return 'Say whether you want an informal conference.';
  }
  return null;
}
