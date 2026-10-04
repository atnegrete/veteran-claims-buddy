import '../account/profile.dart';
import '../auth/phone_number.dart';
import '../forms/iso_date_field.dart';
import 'questionnaire_catalog.dart';

const examTypeMax = 200;
const examProviderNameMax = 80;
const examLocationMax = 200;
const examNotesMax = 2000;

const vaClaimExamUrl = 'https://www.va.gov/resources/va-claim-exam/';
const vaTravelPayUrl =
    'https://www.va.gov/health-care/get-reimbursed-for-travel-pay/';

const examReminderBody = 'Your exam starts in about 2 hours.';

const examProviderTypes = <String, String>{
  'va': 'VA facility',
  'contractor': 'Contractor',
  'unknown': 'Not sure',
};

const _vaTravelGuidance =
    'VA travel pay covers a trip to a VA facility for this exam. Check the current guidance before you go.';

const _contractorTravelGuidance =
    'The contractor handles travel reimbursement for this exam. If it has not arrived within 14 days after the appointment, contact that contractor.';

class ClaimExam {
  const ClaimExam({
    required this.id,
    required this.caseId,
    required this.examDate,
    required this.examTime,
    required this.timezone,
    required this.examType,
    required this.providerType,
    required this.providerName,
    required this.location,
    required this.phone,
    required this.telehealth,
    required this.notes,
    required this.status,
  });

  final String id;
  final String caseId;
  final String examDate;
  final String examTime;
  final String timezone;
  final String examType;
  final String providerType;
  final String providerName;
  final String location;
  final String phone;
  final bool telehealth;
  final String notes;
  final String status;

  factory ClaimExam.fromData(String id, Map<String, dynamic> data) {
    final provider = data['providerType'] as String?;
    return ClaimExam(
      id: id,
      caseId: data['caseId'] as String? ?? '',
      examDate: data['examDate'] as String? ?? '',
      examTime: data['examTime'] as String? ?? '',
      timezone: profileTimezoneOrDefault(data['timezone'] as String?),
      examType: data['examType'] as String? ?? '',
      providerType: examProviderTypes.containsKey(provider)
          ? provider!
          : 'unknown',
      providerName: data['providerName'] as String? ?? '',
      location: data['location'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      telehealth: data['telehealth'] == true,
      notes: data['notes'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
    );
  }
}

class ExamPrepLine {
  const ExamPrepLine({required this.prompt, required this.answer});

  final String prompt;
  final String answer;
}

String? examDraftError({
  required String examDate,
  required String examTime,
  required String timezone,
  required String examType,
  required String providerType,
  required String providerName,
  required String location,
  required String phone,
  required String notes,
}) {
  if (!validIsoDate(examDate)) return 'Enter the exam date as YYYY-MM-DD.';
  if (!validTimeOfDay(examTime)) return 'Enter the time as HH:MM.';
  if (!profileTimezones.containsKey(timezone)) return 'Choose a time zone.';
  final type = examType.trim();
  if (type.isEmpty || type.length > examTypeMax) {
    return 'Enter what this exam is for.';
  }
  if (!examProviderTypes.containsKey(providerType)) {
    return 'Choose who is giving the exam.';
  }
  if (providerName.trim().length > examProviderNameMax) {
    return 'Shorten the provider name.';
  }
  if (location.trim().length > examLocationMax) return 'Shorten the location.';
  if (notes.trim().length > examNotesMax) return 'Shorten the notes.';
  if (nationalDigits(phone).isNotEmpty && toE164(phone) == null) {
    return 'Enter a 10-digit mobile number, or leave the phone blank.';
  }
  return null;
}

String examPhoneStored(String phone) => toE164(phone) ?? '';

List<String> examTravelGuidance(String providerType) {
  return switch (providerType) {
    'va' => const [_vaTravelGuidance],
    'contractor' => const [_contractorTravelGuidance],
    _ => const [_vaTravelGuidance, _contractorTravelGuidance],
  };
}

List<ExamPrepLine> examPrepLines(QuestionnaireSession session) {
  final visible = {
    for (final question in visibleCatalogQuestions(
      session.questions,
      session.answers,
    ))
      question.id,
  };
  final lines = <ExamPrepLine>[];
  for (final question in session.questions) {
    if (!visible.contains(question.id)) continue;
    final values = session.answers[question.id];
    if (values == null || values.isEmpty) continue;
    final answer = catalogDisplayValue(question, values).trim();
    if (answer.isEmpty || answer == 'Skipped') continue;
    lines.add(ExamPrepLine(prompt: question.prompt, answer: answer));
  }
  return lines;
}

bool examReminderRouteOk(String route) {
  return RegExp(r'^/cases/[A-Za-z0-9_-]+/exams/[A-Za-z0-9_-]+/details$')
      .hasMatch(route);
}

bool taskReminderRouteOk(String route) {
  return RegExp(r'^/cases/[A-Za-z0-9_-]+/tasks$').hasMatch(route);
}
