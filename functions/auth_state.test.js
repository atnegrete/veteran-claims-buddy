const test = require("node:test");
const assert = require("node:assert/strict");
const { assertEnrollmentConfirmed } = require("./auth_state");

test("verified email and one factor is confirmed", () => {
  assert.deepEqual(
    assertEnrollmentConfirmed({
      emailVerified: true,
      multiFactor: { enrolledFactors: [{ uid: "factor-1" }] },
    }),
    { ok: true },
  );
});

test("a second factor still counts", () => {
  assert.equal(
    assertEnrollmentConfirmed({
      emailVerified: true,
      multiFactor: { enrolledFactors: [{ uid: "a" }, { uid: "b" }] },
    }).ok,
    true,
  );
});

test("unverified email is rejected", () => {
  assert.equal(
    assertEnrollmentConfirmed({
      emailVerified: false,
      multiFactor: { enrolledFactors: [{ uid: "factor-1" }] },
    }).ok,
    false,
  );
});

test("verified email with no factor is rejected", () => {
  assert.equal(
    assertEnrollmentConfirmed({
      emailVerified: true,
      multiFactor: { enrolledFactors: [] },
    }).ok,
    false,
  );
});

test("a missing auth record is rejected", () => {
  assert.equal(assertEnrollmentConfirmed(null).ok, false);
});
