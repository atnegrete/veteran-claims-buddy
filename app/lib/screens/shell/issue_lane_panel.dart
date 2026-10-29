import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_ui.dart';
import '../../claim/claim_decision.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_review.dart';
import '../../claim/issue_lane.dart';
import '../../claim/review_repository.dart';

/// The filing questions for one confirmed decision.
///
/// Choices stay on the page. The parent saves them.
class IssueLanePanel extends ConsumerWidget {
  const IssueLanePanel({
    super.key,
    required this.issue,
    required this.decision,
    required this.answers,
    required this.onChanged,
    this.busy = false,
  });

  final ClaimIssue issue;
  final RecordedDecision decision;
  final LaneAnswers answers;
  final ValueChanged<LaneAnswers> onChanged;
  final bool busy;

  bool get _within {
    return decisionWithinReviewYear(decision.decisionDate, DateTime.now());
  }

  bool get _askMedicalLink {
    if (decision.reasonCategories.isNotEmpty) return false;
    if (answers.lawChanged) return false;
    if (answers.choice != 'disagree') return false;
    return answers.hasNewEvidence || answers.againPath == 'board';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          'What do you want to do with this decision?',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('choice-${answers.choice}'),
          initialValue: answers.choice.isEmpty ? null : answers.choice,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Your choice'),
          items: const [
            DropdownMenuItem(
              value: 'leave',
              child: Text(
                'Leave this decision',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'worse',
              child: Text(
                'It has gotten worse since that decision',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'disagree',
              child: Text(
                'I disagree with this decision',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null) return;
                  onChanged(
                    answers.copyWith(
                      choice: value,
                      againPath: value == 'disagree' ? null : '',
                      hasNewEvidence: value == 'disagree' ? null : false,
                      lawChanged: value == 'disagree' ? null : false,
                      medicalLinkMissing: value == 'disagree' ? null : false,
                    ),
                  );
                },
        ),
        if (answers.choice == 'disagree') ...[
          const SizedBox(height: 12),
          if (!_within)
            InfoNote(
              text:
                  'The year to ask for a Higher-Level Review or a Board Appeal ended on ${oneYearAfterDecision(decision.decisionDate)}.',
            ),
          if (_within) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(
                'path-${answers.hasNewEvidence}-${answers.lawChanged}-${answers.againPath}',
              ),
              initialValue: pathValue(answers),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'What is new'),
              items: const [
                DropdownMenuItem(
                  value: 'evidence',
                  child: Text(
                    'I have records or a doctor\'s opinion the VA did not have',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'law',
                  child: Text(
                    'A change in law now covers this',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'nothing',
                  child: Text(
                    'I have nothing new',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      onChanged(answersForPath(answers, value));
                    },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => onChanged(
                        answers.copyWith(
                          choice: 'disagree',
                          againPath: 'board',
                          lawChanged: false,
                        ),
                      ),
                child: const Text('Take this to a judge'),
              ),
            ),
          ],
          if (!_within) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'late-${answers.hasNewEvidence}-${answers.lawChanged}',
              ),
              initialValue: answers.lawChanged
                  ? 'law'
                  : answers.hasNewEvidence
                  ? 'evidence'
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'What is new'),
              items: const [
                DropdownMenuItem(
                  value: 'evidence',
                  child: Text(
                    'I have records or a doctor\'s opinion the VA did not have',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'law',
                  child: Text(
                    'A change in law now covers this',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      onChanged(answersForPath(answers, value));
                    },
            ),
          ],
        ],
        if (_askMedicalLink) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('link-${answers.medicalLinkMissing}'),
            initialValue: answers.medicalLinkMissing ? 'yes' : 'no',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Was a medical link missing from the decision?',
            ),
            items: const [
              DropdownMenuItem(value: 'yes', child: Text('Yes')),
              DropdownMenuItem(value: 'no', child: Text('No')),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value == null) return;
                    onChanged(
                      answers.copyWith(medicalLinkMissing: value == 'yes'),
                    );
                  },
          ),
        ],
      ],
    );
  }
}

String? pathValue(LaneAnswers answers) {
  if (answers.lawChanged) return 'law';
  if (answers.hasNewEvidence || answers.againPath == 'supplemental') {
    return 'evidence';
  }
  if (answers.againPath == 'higherLevel') return 'nothing';
  return null;
}

LaneAnswers answersForPath(LaneAnswers answers, String path) {
  return switch (path) {
    'evidence' => answers.copyWith(
      choice: 'disagree',
      againPath: 'supplemental',
      hasNewEvidence: true,
      lawChanged: false,
    ),
    'law' => answers.copyWith(
      choice: 'disagree',
      againPath: 'supplemental',
      hasNewEvidence: false,
      lawChanged: true,
    ),
    _ => answers.copyWith(
      choice: 'disagree',
      againPath: 'higherLevel',
      hasNewEvidence: false,
      lawChanged: false,
    ),
  };
}

/// Keeps one review draft that matches the filing choice.
Future<void> syncLaneReviews({
  required WidgetRef ref,
  required String uid,
  required String caseId,
  required ClaimIssue issue,
  required RecordedDecision decision,
  required LaneAnswers answers,
}) async {
  final within = decisionWithinReviewYear(
    decision.decisionDate,
    DateTime.now(),
  );
  final drafts = ref
      .read(claimReviewsProvider(caseId))
      .maybeWhen(data: (value) => value, orElse: () => const <ClaimReview>[]);
  final keep = keptReviewType(answers, within: within);
  final repository = ref.read(reviewRepositoryProvider);
  var hasSupplemental = false;
  for (final review in drafts) {
    if (review.conditionId != issue.id) continue;
    if (review.type == 'supplementalClaim') hasSupplemental = true;
    if (review.type != keep) {
      await repository.discard(uid: uid, reviewId: review.id);
    }
  }
  if (keep != 'supplementalClaim' || hasSupplemental) return;
  if (decision.decisionId.isEmpty) return;
  await repository.start(
    uid: uid,
    caseId: caseId,
    path: ReviewPath.supplemental,
    issue: ReviewCandidate(
      decisionId: decision.decisionId,
      decisionIssueId: decision.id,
      conditionId: issue.id,
      displayName: issue.displayName,
      outcome: decision.outcome,
      decisionDate: decision.decisionDate,
    ),
    boardDocket: null,
    informalConference: null,
  );
}

String? keptReviewType(LaneAnswers answers, {required bool within}) {
  if (answers.choice != 'disagree') return null;
  if (answers.againPath == 'board' && within && !answers.lawChanged) {
    return 'boardAppeal';
  }
  if (answers.againPath == 'higherLevel' &&
      within &&
      !answers.hasNewEvidence &&
      !answers.lawChanged) {
    return 'higherLevelReview';
  }
  if (answers.lawChanged ||
      answers.hasNewEvidence ||
      answers.againPath == 'supplemental') {
    return 'supplementalClaim';
  }
  return null;
}
