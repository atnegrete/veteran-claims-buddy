import 'package:app/claim/claim_decision.dart';
import 'package:app/claim/claim_exam.dart';
import 'package:app/claim/claim_review.dart';
import 'package:app/claim/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the timeline is exams, confirmed decisions, and review drafts', () {
    final rows = timelineRows(
      exams: const [
        ClaimExam(
          id: 'exam-1',
          caseId: 'case-1',
          examDate: '2026-11-02',
          examTime: '09:00',
          timezone: 'America/Chicago',
          examType: 'C&P',
          providerType: 'va',
          providerName: '',
          location: '',
          phone: '',
          telehealth: false,
          notes: '',
          status: 'active',
        ),
      ],
      decisions: const [
        ClaimDecision(
          id: 'decision-1',
          caseId: 'case-1',
          decisionDate: '2026-03-01',
          receivedDate: '2026-03-15',
          sourceDocumentId: null,
          sourceType: 'documentExtracted',
          status: 'confirmed',
          overallSummary: 'The knee claim was denied.',
        ),
        ClaimDecision(
          id: 'decision-2',
          caseId: 'case-1',
          decisionDate: '2026-04-01',
          receivedDate: null,
          sourceDocumentId: null,
          sourceType: 'documentExtracted',
          status: 'needsReview',
          overallSummary: 'Still a draft.',
        ),
      ],
      reviews: const [
        ClaimReview(
          id: 'review-1',
          caseId: 'case-1',
          type: 'supplementalClaim',
          formId: '20-0995',
          decisionId: 'decision-1',
          decisionIssueId: 'issue-1',
          conditionId: 'knee',
          displayName: 'Knee pain',
          boardDocket: null,
          informalConference: null,
        ),
      ],
    );

    expect(rows.map((row) => row.title).toList(), [
      'Exam',
      'Decision',
      'Supplemental Claim draft',
    ]);
    expect(rows[1].detail, 'The knee claim was denied.');
    expect(rows[2].detail, 'Form 20-0995.');
    expect(rows.any((row) => row.detail == 'Still a draft.'), isFalse);
  });
}
