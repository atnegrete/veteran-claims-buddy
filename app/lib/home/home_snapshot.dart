import '../auth/auth_redirect.dart';
import '../cases/veteran_case.dart';

/// Home's view of the working Case. Tasks and Premium stay empty until those exist.
class HomeSnapshot {
  const HomeSnapshot({
    this.workingCase,
    this.nextAction,
    this.deadlines = const [],
    this.premiumActive = false,
  });

  final HomeCaseSummary? workingCase;
  final HomeAction? nextAction;
  final List<HomeDeadline> deadlines;
  final bool premiumActive;
}

class HomeCaseSummary {
  const HomeCaseSummary({
    required this.id,
    required this.displayName,
    required this.statusLabel,
  });

  final String id;
  final String displayName;
  final String statusLabel;
}

HomeSnapshot homeSnapshotFrom({
  required List<VeteranCase> cases,
  String? workingCaseId,
  bool premiumActive = false,
}) {
  VeteranCase? working;
  for (final item in cases) {
    if (item.id == workingCaseId && item.status != 'archived') {
      working = item;
      break;
    }
  }
  return HomeSnapshot(
    premiumActive: premiumActive,
    workingCase: working == null
        ? null
        : HomeCaseSummary(
            id: working.id,
            displayName: caseDisplayName(working.displayName),
            statusLabel: caseStatusLabel(working.status),
          ),
  );
}

class HomeAction {
  const HomeAction({required this.title, required this.path});

  final String title;
  final String path;
}

class HomeDeadline {
  const HomeDeadline({
    required this.title,
    required this.whenLabel,
    required this.path,
  });

  final String title;
  final String whenLabel;
  final String path;
}

/// Premium opens the new symptom form. Otherwise Home opens the plans page.
String symptomDestination({required bool premiumActive}) {
  if (premiumActive) return '/symptoms/events/new';
  return '${AuthRoutes.plans}?reason=symptoms';
}
