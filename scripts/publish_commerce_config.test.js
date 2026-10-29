'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { validateConfig, documentFields } = require('./publish_commerce_config');

function goodConfig() {
  return {
    id: 'current',
    digitalClaimPackageBusinessPriceCents: 25000,
    premiumMonthlyBusinessPriceCents: 2999,
    premiumYearlyBusinessPriceCents: 23499,
    caseUnlockPremiumDays: 365,
    premiumEnabled: true,
    caseUnlockEnabled: true,
    schemaVersion: 1,
  };
}

test('a complete config validates', () => {
  assert.equal(validateConfig(goodConfig()).id, 'current');
});

test('non-integer prices are rejected', () => {
  const config = goodConfig();
  config.premiumMonthlyBusinessPriceCents = 29.99;
  assert.throws(() => validateConfig(config), /positive integer/);
});

test('a missing flag is rejected', () => {
  const config = goodConfig();
  delete config.premiumEnabled;
  assert.throws(() => validateConfig(config), /must be a boolean/);
});

test('a blank id is rejected', () => {
  const config = goodConfig();
  config.id = '';
  assert.throws(() => validateConfig(config), /id is required/);
});

test('documentFields encodes ints and booleans for Firestore REST', () => {
  const fields = documentFields({ a: 25000, b: true });
  assert.deepEqual(fields.a, { integerValue: '25000' });
  assert.deepEqual(fields.b, { booleanValue: true });
});
