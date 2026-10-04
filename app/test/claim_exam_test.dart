import 'package:flutter_test/flutter_test.dart';

import 'package:app/claim/claim_exam.dart';
import 'package:app/claim/questionnaire_catalog.dart';
import 'package:app/forms/iso_date_field.dart';

void main() {
  test('a time stays HH:MM', () {
    expect(validTimeOfDay('09:30'), isTrue);
    expect(validTimeOfDay('23:59'), isTrue);
    expect(validTimeOfDay('24:00'), isFalse);
    expect(validTimeOfDay('9:30'), isFalse);
  });

  test('a blank phone is allowed and a short one is not', () {
    expect(
      examDraftError(
        examDate: '2026-04-02',
        examTime: '09:30',
        timezone: 'America/Chicago',
        examType: 'Hearing',
        providerType: 'va',
        providerName: '',
        location: '',
        phone: '+1 ',
        notes: '',
      ),
      isNull,
    );
    expect(
      examDraftError(
        examDate: '2026-04-02',
        examTime: '09:30',
        timezone: 'America/Chicago',
        examType: 'Hearing',
        providerType: 'contractor',
        providerName: '',
        location: '',
        phone: '+1 (555)',
        notes: '',
      ),
      'Enter a 10-digit mobile number, or leave the phone blank.',
    );
    expect(examPhoneStored('+1 (555) 555-0100'), '+15555550100');
    expect(examPhoneStored('+1 '), '');
  });

  test('travel follows who is giving the exam', () {
    expect(examTravelGuidance('va').single, contains('VA travel pay'));
    expect(examTravelGuidance('contractor').single, contains('14 days'));
    expect(examTravelGuidance('unknown'), hasLength(2));
    expect(examTravelGuidance('contractor').join(), isNot(contains('1-800')));
  });

  test('prep reuses answers already given', () {
    const session = QuestionnaireSession(
      questions: widgetPreviewCatalog,
      answers: {
        'head': ['yes'],
        'eyes': ['no'],
      },
    );
    final lines = examPrepLines(session);
    expect(lines, hasLength(2));
    expect(lines.first.answer, 'Yes');
    expect(lines.last.answer, 'No');
  });

  test('a reminder route opens that exam', () {
    expect(examReminderRouteOk('/cases/case-1/exams/exam-1/details'), isTrue);
    expect(examReminderRouteOk('/cases/case-1/exams/exam-1/prep'), isFalse);
    expect(examReminderBody, 'Your exam starts in about 2 hours.');
    expect(taskReminderRouteOk('/cases/case-1/tasks'), isTrue);
    expect(taskReminderRouteOk('/cases/case-1/tasks/extra'), isFalse);
  });
}
