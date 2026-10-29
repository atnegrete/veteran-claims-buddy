const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createPurchaseIntentHandler,
  revenueCatWebhookHandler,
  caseIsOpen,
  webhookAuthValue,
} = require("./commerce");

const NOW = 1_700_000_000_000;
const SECRET = "test-secret";

// --- in-memory Firestore (same shape the commerce handlers use) ---------

function memoryDb(seed = {}) {
  const docs = new Map(Object.entries(seed));

  function snapshot(path) {
    const data = docs.get(path);
    return {
      id: path.split("/").pop(),
      exists: data !== undefined,
      data: () => (data === undefined ? undefined : { ...data }),
      get: (field) => (data === undefined ? undefined : data[field]),
    };
  }

  function docRef(path) {
    return {
      id: path.split("/").pop(),
      path,
      async get() {
        return snapshot(path);
      },
      async set(data, options) {
        const prev = docs.get(path);
        docs.set(
          path,
          options && options.merge && prev ? { ...prev, ...data } : { ...data },
        );
      },
      collection: (name) => collectionRef(`${path}/${name}`),
    };
  }

  function collectionRef(path) {
    const depth = path.split("/").length + 1;
    let auto = 0;
    return {
      doc(id) {
        const docId = id || `auto-${(auto += 1)}`;
        return docRef(`${path}/${docId}`);
      },
      async get() {
        const children = [];
        for (const [key] of docs) {
          if (key.startsWith(`${path}/`) && key.split("/").length === depth) {
            children.push(snapshot(key));
          }
        }
        return { docs: children, empty: children.length === 0 };
      },
    };
  }

  return {
    doc: (path) => docRef(path),
    collection: (path) => collectionRef(path),
    _docs: docs,
  };
}

function webhookDeps(db) {
  return {
    db,
    now: NOW,
    secret: SECRET,
    serverTimestamp: () => NOW,
    timestampFromMillis: (ms) => ({ toMillis: () => ms }),
  };
}

function fakeRes() {
  return {
    statusCode: 0,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(payload) {
      this.body = payload;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

function webhookReq(event, { method = "POST", auth = SECRET } = {}) {
  return {
    method,
    headers: { authorization: auth },
    body: { event },
  };
}

// --- webhook basics ------------------------------------------------------

test("webhookAuthValue strips a Bearer prefix", () => {
  assert.equal(webhookAuthValue({ headers: { authorization: "Bearer abc" } }), "abc");
  assert.equal(webhookAuthValue({ headers: { authorization: "abc" } }), "abc");
});

test("caseIsOpen excludes completed and archived", () => {
  assert.equal(caseIsOpen("draft"), true);
  assert.equal(caseIsOpen("completed"), false);
  assert.equal(caseIsOpen("archived"), false);
});

test("webhook rejects a non-POST method", async () => {
  const res = fakeRes();
  await revenueCatWebhookHandler(webhookReq({}, { method: "GET" }), res, webhookDeps(memoryDb()));
  assert.equal(res.statusCode, 405);
});

test("webhook rejects a wrong secret", async () => {
  const res = fakeRes();
  await revenueCatWebhookHandler(
    webhookReq({ id: "e1", app_user_id: "u1" }, { auth: "nope" }),
    res,
    webhookDeps(memoryDb()),
  );
  assert.equal(res.statusCode, 401);
});

test("webhook rejects a malformed event", async () => {
  const res = fakeRes();
  await revenueCatWebhookHandler(webhookReq({ id: "e1" }), res, webhookDeps(memoryDb()));
  assert.equal(res.statusCode, 400);
});

// --- subscription projection --------------------------------------------

test("an initial subscription purchase projects active premium", async () => {
  const db = memoryDb();
  const res = fakeRes();
  await revenueCatWebhookHandler(
    webhookReq({
      id: "e1",
      type: "INITIAL_PURCHASE",
      app_user_id: "u1",
      product_id: "ios_veteran_claims_buddy_premium_monthly",
      expiration_at_ms: NOW + 30 * 24 * 60 * 60 * 1000,
      store: "APP_STORE",
    }),
    res,
    webhookDeps(db),
  );
  assert.equal(res.statusCode, 200);
  const premium = db._docs.get("users/u1/billing/premium");
  assert.equal(premium.isActive, true);
  assert.equal(premium.source, "subscription");
  assert.equal(premium.activeCaseLimit, null);
  assert.equal(premium.willRenew, true);
});

test("an expiration event turns premium off", async () => {
  const db = memoryDb({
    "users/u1/billing/subscription": {
      isActive: true,
      premiumUntilMs: NOW + 1000,
      willRenew: true,
      productKind: "premiumMonthly",
    },
  });
  const res = fakeRes();
  await revenueCatWebhookHandler(
    webhookReq({
      id: "e2",
      type: "EXPIRATION",
      app_user_id: "u1",
      product_id: "ios_veteran_claims_buddy_premium_monthly",
    }),
    res,
    webhookDeps(db),
  );
  const premium = db._docs.get("users/u1/billing/premium");
  assert.equal(premium.isActive, false);
  // The lapsed end date and source are retained so the client can show an
  // "expired" state and offer Renew; the Firestore rule still denies on a past
  // premiumUntil.
  assert.equal(premium.source, "subscription");
  assert.ok(premium.premiumUntil != null);
});

// --- case unlock binding + idempotency ----------------------------------

test("a case unlock binds the pending intent and grants one year", async () => {
  const db = memoryDb({
    "users/u1/purchaseIntents/intent-1": {
      product: "claim_package_unlock",
      caseId: "case-1",
      status: "pending",
      createdAt: NOW - 1000,
    },
  });
  const res = fakeRes();
  await revenueCatWebhookHandler(
    webhookReq({
      id: "e3",
      type: "NON_RENEWING_PURCHASE",
      app_user_id: "u1",
      product_id: "ios_veteran_claims_buddy_claim_package_unlock",
      purchased_at_ms: NOW,
      transaction_id: "txn-1",
      store: "APP_STORE",
    }),
    res,
    webhookDeps(db),
  );
  assert.equal(res.statusCode, 200);

  const unlock = db._docs.get("users/u1/caseUnlocks/case-1");
  assert.ok(unlock, "case unlock doc written");
  assert.equal(unlock.grantsPremiumUntil.toMillis(), NOW + 365 * 24 * 60 * 60 * 1000);

  const intent = db._docs.get("users/u1/purchaseIntents/intent-1");
  assert.equal(intent.status, "consumed");
  assert.equal(intent.consumedByTransactionId, "txn-1");

  const premium = db._docs.get("users/u1/billing/premium");
  assert.equal(premium.isActive, true);
  assert.equal(premium.source, "caseUnlock");
  assert.equal(premium.activeCaseLimit, 1);

  const theCase = db._docs.get("users/u1/cases/case-1");
  assert.equal(theCase.digitalAccessType, "caseUnlock");
});

test("a duplicate event id is ignored", async () => {
  const db = memoryDb({
    "users/u1/purchaseIntents/intent-1": {
      product: "claim_package_unlock",
      caseId: "case-1",
      status: "pending",
      createdAt: NOW - 1000,
    },
  });
  const event = {
    id: "e4",
    type: "NON_RENEWING_PURCHASE",
    app_user_id: "u1",
    product_id: "ios_veteran_claims_buddy_claim_package_unlock",
    purchased_at_ms: NOW,
    transaction_id: "txn-1",
  };
  const first = fakeRes();
  await revenueCatWebhookHandler(webhookReq(event), first, webhookDeps(db));
  assert.equal(first.statusCode, 200);
  assert.equal(first.body.status, "ok");

  // Re-mark the intent pending to prove the second run does NOT re-consume it.
  db._docs.set("users/u1/purchaseIntents/intent-1", {
    product: "claim_package_unlock",
    caseId: "case-1",
    status: "pending",
    createdAt: NOW - 1000,
  });
  const second = fakeRes();
  await revenueCatWebhookHandler(webhookReq(event), second, webhookDeps(db));
  assert.equal(second.statusCode, 200);
  assert.equal(second.body.status, "duplicate");
  assert.equal(
    db._docs.get("users/u1/purchaseIntents/intent-1").status,
    "pending",
    "duplicate event did not re-process",
  );
});

// --- createPurchaseIntent ------------------------------------------------

function intentRequest(data) {
  return { auth: { uid: "u1" }, data };
}

function callableDeps(db) {
  return {
    db,
    getUser: async () => ({
      emailVerified: true,
      multiFactor: { enrolledFactors: [{ uid: "factor" }] },
    }),
    serverTimestamp: () => NOW,
  };
}

test("createPurchaseIntent writes a pending intent for a real case", async () => {
  const db = memoryDb({ "users/u1/cases/case-1": { status: "draft" } });
  const result = await createPurchaseIntentHandler(
    intentRequest({ product: "claim_package_unlock", caseId: "case-1" }),
    callableDeps(db),
  );
  assert.ok(result.intentId);
  const intent = db._docs.get(`users/u1/purchaseIntents/${result.intentId}`);
  assert.equal(intent.caseId, "case-1");
  assert.equal(intent.status, "pending");
});

test("createPurchaseIntent blocks a second open case on the case-unlock plan", async () => {
  const db = memoryDb({
    "users/u1/cases/case-1": { status: "draft" },
    "users/u1/cases/case-2": { status: "draft" },
    "users/u1/caseUnlocks/case-1": { caseId: "case-1" },
    "users/u1/billing/premium": { source: "caseUnlock", isActive: true },
  });
  await assert.rejects(
    createPurchaseIntentHandler(
      intentRequest({ product: "claim_package_unlock", caseId: "case-2" }),
      callableDeps(db),
    ),
    /Complete your current case/,
  );
});

test("createPurchaseIntent allows a second unlock once the first case is completed", async () => {
  const db = memoryDb({
    "users/u1/cases/case-1": { status: "completed" },
    "users/u1/cases/case-2": { status: "draft" },
    "users/u1/caseUnlocks/case-1": { caseId: "case-1" },
    "users/u1/billing/premium": { source: "caseUnlock", isActive: true },
  });
  const result = await createPurchaseIntentHandler(
    intentRequest({ product: "claim_package_unlock", caseId: "case-2" }),
    callableDeps(db),
  );
  assert.ok(result.intentId);
});

test("createPurchaseIntent rejects an already unlocked case", async () => {
  const db = memoryDb({
    "users/u1/cases/case-1": { status: "draft" },
    "users/u1/caseUnlocks/case-1": { caseId: "case-1" },
  });
  await assert.rejects(
    createPurchaseIntentHandler(
      intentRequest({ product: "claim_package_unlock", caseId: "case-1" }),
      callableDeps(db),
    ),
    /already unlocked/,
  );
});
