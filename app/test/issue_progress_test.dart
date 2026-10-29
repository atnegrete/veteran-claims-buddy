import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_sections.dart';
import 'package:app/claim/issue_progress.dart';
import 'package:app/claim/questionnaire_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a path names the open part of an issue', () {
    expect(
      issuePanelFromPath('/cases/c1/conditions/headache', 'headache'),
      isNull,
    );
    expect(
      issuePanelFromPath(
        '/cases/c1/conditions/headache/statements/doctor-draft',
        'headache',
      ),
      'doctor',
    );
    expect(
      issuePanelFromPath('/cases/c1/conditions/headache/evidence', 'headache'),
      'evidence',
    );
  });

  test('continue opens the next condition card and skips closed ones', () {
    expect(nextConditionPanel('questions', laterClosed: false), 'decisions');
    expect(nextConditionPanel('decisions', laterClosed: false), 'connection');
    expect(nextConditionPanel('connection', laterClosed: false), 'lay');
    expect(nextConditionPanel('lay', laterClosed: false), 'doctor');
    expect(nextConditionPanel('doctor', laterClosed: false), isNull);
    expect(nextConditionPanel('decisions', laterClosed: true), isNull);
    expect(nextConditionPanel('questions', laterClosed: true), 'decisions');
    expect(previousConditionPanel('questions', laterClosed: false), isNull);
    expect(
      previousConditionPanel('decisions', laterClosed: false),
      'questions',
    );
    expect(
      previousConditionPanel('connection', laterClosed: false),
      'decisions',
    );
    expect(previousConditionPanel('lay', laterClosed: true), 'decisions');
    expect(previousConditionPanel('doctor', laterClosed: false), 'lay');
  });

  test('a condition opens on the first part that is not filled in', () {
    const open = ClaimSectionStatus.notStarted;
    const done = ClaimSectionStatus.done;
    expect(
      firstUnfinishedConditionPanel(
        laterClosed: false,
        status: {
          'questions': open,
          'decisions': open,
          'connection': open,
          'lay': open,
          'doctor': open,
        },
      ),
      'questions',
    );
    expect(
      firstUnfinishedConditionPanel(
        laterClosed: false,
        status: {
          'questions': done,
          'decisions': ClaimSectionStatus.inProgress,
          'connection': open,
          'lay': open,
          'doctor': open,
        },
      ),
      'decisions',
    );
    expect(
      firstUnfinishedConditionPanel(
        laterClosed: false,
        status: {
          'questions': done,
          'decisions': done,
          'connection': open,
          'lay': open,
          'doctor': open,
        },
      ),
      'connection',
    );
    expect(
      firstUnfinishedConditionPanel(
        laterClosed: true,
        status: {
          'questions': done,
          'decisions': done,
          'connection': open,
          'lay': open,
          'doctor': open,
        },
      ),
      'decisions',
    );
    expect(
      firstUnfinishedConditionPanel(
        laterClosed: false,
        skipDoctor: true,
        status: {
          'questions': done,
          'decisions': done,
          'connection': done,
          'lay': done,
          'doctor': open,
        },
      ),
      'lay',
    );
  });

  test('evidence names the pieces that still have no note', () {
    final progress = evidenceProgress(const [
      EvidenceLink(
        id: 'note',
        conditionId: 'back',
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

  test('a condition counts finished parts out of the ones still open', () {
    const open = ClaimSectionStatus.notStarted;
    const underway = ClaimSectionStatus.inProgress;
    const done = ClaimSectionStatus.done;
    final partial = conditionPartProgress(
      questions: done,
      decisions: underway,
      connectionSaved: true,
      laySaved: false,
      doctorComplete: false,
      laterClosed: false,
    );
    expect(partial.completed, 2);
    expect(partial.total, 5);
    expect(partial.status, ClaimSectionStatus.inProgress);
    expect(completionLabel(0, 5), '0 of 5 completed');
    expect(
      completionLabel(partial.completed, partial.total),
      '2 of 5 completed',
    );

    final untouched = conditionPartProgress(
      questions: open,
      decisions: open,
      connectionSaved: false,
      laySaved: false,
      doctorComplete: false,
      laterClosed: false,
    );
    expect(untouched.completed, 0);
    expect(untouched.status, ClaimSectionStatus.notStarted);

    final closed = conditionPartProgress(
      questions: done,
      decisions: done,
      connectionSaved: false,
      laySaved: false,
      doctorComplete: false,
      laterClosed: true,
    );
    expect(closed.completed, 2);
    expect(closed.total, 2);
    expect(closed.status, ClaimSectionStatus.done);

    final finished = conditionPartProgress(
      questions: done,
      decisions: done,
      connectionSaved: true,
      laySaved: true,
      doctorComplete: true,
      laterClosed: false,
    );
    expect(finished.status, ClaimSectionStatus.done);
    expect(
      completionLabel(finished.completed, finished.total),
      '5 of 5 completed',
    );
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
