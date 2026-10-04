const { test } = require('node:test');
const assert = require('node:assert/strict');
const calc = require('./js/calculator.js');

test('two 50 percent ratings combine to 75 and round to 80', () => {
  const unrounded = calc.unroundedCombinedRating([50, 50]);
  assert.equal(unrounded, 75);
  assert.equal(calc.roundedCombinedRating(unrounded), 80);
});

test('a 70 percent rating with a spouse, three children, and aid and attendance matches the VA example', () => {
  const cents = calc.monthlyCents(70, {
    spouse: true,
    spouseAid: true,
    parents: 0,
    childrenUnder18: 3,
    childrenSchool: 0,
  });
  assert.equal(cents, 236745);
  assert.equal(calc.formatDollars(cents), '$2,367.45');
});

test('a 10 percent rating ignores dependents', () => {
  const cents = calc.monthlyCents(10, {
    spouse: true,
    spouseAid: true,
    parents: 2,
    childrenUnder18: 2,
    childrenSchool: 1,
  });
  assert.equal(cents, 18042);
});
