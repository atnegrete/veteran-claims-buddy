const caseLimit = 12;
const openCaseName = 'Open Case';

String caseDisplayName(String stored) {
  final name = stored.trim();
  return name.isEmpty ? openCaseName : name;
}

class VeteranCase {
  const VeteranCase({
    required this.id,
    required this.displayName,
    required this.status,
    this.appealing = false,
    this.digitalAccessType = 'none',
  });

  final String id;
  final String displayName;
  final String status;
  final bool appealing;

  /// `'none'`, `'caseUnlock'`, or `'subscription'`. How the case was unlocked.
  final String digitalAccessType;

  bool get isCompleted => status == 'completed';

  bool get isArchived => status == 'archived';

  /// Open until it is completed or archived.
  bool get isOpen => !isCompleted && !isArchived;

  static VeteranCase fromDoc(String id, Map<String, dynamic> data) {
    return VeteranCase(
      id: id,
      displayName: data['displayName'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      appealing: data['appealing'] == true,
      digitalAccessType: data['digitalAccessType'] as String? ?? 'none',
    );
  }
}

const caseStatusLabels = <String, String>{
  'draft': 'Draft',
  'working': 'In progress',
  'readyForPackage': 'Ready for a package',
  'packageGenerated': 'Package generated',
  'submittedByVeteran': 'Submitted by you',
  'awaitingVA': 'Waiting on the VA',
  'decisionReceived': 'Decision received',
  'reviewPreparing': 'Preparing a review',
  'reviewSubmitted': 'Review submitted',
  'reviewPending': 'Review pending',
  'readyToComplete': 'Ready to complete',
  'completed': 'Complete',
  'archived': 'Archived',
};

String caseStatusLabel(String status) => caseStatusLabels[status] ?? 'Draft';

bool countsTowardCaseLimit(String status) =>
    status != 'archived' && status != 'completed';

int activeCaseCount(Iterable<VeteranCase> cases) {
  return cases.where((item) => countsTowardCaseLimit(item.status)).length;
}

/// Returns the stored name, or null when it is empty or longer than 80 characters.
String? normalizeCaseName(String value) {
  final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.length > 80) return null;
  return name;
}
