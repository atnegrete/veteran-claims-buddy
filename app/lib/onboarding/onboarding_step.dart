enum OnboardingStep {
  welcome,
  service,
  deployments,
  exposures,
  discovery,
  review,
}

const onboardingStepOrder = OnboardingStep.values;

extension OnboardingStepLabel on OnboardingStep {
  String get label => switch (this) {
    OnboardingStep.welcome => 'Welcome',
    OnboardingStep.service => 'Service',
    OnboardingStep.deployments => 'Deployments',
    OnboardingStep.exposures => 'Exposures',
    OnboardingStep.discovery => 'Discovery',
    OnboardingStep.review => 'Review',
  };
}

OnboardingStep? onboardingStepFromName(String? name) {
  for (final step in onboardingStepOrder) {
    if (step.name == name) return step;
  }
  return null;
}

OnboardingStep? nextOnboardingStep(OnboardingStep step) {
  final index = onboardingStepOrder.indexOf(step);
  if (index < 0 || index + 1 >= onboardingStepOrder.length) return null;
  return onboardingStepOrder[index + 1];
}

String? validateIsoDate(String value, {required String label}) {
  final trimmed = value.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    return 'Enter $label as YYYY-MM-DD.';
  }
  final parsed = DateTime.tryParse(trimmed);
  final normalized = parsed == null
      ? ''
      : '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  if (parsed == null || normalized != trimmed) {
    return 'Enter a real date for $label.';
  }
  return null;
}

String? validateDateRange({
  required String startDate,
  required String endDate,
  required bool endOptional,
}) {
  final startError = validateIsoDate(startDate, label: 'the start date');
  if (startError != null) return startError;
  if (endOptional && endDate.trim().isEmpty) return null;
  final endError = validateIsoDate(endDate, label: 'the end date');
  if (endError != null) return endError;
  if (endDate.trim().compareTo(startDate.trim()) < 0) {
    return 'The end date is before the start date.';
  }
  return null;
}

/// A best-guess month, stored later as the first day of that month.
String? validateYearMonth(String value, {required String label}) {
  final trimmed = value.trim();
  if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(trimmed)) {
    return 'Enter $label as YYYY-MM.';
  }
  final month = int.parse(trimmed.substring(5));
  if (month < 1 || month > 12) {
    return 'Enter a real month for $label.';
  }
  return null;
}

String? validateYearMonthRange({
  required String start,
  required String end,
}) {
  final startError = validateYearMonth(start, label: 'the start');
  if (startError != null) return startError;
  final endError = validateYearMonth(end, label: 'the end');
  if (endError != null) return endError;
  if (end.trim().compareTo(start.trim()) < 0) {
    return 'The end is before the start.';
  }
  return null;
}

/// `YYYY-MM` becomes `YYYY-MM-01` so stored dates stay full dates.
String yearMonthToIsoDate(String value) => '${value.trim()}-01';

/// Shows the month from a stored `YYYY-MM-DD` date.
String displayYearMonth(String stored) {
  final match = RegExp(r'^\d{4}-\d{2}').firstMatch(stored.trim());
  return match?.group(0) ?? stored;
}
