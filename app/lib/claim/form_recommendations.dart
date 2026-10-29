import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding/onboarding_progress.dart';
import 'claim_document.dart';
import 'claim_guide.dart';
import 'claim_issue.dart';
import 'claim_issue_repository.dart';
import 'claim_review.dart';
import 'document_repository.dart';
import 'form_recommender.dart';
import 'issue_lane.dart';
import 'issue_record_repository.dart';
import 'questionnaire_catalog.dart';
import 'questionnaire_repository.dart';
import 'review_repository.dart';

/// The Forms-page recommendation for one claim, from data the claim already
/// stores. Shared by the full Forms page and the side-by-side form list.
final formRecommendationsProvider = Provider.family<FormRecommendations, String>(
  (ref, caseId) {
    final firstClaim = ref
        .watch(onboardingDocProvider)
        .maybeWhen(data: firstClaimAnswer, orElse: () => null);
    final session = ref.watch(questionnaireSessionProvider).maybeWhen(
      data: (value) => value,
      orElse: () => QuestionnaireSession.empty,
    );
    final issues = ref.watch(claimIssuesProvider).maybeWhen(
      data: (value) => value,
      orElse: () => const <ClaimIssue>[],
    );
    final claimed = [
      for (final issue in issues)
        if (issue.activeCaseId == caseId) issue,
    ];
    final documents = ref.watch(claimDocumentsProvider(caseId)).maybeWhen(
      data: (value) => value,
      orElse: () => const <ClaimDocument>[],
    );
    final candidates = ref.watch(reviewCandidatesProvider(caseId)).maybeWhen(
      data: (value) => value,
      orElse: () => const <ReviewCandidate>[],
    );
    final drafts = ref.watch(claimReviewsProvider(caseId)).maybeWhen(
      data: (value) => value,
      orElse: () => const <ClaimReview>[],
    );
    final taken = {for (final draft in drafts) draft.decisionIssueId};
    final hasOpenCandidate = candidates.any(
      (candidate) => !taken.contains(candidate.decisionIssueId),
    );
    final mentalHealth = claimed.any(
      (issue) =>
          catalogPageIdForCondition(session.questions, issue.conditionId) ==
          'mental',
    );
    final lanes = ref.watch(claimLanesProvider(caseId));
    final hasPrivateRecords = documents.any(
      (document) =>
          document.uploadStatus == 'uploaded' &&
          document.documentType == 'privateMedicalRecord',
    );
    return recommendForms(
      FormRecommenderInput(
        caseId: caseId,
        firstClaim: firstClaim,
        hasIssues: claimed.isNotEmpty,
        hasMentalHealthCondition: mentalHealth,
        hasOpenReviewCandidate: hasOpenCandidate,
        reviewDrafts: drafts,
        privateProvider: hasPrivateRecords,
        lanes: lanes,
      ),
    );
  },
);

/// One filing lane per condition on this claim.
final claimLanesProvider = Provider.family<List<IssueLaneResult>, String>((
  ref,
  caseId,
) {
  final issues = ref.watch(claimIssuesProvider).maybeWhen(
    data: (value) => value,
    orElse: () => const <ClaimIssue>[],
  );
  final drafts = ref.watch(claimReviewsProvider(caseId)).maybeWhen(
    data: (value) => value,
    orElse: () => const <ClaimReview>[],
  );
  final today = DateTime.now();
  return [
    for (final issue in issues)
      if (issue.activeCaseId == caseId)
        resolveIssueLane(
          issueId: issue.id,
          displayName: issue.displayName,
          decision: latestLaneDecision(
            ref.watch(issueDecisionsProvider(issue.id)).maybeWhen(
              data: (value) => value,
              orElse: () => const <RecordedDecision>[],
            ),
          ),
          answers: ref.watch(issueLaneAnswersProvider(issue.id)).maybeWhen(
            data: (value) => value,
            orElse: () => LaneAnswers.empty,
          ),
          theoryTypes: {
            for (final theory
                in ref.watch(issueTheoriesProvider(issue.id)).maybeWhen(
                  data: (value) => value,
                  orElse: () => const <ClaimTheory>[],
                ))
              theory.type,
          },
          today: today,
          boardDocket: boardDocketForIssue(drafts, issue.id),
        ),
  ];
});

LaneDecision? latestLaneDecision(List<RecordedDecision> decisions) {
  if (decisions.isEmpty) return null;
  final sorted = [...decisions]
    ..sort((a, b) => b.decisionDate.compareTo(a.decisionDate));
  final latest = sorted.first;
  return LaneDecision(
    decisionId: latest.decisionId,
    decisionIssueId: latest.id,
    outcome: latest.outcome,
    decisionDate: latest.decisionDate,
    displayName: latest.displayName,
    reasonCategories: latest.reasonCategories,
  );
}

String? boardDocketForIssue(List<ClaimReview> drafts, String issueId) {
  for (final draft in drafts) {
    if (draft.type == 'boardAppeal' && draft.conditionId == issueId) {
      return draft.boardDocket;
    }
  }
  return null;
}
