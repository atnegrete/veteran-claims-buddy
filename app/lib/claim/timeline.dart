import 'claim_decision.dart';
import 'claim_exam.dart';
import 'claim_review.dart';

class TimelineRow {
  const TimelineRow({
    required this.date,
    required this.title,
    required this.detail,
  });

  final String date;
  final String title;
  final String detail;
}

/// A read-only list for one claim. It does not file anything.
List<TimelineRow> timelineRows({
  required List<ClaimExam> exams,
  required List<ClaimDecision> decisions,
  required List<ClaimReview> reviews,
}) {
  final decisionDates = {
    for (final decision in decisions) decision.id: decision.decisionDate,
  };
  final rows = <TimelineRow>[
    for (final exam in exams)
      if (exam.status != 'archived')
        TimelineRow(date: exam.examDate, title: 'Exam', detail: exam.examType),
    for (final decision in decisions)
      if (decision.status == 'confirmed')
        TimelineRow(
          date: decision.decisionDate,
          title: 'Decision',
          detail: decision.overallSummary,
        ),
    for (final review in reviews)
      TimelineRow(
        date: decisionDates[review.decisionId] ?? '',
        title: '${_reviewName(review.type)} draft',
        detail: 'Form ${review.formId}.',
      ),
  ];
  rows.sort((a, b) {
    if (a.date.isEmpty && b.date.isEmpty) return a.title.compareTo(b.title);
    if (a.date.isEmpty) return 1;
    if (b.date.isEmpty) return -1;
    return b.date.compareTo(a.date);
  });
  return rows;
}

String _reviewName(String type) {
  return switch (type) {
    'higherLevelReview' => 'Higher-Level Review',
    'boardAppeal' => 'Board Appeal',
    _ => 'Supplemental Claim',
  };
}
