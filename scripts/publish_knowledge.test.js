const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { validateRules, assertRulesReplace, contentHash } = require('./publish_knowledge');
const { rules } = require('../functions/va_rules');

const file = path.join(__dirname, '../knowledge/va-rules.json');

test('the checked-in snapshot matches the letter reader', () => {
  const snapshot = validateRules(JSON.parse(fs.readFileSync(file, 'utf8')));
  assert.equal(snapshot.id, rules.id);
  assert.equal(snapshot.version, rules.version);
  assert.equal(snapshot.reviewDeadlineYears, rules.reviewDeadlineYears);
  assert.deepEqual(snapshot.reviews, rules.reviews);
  assert.deepEqual(snapshot.sources, rules.sources);
  assert.equal(contentHash(fs.readFileSync(file)).length, 64);
});

test('a published rule is replaced only on dev', () => {
  assert.throws(
    () => assertRulesReplace('active', 'veteran-claims-buddy-prod'),
    /already active/,
  );
  assert.doesNotThrow(() =>
    assertRulesReplace('active', 'veteran-claims-buddy-dev'),
  );
});

test('a source that is not a VA page is refused', () => {
  const snapshot = validateRules(JSON.parse(fs.readFileSync(file, 'utf8')));
  assert.throws(
    () =>
      validateRules({
        ...snapshot,
        sources: [{ id: 'other', title: 'Other', url: 'https://example.com/rules' }],
      }),
    /VA page/,
  );
});
