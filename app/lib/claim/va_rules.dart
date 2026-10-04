const deadlineRuleVersionId = 'va-rules';

const reviewDeadlineYears = 1;

const vaDecisionReviewsUrl = 'https://www.va.gov/decision-reviews/';

String reviewWindowPhrase() {
  if (reviewDeadlineYears == 1) return 'One year';
  return '$reviewDeadlineYears years';
}
