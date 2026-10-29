import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../claim/claim_decision.dart';
import '../../claim/claim_exam.dart';
import '../../claim/claim_review.dart';
import '../../claim/decision_repository.dart';
import '../../claim/exam_repository.dart';
import '../../claim/review_repository.dart';
import '../../app/app_ui.dart';
import '../../claim/timeline.dart';
import 'shell_pages.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref
        .watch(claimExamsProvider(caseId))
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimExam>[]);
    final decisions = ref
        .watch(claimDecisionsProvider(caseId))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <ClaimDecision>[],
        );
    final reviews = ref
        .watch(claimReviewsProvider(caseId))
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimReview>[]);
    final rows = timelineRows(
      exams: exams,
      decisions: decisions,
      reviews: reviews,
    );
    final theme = Theme.of(context);
    return ShellPage(
      title: 'Timeline',
      child: rows.isEmpty
          ? const LeadText(
              'Exams, confirmed decisions, and review drafts show up here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, row) in rows.indexed) ...[
                  if (index > 0) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                  ],
                  if (row.date.isNotEmpty)
                    Text(
                      row.date,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (row.date.isNotEmpty) const SizedBox(height: 4),
                  Text(row.title, style: theme.textTheme.titleMedium),
                  if (row.detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      row.detail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
