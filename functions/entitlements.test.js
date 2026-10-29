const test = require("node:test");
const assert = require("node:assert/strict");
const {
  productKind,
  isSubscriptionKind,
  caseUnlockExpiryMs,
  computePremiumProjection,
  premiumFeaturesActive,
  canGeneratePackage,
  DAY_MS,
} = require("./entitlements");

const NOW = 1_000_000_000_000;

test("productKind resolves each product regardless of platform prefix", () => {
  assert.equal(productKind("ios_veteran_claims_buddy_premium_monthly"), "premiumMonthly");
  assert.equal(productKind("android_veteran_claims_buddy_premium_yearly"), "premiumYearly");
  assert.equal(productKind("web_veteran_claims_buddy_claim_package_unlock"), "caseUnlock");
  assert.equal(productKind("something_else"), null);
  assert.equal(productKind(null), null);
});

test("isSubscriptionKind only matches the two plans", () => {
  assert.equal(isSubscriptionKind("premiumMonthly"), true);
  assert.equal(isSubscriptionKind("premiumYearly"), true);
  assert.equal(isSubscriptionKind("caseUnlock"), false);
});

test("caseUnlockExpiryMs adds the configured days, defaulting to 365", () => {
  assert.equal(caseUnlockExpiryMs(NOW, 365), NOW + 365 * DAY_MS);
  assert.equal(caseUnlockExpiryMs(NOW, undefined), NOW + 365 * DAY_MS);
});

test("an active subscription wins and lifts the case limit", () => {
  const projection = computePremiumProjection({
    subscription: { isActive: true, premiumUntil: NOW + DAY_MS, willRenew: true },
    caseUnlocks: [{ grantsPremiumUntil: NOW + 10 * DAY_MS }],
    now: NOW,
  });
  assert.equal(projection.isActive, true);
  assert.equal(projection.source, "subscription");
  assert.equal(projection.activeCaseLimit, null);
  assert.equal(projection.willRenew, true);
  // premiumUntil is the furthest of the two active grants.
  assert.equal(projection.premiumUntilMs, NOW + 10 * DAY_MS);
});

test("a case unlock alone grants premium capped at one active case", () => {
  const projection = computePremiumProjection({
    subscription: { isActive: false, premiumUntil: 0 },
    caseUnlocks: [{ grantsPremiumUntil: NOW + 5 * DAY_MS }],
    now: NOW,
  });
  assert.equal(projection.isActive, true);
  assert.equal(projection.source, "caseUnlock");
  assert.equal(projection.activeCaseLimit, 1);
  assert.equal(projection.willRenew, false);
  assert.equal(projection.premiumUntilMs, NOW + 5 * DAY_MS);
});

test("an expired case unlock grants nothing but retains its end for display", () => {
  const projection = computePremiumProjection({
    subscription: { isActive: false, premiumUntil: 0 },
    caseUnlocks: [{ grantsPremiumUntil: NOW - DAY_MS }],
    now: NOW,
  });
  assert.equal(projection.isActive, false);
  assert.equal(projection.source, "caseUnlock");
  assert.equal(projection.premiumUntilMs, NOW - DAY_MS);
  assert.equal(projection.activeCaseLimit, null);
});

test("an expired subscription retains its end date and source for display", () => {
  const projection = computePremiumProjection({
    subscription: { isActive: false, premiumUntil: NOW - DAY_MS, willRenew: false },
    caseUnlocks: [],
    now: NOW,
  });
  assert.equal(projection.isActive, false);
  assert.equal(projection.source, "subscription");
  assert.equal(projection.premiumUntilMs, NOW - DAY_MS);
  assert.equal(projection.willRenew, false);
  assert.equal(projection.activeCaseLimit, null);
});

test("no subscription and no unlocks projects a null, sourceless state", () => {
  const projection = computePremiumProjection({
    subscription: { isActive: false, premiumUntil: 0 },
    caseUnlocks: [],
    now: NOW,
  });
  assert.equal(projection.isActive, false);
  assert.equal(projection.source, null);
  assert.equal(projection.premiumUntilMs, null);
});

test("premiumFeaturesActive reads the projected timestamp", () => {
  assert.equal(premiumFeaturesActive({ premiumUntil: NOW + DAY_MS }, NOW), true);
  assert.equal(premiumFeaturesActive({ premiumUntil: NOW - DAY_MS }, NOW), false);
  assert.equal(premiumFeaturesActive(null, NOW), false);
});

test("canGeneratePackage: subscription covers any case; unlock covers its case", () => {
  const sub = { source: "subscription", premiumUntil: NOW + DAY_MS };
  assert.equal(canGeneratePackage({ premium: sub, caseUnlock: null, now: NOW }), true);

  const caseUnlockPremium = { source: "caseUnlock", premiumUntil: NOW + DAY_MS };
  // Case-unlock premium does not cover a case with no unlock doc.
  assert.equal(
    canGeneratePackage({ premium: caseUnlockPremium, caseUnlock: null, now: NOW }),
    false,
  );
  // It does cover the one case it is bound to.
  assert.equal(
    canGeneratePackage({
      premium: caseUnlockPremium,
      caseUnlock: { grantsPremiumUntil: NOW + DAY_MS },
      now: NOW,
    }),
    true,
  );
});
