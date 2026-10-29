/**
 * Commerce: purchase intents and the RevenueCat webhook.
 *
 * RevenueCat is the store of record. The webhook is the only writer of the
 * entitlement projection the client reads, so Premium and Case-unlock access
 * stay server-authoritative on web, iOS, and Android.
 *
 * Docs written here (all server-only to clients):
 *   users/{uid}/billing/subscription      raw subscription state
 *   users/{uid}/billing/premium           computed projection the client reads
 *   users/{uid}/caseUnlocks/{caseId}      one-year Premium bound to one case
 *   users/{uid}/purchaseIntents/{id}      ties a pending Case unlock to a case
 *   users/{uid}/billingTransactions/{id}  an audit row per provider transaction
 *   billingEvents/{eventId}               idempotency marker (top level)
 *
 * The handlers take a `deps` object so `commerce.test.js` can drive them with an
 * in-memory Firestore, matching the pattern in vet_buddy.test.js.
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getAuth } = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const { assertEnrollmentConfirmed } = require("./auth_state");
const {
  productKind,
  isSubscriptionKind,
  caseUnlockExpiryMs,
  computePremiumProjection,
  toMillis,
} = require("./entitlements");

const REVENUECAT_WEBHOOK_AUTH = defineSecret("REVENUECAT_WEBHOOK_AUTH");

const CASE_UNLOCK_PRODUCT = "claim_package_unlock";
const DEFAULT_CASE_UNLOCK_DAYS = 365;

const SUBSCRIPTION_ACTIVE_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
]);

// A case is "open" (counts against the single-case Case-unlock limit) unless it
// has been completed or archived.
function caseIsOpen(status) {
  return status !== "completed" && status !== "archived";
}

function numberOf(value) {
  const parsed = typeof value === "string" ? Number(value) : value;
  return Number.isFinite(parsed) ? parsed : 0;
}

function webhookAuthValue(req) {
  const headers = req.headers || {};
  let raw = headers.authorization || headers.Authorization || "";
  if (!raw && typeof req.get === "function") {
    raw = req.get("Authorization") || "";
  }
  return raw.startsWith("Bearer ") ? raw.slice(7) : raw;
}

// -------------------------------------------------------------------------
// Purchase intents (callable)
// -------------------------------------------------------------------------

async function requireReadyVeteran(request, deps) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const user = await deps.getUser(request.auth.uid);
  if (!assertEnrollmentConfirmed(user).ok) {
    throw new HttpsError(
      "failed-precondition",
      "Verified email and an enrolled text-message check are required.",
    );
  }
  return request.auth.uid;
}

async function createPurchaseIntentHandler(request, deps) {
  const uid = await requireReadyVeteran(request, deps);
  const db = deps.db;
  const data = request.data || {};
  if (data.product !== CASE_UNLOCK_PRODUCT) {
    throw new HttpsError("invalid-argument", "Unknown product.");
  }
  const caseId = data.caseId;
  if (typeof caseId !== "string" || caseId.trim() === "") {
    throw new HttpsError("invalid-argument", "Choose a case to unlock.");
  }

  const caseSnap = await db.doc(`users/${uid}/cases/${caseId}`).get();
  if (!caseSnap.exists) {
    throw new HttpsError("not-found", "That case is not on this account.");
  }

  const existingUnlock = await db
    .doc(`users/${uid}/caseUnlocks/${caseId}`)
    .get();
  if (existingUnlock.exists) {
    throw new HttpsError("failed-precondition", "This case is already unlocked.");
  }

  // Single active case: a Case-unlock customer may only unlock one case at a
  // time. A Premium subscription lifts this limit.
  const premiumSnap = await db.doc(`users/${uid}/billing/premium`).get();
  const premium = premiumSnap.exists ? premiumSnap.data() : null;
  const subscriptionActive =
    premium && premium.source === "subscription" && premium.isActive === true;
  if (!subscriptionActive) {
    const unlocksSnap = await db.collection(`users/${uid}/caseUnlocks`).get();
    for (const doc of unlocksSnap.docs) {
      if (doc.id === caseId) continue;
      const otherCase = await db.doc(`users/${uid}/cases/${doc.id}`).get();
      const status = otherCase.exists ? otherCase.get("status") : null;
      if (caseIsOpen(status)) {
        throw new HttpsError(
          "failed-precondition",
          "Complete your current case or switch to Premium before unlocking another case.",
        );
      }
    }
  }

  const intentRef = db.collection(`users/${uid}/purchaseIntents`).doc();
  await intentRef.set({
    product: CASE_UNLOCK_PRODUCT,
    caseId,
    status: "pending",
    createdAt: deps.serverTimestamp(),
    updatedAt: deps.serverTimestamp(),
    consumedByTransactionId: null,
    schemaVersion: 1,
  });
  return { intentId: intentRef.id };
}

// -------------------------------------------------------------------------
// RevenueCat webhook (HTTP)
// -------------------------------------------------------------------------

async function readCaseUnlockDays(db) {
  try {
    const snap = await db.doc("commerceConfig/current").get();
    if (snap.exists) {
      const days = snap.get("caseUnlockPremiumDays");
      if (Number.isFinite(days) && days > 0) return days;
    }
  } catch (_) {
    // Fall through to the default when the config is absent.
  }
  return DEFAULT_CASE_UNLOCK_DAYS;
}

async function applySubscriptionEvent({ db, uid, event, kind, deps }) {
  const ref = db.doc(`users/${uid}/billing/subscription`);
  const untilMs = numberOf(event.expiration_at_ms);
  const update = {
    productKind: kind,
    store: event.store || null,
    lastEventId: event.id,
    lastEventType: event.type,
    updatedAt: deps.serverTimestamp(),
    schemaVersion: 1,
  };
  if (SUBSCRIPTION_ACTIVE_TYPES.has(event.type)) {
    update.isActive = true;
    update.willRenew = true;
    if (untilMs) update.premiumUntilMs = untilMs;
  } else if (event.type === "CANCELLATION") {
    update.willRenew = false;
    if (untilMs) update.premiumUntilMs = untilMs;
  } else if (event.type === "EXPIRATION") {
    update.isActive = false;
    update.willRenew = false;
  }
  await ref.set(update, { merge: true });
}

async function applyCaseUnlockEvent({ db, uid, event, deps }) {
  const purchasedAtMs = numberOf(event.purchased_at_ms) || deps.now;
  const txId = event.transaction_id || event.id;

  const intentsSnap = await db
    .collection(`users/${uid}/purchaseIntents`)
    .get();
  const pending = intentsSnap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter(
      (intent) =>
        intent.product === CASE_UNLOCK_PRODUCT && intent.status === "pending",
    )
    .sort((a, b) => toMillis(b.createdAt) - toMillis(a.createdAt));
  const intent = pending[0] || null;
  const days = await readCaseUnlockDays(db);
  const untilMs = caseUnlockExpiryMs(purchasedAtMs, days);

  await db.doc(`users/${uid}/billingTransactions/${txId}`).set(
    {
      product: "caseUnlock",
      caseId: intent ? intent.caseId : null,
      providerTransactionId: txId,
      eventId: event.id,
      eventType: event.type,
      store: event.store || null,
      purchasedAt: deps.timestampFromMillis(purchasedAtMs),
      schemaVersion: 1,
    },
    { merge: true },
  );

  if (!intent) return;

  await db.doc(`users/${uid}/caseUnlocks/${intent.caseId}`).set(
    {
      caseId: intent.caseId,
      grantsPremiumUntil: deps.timestampFromMillis(untilMs),
      purchasedAt: deps.timestampFromMillis(purchasedAtMs),
      providerTransactionId: txId,
      eventId: event.id,
      schemaVersion: 1,
    },
    { merge: true },
  );
  await db.doc(`users/${uid}/purchaseIntents/${intent.id}`).set(
    {
      status: "consumed",
      consumedByTransactionId: txId,
      updatedAt: deps.serverTimestamp(),
    },
    { merge: true },
  );
  await db.doc(`users/${uid}/cases/${intent.caseId}`).set(
    {
      digitalAccessType: "caseUnlock",
      unlockSource: "caseUnlock",
      entitlementExpiresAt: deps.timestampFromMillis(untilMs),
      updatedAt: deps.serverTimestamp(),
    },
    { merge: true },
  );
}

async function recomputePremium({ db, uid, deps }) {
  const subSnap = await db.doc(`users/${uid}/billing/subscription`).get();
  const subscription = subSnap.exists ? subSnap.data() : {};
  const subInput = {
    isActive: subscription.isActive === true,
    premiumUntil: toMillis(subscription.premiumUntilMs),
    willRenew: subscription.willRenew === true,
  };

  const unlocksSnap = await db.collection(`users/${uid}/caseUnlocks`).get();
  const caseUnlocks = unlocksSnap.docs.map((doc) => doc.data());

  const projection = computePremiumProjection({
    subscription: subInput,
    caseUnlocks,
    now: deps.now,
  });

  await db.doc(`users/${uid}/billing/premium`).set(
    {
      isActive: projection.isActive,
      source: projection.source,
      premiumUntil:
        projection.premiumUntilMs == null
          ? null
          : deps.timestampFromMillis(projection.premiumUntilMs),
      willRenew: projection.willRenew,
      activeCaseLimit: projection.activeCaseLimit,
      lastVerifiedAt: deps.serverTimestamp(),
      updatedAt: deps.serverTimestamp(),
      schemaVersion: 1,
    },
    { merge: true },
  );
}

async function applyEvent({ db, uid, event, deps }) {
  const kind = productKind(event.product_id);
  if (isSubscriptionKind(kind)) {
    await applySubscriptionEvent({ db, uid, event, kind, deps });
  } else if (kind === "caseUnlock") {
    await applyCaseUnlockEvent({ db, uid, event, deps });
  }
  await recomputePremium({ db, uid, deps });
}

async function revenueCatWebhookHandler(req, res, deps) {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  if (!deps.secret || webhookAuthValue(req) !== deps.secret) {
    res.status(401).send("Unauthorized");
    return;
  }
  const event = req.body && req.body.event;
  if (
    !event ||
    typeof event.id !== "string" ||
    typeof event.app_user_id !== "string"
  ) {
    res.status(400).send("Bad Request");
    return;
  }

  const db = deps.db;
  const uid = event.app_user_id;
  const eventRef = db.doc(`billingEvents/${event.id}`);
  const existing = await eventRef.get();
  if (existing.exists) {
    res.status(200).json({ status: "duplicate" });
    return;
  }

  try {
    await applyEvent({ db, uid, event, deps });
  } catch (error) {
    // A 500 asks RevenueCat to retry (up to 5 times). Do not mark the event
    // processed so the retry can finish the work.
    console.error("revenueCatWebhook failed", error);
    res.status(500).json({ status: "error" });
    return;
  }

  await eventRef.set({
    uid,
    type: event.type || "UNKNOWN",
    productId: event.product_id || null,
    status: "processed",
    receivedAt: deps.serverTimestamp(),
    schemaVersion: 1,
  });
  res.status(200).json({ status: "ok" });
}

// -------------------------------------------------------------------------
// Production dependency wiring
// -------------------------------------------------------------------------

function callableDeps() {
  return {
    db: getFirestore(),
    getUser: (uid) => getAuth().getUser(uid),
    serverTimestamp: () => FieldValue.serverTimestamp(),
  };
}

function webhookDeps() {
  return {
    db: getFirestore(),
    now: Date.now(),
    secret: REVENUECAT_WEBHOOK_AUTH.value(),
    serverTimestamp: () => FieldValue.serverTimestamp(),
    timestampFromMillis: (ms) => Timestamp.fromMillis(ms),
  };
}

const createPurchaseIntent = onCall((request) =>
  createPurchaseIntentHandler(request, callableDeps()),
);

const revenueCatWebhook = onRequest(
  { secrets: [REVENUECAT_WEBHOOK_AUTH] },
  (req, res) => revenueCatWebhookHandler(req, res, webhookDeps()),
);

module.exports = {
  CASE_UNLOCK_PRODUCT,
  DEFAULT_CASE_UNLOCK_DAYS,
  caseIsOpen,
  numberOf,
  webhookAuthValue,
  createPurchaseIntentHandler,
  revenueCatWebhookHandler,
  applyEvent,
  recomputePremium,
  createPurchaseIntent,
  revenueCatWebhook,
};
