const test = require("node:test");
const assert = require("node:assert/strict");
const {
  accountDocument,
  enrolledFormPhone,
  formEmail,
} = require("./account_setup");

test("a new account document starts onboarding at welcome", () => {
  const now = { sentinel: true };
  assert.deepEqual(
    accountDocument(
      { email: "ada@example.com", emailVerified: false },
      now,
    ),
    {
      email: "ada@example.com",
      emailVerified: false,
      onboardingStatus: "inProgress",
      onboardingStep: "welcome",
      timezone: "America/Chicago",
      preferredLanguage: "en",
      schemaVersion: 1,
      createdAt: now,
      updatedAt: now,
    },
  );
});

test("the form phone is the enrolled U.S. number", () => {
  assert.equal(
    enrolledFormPhone({
      multiFactor: {
        enrolledFactors: [{ factorId: "phone", phoneNumber: "+15551234567" }],
      },
    }),
    "+15551234567",
  );
});

test("a missing or non-U.S. enrollment does not invent a form phone", () => {
  assert.equal(enrolledFormPhone(null), "");
  assert.equal(
    enrolledFormPhone({
      multiFactor: { enrolledFactors: [{ phoneNumber: "+445551234567" }] },
    }),
    "",
  );
});

test("the form email is the sign-in email when it is a normal address", () => {
  assert.equal(formEmail({ email: "ada@example.com" }), "ada@example.com");
  assert.equal(formEmail({ email: "not-an-email" }), "");
  assert.equal(formEmail(null), "");
});
