import 'package:app/onboarding/onboarding_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding advances in page-map order', () {
    expect(nextOnboardingStep(OnboardingStep.welcome), OnboardingStep.service);
    expect(
      nextOnboardingStep(OnboardingStep.service),
      OnboardingStep.deployments,
    );
    expect(
      nextOnboardingStep(OnboardingStep.deployments),
      OnboardingStep.exposures,
    );
    expect(nextOnboardingStep(OnboardingStep.exposures), OnboardingStep.review);
    expect(onboardingStepOrder, isNot(contains(OnboardingStep.discovery)));
    expect(nextOnboardingStep(OnboardingStep.review), isNull);
  });

  test('an unknown saved step falls back only through the parser', () {
    expect(onboardingStepFromName('service'), OnboardingStep.service);
    expect(onboardingStepFromName('home'), isNull);
  });

  test('date range rejects an end before the start', () {
    expect(
      validateDateRange(
        startDate: '2010-01-02',
        endDate: '2009-01-01',
        endOptional: false,
      ),
      'The end date is before the start date.',
    );
  });

  test('a still-serving period may omit the end date', () {
    expect(
      validateDateRange(
        startDate: '2010-01-02',
        endDate: '',
        endOptional: true,
      ),
      isNull,
    );
  });

  test('a deployment month rejects month 13', () {
    expect(
      validateYearMonth('2010-13', label: 'the start'),
      'Enter a real month for the start.',
    );
  });

  test('a best-guess month is stored as the first of that month', () {
    expect(
      validateYearMonthRange(start: '2010-03', end: '2010-02'),
      'The end is before the start.',
    );
    expect(yearMonthToIsoDate('2010-03'), '2010-03-01');
    expect(displayYearMonth('2010-03-01'), '2010-03');
  });

  test('an impossible calendar date is rejected', () {
    expect(
      validateIsoDate('2010-02-31', label: 'the start date'),
      'Enter a real date for the start date.',
    );
  });
}
