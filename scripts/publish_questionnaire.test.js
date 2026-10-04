const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const {
  assertPublishAllowed,
  validateDefinition,
  assertNotActive,
} = require('./publish_questionnaire');
const { definition } = require('../questionnaires/catalog');

test('prod publish refuses without the confirmation flag', () => {
  assert.throws(
    () => assertPublishAllowed({ project: 'prod', confirmProd: false }),
    /confirm-prod/,
  );
});

test('prod publish allows the confirmation flag', () => {
  assert.equal(
    assertPublishAllowed({ project: 'prod', confirmProd: true }),
    'veteran-claims-buddy-prod',
  );
});

test('an unknown project is refused', () => {
  assert.throws(
    () => assertPublishAllowed({ project: 'staging', confirmProd: false }),
    /dev or --project prod/,
  );
});

test('an active questionnaire is replaced only on dev', () => {
  assert.throws(
    () => assertNotActive('active', 'veteran-claims-buddy-prod'),
    /already active/,
  );
  assert.doesNotThrow(() =>
    assertNotActive('active', 'veteran-claims-buddy-dev'),
  );
  assert.doesNotThrow(() => assertNotActive('', 'veteran-claims-buddy-prod'));
  assert.doesNotThrow(() =>
    assertNotActive('draft', 'veteran-claims-buddy-prod'),
  );
});

test('the condition discovery catalog is a valid v2 definition', () => {
  const catalog = validateDefinition(definition());
  assert.equal(catalog.id, 'condition-discovery-v2');
  assert.equal(catalog.version, 2);
  assert.equal(catalog.entryQuestionId, 'head');
  assert.ok(catalog.questions.length > 400);
  const muscle = catalog.questions.find((question) => question.id === 'muscle.which');
  assert.ok(muscle.options.length >= 23);
  const bones = catalog.questions.find((question) => question.id === 'bone.which');
  assert.ok(bones.options.some((option) => option.value === 'skull_fracture'));
  assert.ok(bones.options.some((option) => option.value === 'coccyx'));
  const foot = catalog.questions.find((question) => question.id === 'foot.which');
  assert.ok(foot.options.some((option) => option.value === 'claw'));
  assert.ok(foot.options.some((option) => option.value === 'hallux'));
  const shoulder = catalog.questions.find((question) => question.id === 'shoulder.which');
  assert.ok(shoulder.options.some((option) => option.value === 'clavicle'));
  assert.ok(shoulder.options.some((option) => option.value === 'humerus'));
  const suicide = catalog.questions
    .find((question) => question.id === 'mental.symptoms')
    .options.find((option) => option.value === 'suicide');
  assert.equal(suicide.crisisNotice, '988');
  const child = catalog.questions.find((question) => question.id === 'sb.type');
  assert.equal(child.includeInIntake, false);
  const published = JSON.parse(
    fs.readFileSync('questionnaires/condition-discovery-v2.json', 'utf8'),
  );
  assert.deepEqual(published, catalog);
});
