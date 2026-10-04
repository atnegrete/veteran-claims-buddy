import 'package:app/claim/symptom_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a check-in needs a date and no time', () {
    expect(
      symptomDraftError(
        const SymptomDraft(
          entryType: 'checkIn',
          occurredDate: '2026-10-04',
          occurredTime: '',
          severity: 4,
          duration: 'mostOfTheDay',
          affectedWork: false,
          limitedActivity: true,
          rested: true,
          tookTreatment: false,
          conditionId: '',
          conditionName: '',
        ),
      ),
      isNull,
    );
    expect(
      symptomDraftError(
        const SymptomDraft(
          entryType: 'checkIn',
          occurredDate: '2026-10-04',
          occurredTime: '09:00',
          severity: 4,
          duration: 'mostOfTheDay',
          affectedWork: false,
          limitedActivity: false,
          rested: false,
          tookTreatment: false,
          conditionId: '',
          conditionName: '',
        ),
      ),
      'A check-in does not use a time.',
    );
  });

  test('an event needs a time and a paired condition', () {
    expect(
      symptomDraftError(
        const SymptomDraft(
          entryType: 'event',
          occurredDate: '2026-10-04',
          occurredTime: '09:30',
          severity: 8,
          duration: 'underOneHour',
          affectedWork: true,
          limitedActivity: false,
          rested: false,
          tookTreatment: true,
          conditionId: 'issue-1',
          conditionName: 'Hearing loss',
        ),
      ),
      isNull,
    );
    expect(
      symptomDraftError(
        const SymptomDraft(
          entryType: 'event',
          occurredDate: '2026-10-04',
          occurredTime: '09:30',
          severity: 8,
          duration: 'underOneHour',
          affectedWork: false,
          limitedActivity: false,
          rested: false,
          tookTreatment: false,
          conditionId: 'issue-1',
          conditionName: '',
        ),
      ),
      'Choose a condition from this claim.',
    );
  });
}
