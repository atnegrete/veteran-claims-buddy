const supportCategories = <String, String>{
  'account': 'Account',
  'billing': 'Billing',
  'technical': 'Technical',
  'printMail': 'Print & Mail',
  'claimWorkflow': 'Claim help',
  'other': 'Other',
};

const supportStatuses = <String, String>{
  'open': 'Open',
  'waitingOnUser': 'Waiting on you',
  'waitingOnSupport': 'Waiting on support',
  'resolved': 'Resolved',
  'closed': 'Closed',
};

const supportPrivacyNote =
    'Do not include a Social Security number or medical records.';

String supportCategoryLabel(String category) {
  return supportCategories[category] ?? 'Other';
}

String supportStatusLabel(String status) {
  return supportStatuses[status] ?? 'Open';
}

String normalizeSupportText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool supportSubjectOk(String value) {
  final text = normalizeSupportText(value);
  return text.isNotEmpty && text.length <= 120;
}

bool supportMessageOk(String value) {
  final text = value.trim();
  return text.isNotEmpty && text.length <= 2000;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String subject;
  final String category;
  final String status;
  final DateTime updatedAt;

  bool get isClosed => status == 'closed';
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String body;
  final DateTime createdAt;
}

class SupportFailure implements Exception {
  const SupportFailure(this.message);

  final String message;
}
