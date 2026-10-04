import '../forms/iso_date_field.dart';

const symptomDurations = <String, String>{
  'underOneHour': 'Under an hour',
  'oneToFourHours': '1 to 4 hours',
  'mostOfTheDay': 'Most of the day',
  'allDay': 'All day',
};

/// A saved symptom check-in or event. This is not a diagnosis.
class SymptomEntry {
  const SymptomEntry({
    required this.id,
    required this.entryType,
    required this.occurredDate,
    required this.occurredTime,
    required this.severity,
    required this.duration,
    required this.affectedWork,
    required this.limitedActivity,
    required this.rested,
    required this.tookTreatment,
    required this.conditionId,
    required this.conditionName,
  });

  final String id;
  final String entryType;
  final String occurredDate;
  final String occurredTime;
  final int severity;
  final String duration;
  final bool affectedWork;
  final bool limitedActivity;
  final bool rested;
  final bool tookTreatment;
  final String conditionId;
  final String conditionName;

  bool get isEvent => entryType == 'event';

  String get durationLabel => symptomDurations[duration] ?? duration;

  factory SymptomEntry.fromData(String id, Map<String, dynamic> data) {
    final type = data['entryType'] as String?;
    final duration = data['duration'] as String?;
    return SymptomEntry(
      id: id,
      entryType: type == 'event' ? 'event' : 'checkIn',
      occurredDate: data['occurredDate'] as String? ?? '',
      occurredTime: data['occurredTime'] as String? ?? '',
      severity: (data['severity'] as num?)?.round().clamp(0, 10) ?? 0,
      duration: symptomDurations.containsKey(duration)
          ? duration!
          : 'underOneHour',
      affectedWork: data['affectedWork'] == true,
      limitedActivity: data['limitedActivity'] == true,
      rested: data['rested'] == true,
      tookTreatment: data['tookTreatment'] == true,
      conditionId: data['conditionId'] as String? ?? '',
      conditionName: data['conditionName'] as String? ?? '',
    );
  }
}

class SymptomDraft {
  const SymptomDraft({
    required this.entryType,
    required this.occurredDate,
    required this.occurredTime,
    required this.severity,
    required this.duration,
    required this.affectedWork,
    required this.limitedActivity,
    required this.rested,
    required this.tookTreatment,
    required this.conditionId,
    required this.conditionName,
  });

  final String entryType;
  final String occurredDate;
  final String occurredTime;
  final int severity;
  final String duration;
  final bool affectedWork;
  final bool limitedActivity;
  final bool rested;
  final bool tookTreatment;
  final String conditionId;
  final String conditionName;
}

String? symptomDraftError(SymptomDraft draft) {
  if (draft.entryType != 'checkIn' && draft.entryType != 'event') {
    return 'Choose a check-in or an event.';
  }
  if (!validIsoDate(draft.occurredDate)) return 'Enter the date as YYYY-MM-DD.';
  if (draft.entryType == 'checkIn' && draft.occurredTime.isNotEmpty) {
    return 'A check-in does not use a time.';
  }
  if (draft.entryType == 'event' && !validTimeOfDay(draft.occurredTime)) {
    return 'Enter the time as HH:MM.';
  }
  if (draft.severity < 0 || draft.severity > 10) {
    return 'Severity stays between 0 and 10.';
  }
  if (!symptomDurations.containsKey(draft.duration)) {
    return 'Choose how long it lasted.';
  }
  final tied = draft.conditionId.isNotEmpty;
  if (tied != draft.conditionName.isNotEmpty) {
    return 'Choose a condition from this claim.';
  }
  if (draft.conditionName.length > 120) {
    return 'That condition name is too long.';
  }
  return null;
}
