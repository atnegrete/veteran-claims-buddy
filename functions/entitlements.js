/**
 * Entitlement logic for the digital products sold through RevenueCat.
 *
 * `users/{uid}/billing/premium` is the server-authoritative projection the
 * client reads. It is computed from two inputs the webhook maintains:
 *   - `users/{uid}/billing/subscription` (a monthly or yearly Premium plan)
 *   - `users/{uid}/caseUnlocks/{caseId}`  (each a one-time Case unlock that
 *     grants one year of Premium limited to that single case)
 *
 * Nothing here reads a RevenueCat entitlement directly. The webhook is the only
 * writer of these docs, so gating stays server-authoritative on web, iOS, and
 * Android alike. The pure functions below are unit tested in
 * `entitlements.test.js`.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Store product ids are `<platform>_veteran_claims_buddy_<product>`. The
 * platform prefix (`ios_`, `android_`, `web_`) does not matter to the server,
 * so the kind is resolved from the suffix.
 */
function productKind(productId) {
  if (typeof productId !== "string" || productId.length === 0) return null;
  if (productId.endsWith("premium_monthly")) return "premiumMonthly";
  if (productId.endsWith("premium_yearly")) return "premiumYearly";
  if (productId.endsWith("claim_package_unlock")) return "caseUnlock";
  return null;
}

function isSubscriptionKind(kind) {
  return kind === "premiumMonthly" || kind === "premiumYearly";
}

/**
 * The one year of Premium a Case unlock grants, measured from the purchase.
 */
function caseUnlockExpiryMs(purchasedAtMs, days) {
  const span = Number.isFinite(days) ? days : 365;
  return purchasedAtMs + span * DAY_MS;
}

function toMillis(value) {
  if (value == null) return 0;
  if (typeof value === "number") return value;
  if (typeof value.toMillis === "function") return value.toMillis();
  return 0;
}

/**
 * Computes the `billing/premium` projection from the subscription doc and every
 * Case unlock. Pure: callers pass plain millisecond numbers.
 *
 * @returns {{
 *   isActive: boolean,
 *   source: ('subscription'|'caseUnlock'|null),
 *   premiumUntilMs: (number|null),
 *   willRenew: boolean,
 *   activeCaseLimit: (number|null),
 * }}
 */
function computePremiumProjection({ subscription, caseUnlocks, now }) {
  const sub = subscription || {};
  const subUntil = toMillis(sub.premiumUntil);
  const subActive = sub.isActive === true && subUntil > now;

  const unlocks = Array.isArray(caseUnlocks) ? caseUnlocks : [];
  const activeUnlocks = unlocks.filter(
    (unlock) => toMillis(unlock.grantsPremiumUntil) > now,
  );

  // The active end and its source. A subscription takes precedence as the
  // source when it is active; the end is the furthest active grant.
  let activeUntil = subActive ? subUntil : 0;
  let activeSource = subActive ? "subscription" : null;
  for (const unlock of activeUnlocks) {
    const end = toMillis(unlock.grantsPremiumUntil);
    if (end > activeUntil) {
      activeUntil = end;
      if (!subActive) activeSource = "caseUnlock";
    }
  }
  const isActive = activeUntil > now;

  if (isActive) {
    // A subscription lifts the single-case limit (the standing 12-case cap
    // still applies). Premium sourced only from Case unlock(s) is capped at one
    // active case at a time.
    const activeCaseLimit = subActive
      ? null
      : activeUnlocks.length > 0
        ? 1
        : null;
    return {
      isActive: true,
      source: activeSource,
      premiumUntilMs: activeUntil,
      willRenew: subActive ? sub.willRenew === true : false,
      activeCaseLimit,
    };
  }

  // Inactive: retain the most recent end and its source across all sources
  // (active or lapsed) so the client can show an "expired" state. The Firestore
  // rule still gates on `premiumUntil > request.time`, so a past end denies.
  let lastUntil = subUntil;
  let lastSource = subUntil > 0 ? "subscription" : null;
  for (const unlock of unlocks) {
    const end = toMillis(unlock.grantsPremiumUntil);
    if (end > lastUntil) {
      lastUntil = end;
      lastSource = "caseUnlock";
    }
  }

  return {
    isActive: false,
    source: lastUntil > 0 ? lastSource : null,
    premiumUntilMs: lastUntil > 0 ? lastUntil : null,
    willRenew: false,
    activeCaseLimit: null,
  };
}

/**
 * Whether Premium features (Symptom Tracker, Vet Buddy depth, etc.) are on for
 * the account, regardless of which case the work is for.
 */
function premiumFeaturesActive(premium, now) {
  if (!premium) return false;
  return toMillis(premium.premiumUntil) > now;
}

/**
 * Whether a claim package may be generated for a specific case.
 *
 * A subscription covers every case. A Case unlock covers only the single case
 * it was bound to, for the year it grants.
 */
function canGeneratePackage({ premium, caseUnlock, now }) {
  if (premium && premium.source === "subscription" && premiumFeaturesActive(premium, now)) {
    return true;
  }
  if (caseUnlock && toMillis(caseUnlock.grantsPremiumUntil) > now) {
    return true;
  }
  return false;
}

module.exports = {
  DAY_MS,
  productKind,
  isSubscriptionKind,
  caseUnlockExpiryMs,
  computePremiumProjection,
  premiumFeaturesActive,
  canGeneratePackage,
  toMillis,
};
