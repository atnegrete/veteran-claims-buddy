import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../claim/claim_decision.dart';
import '../../claim/claim_exam.dart';
import '../../claim/claim_review.dart';
import '../../claim/decision_repository.dart';
import '../../claim/exam_repository.dart';
import '../../claim/review_repository.dart';
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
    return ShellPage(
      title: 'Timeline',
      child: rows.isEmpty
          ? const Text(
              'Exams, confirmed decisions, and review drafts for this claim show up here. Nothing is filed.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows) ...[
                  Text(
                    row.date.isEmpty ? row.title : '${row.date} · ${row.title}',
                  ),
                  if (row.detail.isNotEmpty) Text(row.detail),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
