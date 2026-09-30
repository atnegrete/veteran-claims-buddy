const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DELETION_GRACE_DAYS,
  recentLoginOk,
  purgeAfterMillis,
} = require("./account_deletion");

test("a password check from the last five minutes is recent", () => {
  const now = 1_000_000;
  assert.equal(recentLoginOk(now - 60, now), true);
  assert.equal(recentLoginOk(now - (5 * 60), now), true);
  assert.equal(recentLoginOk(now - (5 * 60) - 1, now), false);
  assert.equal(recentLoginOk(undefined, now), false);
});

test("deletion waits 30 days", () => {
  const now = Date.parse("2026-09-30T17:00:00.000Z");
  const purgeAfter = purgeAfterMillis(now);
  assert.equal(DELETION_GRACE_DAYS, 30);
  assert.equal(purgeAfter - now, 30 * 24 * 60 * 60 * 1000);
});
