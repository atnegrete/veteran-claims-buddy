const { test } = require('node:test');
const assert = require('node:assert/strict');

const { assertDevResetAllowed } = require('./dev_project');
const { scenarioById } = require('./seed_scenarios');

test('seed refuses without the confirmation flag', () => {
  assert.throws(
    () => assertDevResetAllowed({ confirmed: false }),
    /Refusing to reset/,
  );
});

test('scenario a is service history and an unfinished onboarding', () => {
  const scenario = scenarioById('a');
  assert.equal(scenario.user.onboardingStatus, 'inProgress');
  assert.equal(scenario.documents.some((item) => item.path.startsWith('cases/')), false);
  assert.equal(scenario.documents[0].data.branch, 'army');
});

test('scenario b has two conditions, one evidence note, and an upcoming exam', () => {
  const scenario = scenarioById('b');
  const paths = scenario.documents.map((item) => item.path);
  assert.ok(paths.includes('claimIssues/hearing'));
  assert.ok(paths.includes('claimIssues/knee'));
  assert.equal(paths.filter((path) => path.startsWith('evidenceLinks/')).length, 1);
  const exam = scenario.documents.find((item) => item.path === 'exams/exam-b');
  assert.equal(exam.data.examDate, '2026-11-02');
  assert.equal(exam.data.notes.includes('Hearing'), false);
});

test('scenario c records a nexus denial and a one-year deadline', () => {
  const scenario = scenarioById('c');
  const issue = scenario.documents.find((item) => item.path === 'decisionIssues/knee-denial');
  assert.equal(issue.data.outcome, 'denied');
  assert.equal(issue.data.reasons[0].category, 'nexus');
  const decision = scenario.documents.find((item) => item.path === 'decisions/decision-c');
  assert.equal(decision.data.reviewDeadline, '2027-03-01');
  assert.equal(decision.data.deadlineRuleVersionId, 'va-rules');
});

test('scenario d has a grant, a denial, and a deferral', () => {
  const scenario = scenarioById('d');
  const outcomes = scenario.documents
    .filter((item) => item.path.startsWith('decisionIssues/'))
    .map((item) => item.data.outcome)
    .sort();
  assert.deepEqual(outcomes, ['deferred', 'denied', 'granted']);
});

test('an unknown scenario is refused', () => {
  assert.throws(() => scenarioById('z'), /a, b, c, or d/);
});
