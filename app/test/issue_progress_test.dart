import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_sections.dart';
import 'package:app/claim/issue_progress.dart';
import 'package:app/claim/questionnaire_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a path names the open part of an issue', () {
    expect(issuePanelFromPath('/cases/c1/issues/headache', 'headache'), isNull);
    expect(
      issuePanelFromPath(
        '/cases/c1/issues/headache/statements/doctor-draft',
        'headache',
      ),
      'doctor',
    );
    expect(
      issuePanelFromPath('/cases/c1/issues/headache/evidence', 'headache'),
      'evidence',
    );
  });

  test('evidence names the pieces that still have no note', () {
    final progress = evidenceProgress(const [
      EvidenceLink(
        id: 'note',
        claimIssueId: 'back',
        evidenceType: 'nexus',
        relationship: 'supports',
        summary: 'A lifting injury in service',
      ),
    ]);
    expect(progress.added, 1);
    expect(progress.complete, isFalse);
    expect(progress.openLabels, isNot(contains('Relationship')));
    expect(progress.openLabels, contains('Current disability'));
    expect(addedLabel(1), '1 added');
    expect(addedLabel(3), '3 added');
  });

  test('an issue counts the parts that have something', () {
    expect(
      filledPartCount(
        questions: ClaimSectionStatus.done,
        evidenceNotes: 2,
        connections: 0,
        lay: true,
        doctorDraft: false,
        decisions: 0,
      ),
      3,
    );
    expect(issueFilledLabel(0), 'Nothing filled in yet');
    expect(issueFilledLabel(3), '3 parts filled in');
  });

  test('topic questions are done when that page is answered', () {
    const questions = [
      CatalogQuestion(
        id: 'head.which',
        prompt: 'Which',
        answerType: 'singleChoice',
        order: 1,
        section: 'head',
        options: [CatalogChoice(value: 'headache', label: 'Headache')],
      ),
    ];
    expect(
      topicQuestionsStatus(
        questions: questions,
        answers: const {},
        conditionId: 'head.which__headache',
      ),
      ClaimSectionStatus.notStarted,
    );
    expect(
      topicQuestionsStatus(
        questions: questions,
        answers: const {
          'head.which': ['headache'],
        },
        conditionId: 'head.which__headache',
      ),
      ClaimSectionStatus.done,
    );
  });
}
