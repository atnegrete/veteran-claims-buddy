/// Client-side mirror of the server's `classifyCaseDecision` (functions/cases.js).
///
/// Decides, from a confirmed decision's per-issue outcomes, whether the Veteran
/// may appeal (keep the case open) or should complete it. A full denial or a
/// reduction may appeal; a deferral leaves the case pending; a grant or
/// increase is complete-only. The server re-validates before any change.
class CaseOutcomeClass {
  const CaseOutcomeClass({required this.appealEligible, required this.pending});

  final bool appealEligible;
  final bool pending;
}

CaseOutcomeClass classifyCaseOutcomes(Iterable<String> outcomes) {
  final list = outcomes.toList();
  if (list.isEmpty) {
    return const CaseOutcomeClass(appealEligible: false, pending: true);
  }
  if (list.every((outcome) => outcome == 'deferred')) {
    return const CaseOutcomeClass(appealEligible: false, pending: true);
  }
  final hasGrant = list.any(
    (outcome) =>
        outcome == 'granted' ||
        outcome == 'increased' ||
        outcome == 'continued',
  );
  final hasReduced = list.any((outcome) => outcome == 'reduced');
  final hasDenied = list.any((outcome) => outcome == 'denied');
  final appealEligible = hasReduced || (hasDenied && !hasGrant);
  return CaseOutcomeClass(appealEligible: appealEligible, pending: false);
}
