const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { assertEnrollmentConfirmed } = require("./auth_state");

const CASE_LIMIT = 12;
const OPEN_CASE_NAME = "Open Case";

function resolveWorkingCase(cases, currentId) {
  const active = cases.filter((item) => countsTowardCaseLimit(item.status));
  if (active.length === 0) return { create: true };
  const current = active.find((item) => item.id === currentId);
  return { create: false, caseId: (current ?? active[0]).id };
}

function normalizeCaseName(value) {
  if (typeof value !== "string") return { ok: false };
  const name = value.trim().replace(/\s+/g, " ");
  if (name.length < 1 || name.length > 80) return { ok: false };
  return { ok: true, name };
}

function countsTowardCaseLimit(status) {
  return status !== "archived";
}

function canStartCase(cases) {
  const active = cases.filter((item) => countsTowardCaseLimit(item.status));
  return active.length < CASE_LIMIT;
}

async function requireReadyVeteran(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const user = await getAuth().getUser(request.auth.uid);
  if (!assertEnrollmentConfirmed(user).ok) {
    throw new HttpsError(
      "failed-precondition",
      "Verified email and an enrolled text-message check are required.",
    );
  }
  return request.auth.uid;
}

function throwCaseOutcome(outcome) {
  if (outcome.error === "name") {
    throw new HttpsError("invalid-argument", "Enter a name up to 80 characters.");
  }
  if (outcome.error === "limit") {
    throw new HttpsError("resource-exhausted", "You can keep up to 12 cases.");
  }
  if (outcome.error === "onboarding") {
    throw new HttpsError(
      "failed-precondition",
      "Finish onboarding before starting a case.",
    );
  }
  if (outcome.error === "missing") {
    throw new HttpsError("not-found", "That case is not on this account.");
  }
  if (outcome.error === "deletion") {
    throw new HttpsError(
      "failed-precondition",
      "This account is scheduled for deletion.",
    );
  }
  if (outcome.error === "archived") {
    throw new HttpsError(
      "failed-precondition",
      "An archived case cannot be the working case.",
    );
  }
}

function applyWorkingCase(tx, userRef, userSnap, casesSnap, caseId) {
  const now = FieldValue.serverTimestamp();
  for (const doc of casesSnap.docs) {
    const should = doc.id === caseId;
    if (doc.get("isCurrentWorkingCase") === true && !should) {
      tx.update(doc.ref, { isCurrentWorkingCase: false, updatedAt: now });
    }
    if (should && doc.get("isCurrentWorkingCase") !== true) {
      tx.update(doc.ref, { isCurrentWorkingCase: true, updatedAt: now });
    }
  }
  if (userSnap.get("currentWorkingCaseId") !== caseId) {
    tx.update(userRef, { currentWorkingCaseId: caseId, updatedAt: now });
  }
}

function newCaseData(caseRef, displayName) {
  const now = FieldValue.serverTimestamp();
  return {
    id: caseRef.id,
    displayName,
    status: "draft",
    isCurrentWorkingCase: true,
    initialClaimType: "disabilityClaim",
    claimIssueIds: [],
    latestSubmissionId: null,
    latestDecisionId: null,
    openedAt: now,
    firstSubmittedAt: null,
    completedAt: null,
    completedByVeteran: false,
    digitalAccessType: "none",
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  };
}

const ensureWorkingCase = onCall(async (request) => {
  const uid = await requireReadyVeteran(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const casesRef = userRef.collection("cases");
  const caseRef = casesRef.doc();
  const outcome = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const casesSnap = await tx.get(casesRef);
    if (!userSnap.exists || userSnap.get("onboardingStatus") !== "complete") {
      return { error: "onboarding" };
    }
    if (userSnap.get("accountStatus") === "deletionScheduled") {
      return { error: "deletion" };
    }
    const cases = casesSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    const decision = resolveWorkingCase(
      cases,
      userSnap.get("currentWorkingCaseId"),
    );
    if (!decision.create) {
      applyWorkingCase(tx, userRef, userSnap, casesSnap, decision.caseId);
      return { caseId: decision.caseId };
    }
    if (!canStartCase(cases)) return { error: "limit" };
    for (const doc of casesSnap.docs) {
      if (doc.get("isCurrentWorkingCase") === true) {
        tx.update(doc.ref, {
          isCurrentWorkingCase: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    tx.set(caseRef, newCaseData(caseRef, OPEN_CASE_NAME));
    tx.update(userRef, {
      currentWorkingCaseId: caseRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { caseId: caseRef.id };
  });
  throwCaseOutcome(outcome);
  return { caseId: outcome.caseId };
});

const startCase = onCall(async (request) => {
  const uid = await requireReadyVeteran(request);
  const parsed = normalizeCaseName(request.data?.displayName);
  if (!parsed.ok) throwCaseOutcome({ error: "name" });

  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const casesRef = userRef.collection("cases");
  const caseRef = casesRef.doc();
  const outcome = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const casesSnap = await tx.get(casesRef);
    if (!userSnap.exists || userSnap.get("onboardingStatus") !== "complete") {
      return { error: "onboarding" };
    }
    if (userSnap.get("accountStatus") === "deletionScheduled") {
      return { error: "deletion" };
    }
    const cases = casesSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    if (!canStartCase(cases)) return { error: "limit" };

    for (const doc of casesSnap.docs) {
      if (doc.get("isCurrentWorkingCase") === true) {
        tx.update(doc.ref, {
          isCurrentWorkingCase: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    tx.set(caseRef, newCaseData(caseRef, parsed.name));
    tx.update(userRef, {
      currentWorkingCaseId: caseRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { caseId: caseRef.id };
  });
  throwCaseOutcome(outcome);
  return { caseId: outcome.caseId };
});

const setWorkingCase = onCall(async (request) => {
  const uid = await requireReadyVeteran(request);
  const caseId = request.data?.caseId;
  if (typeof caseId !== "string" || caseId.trim() === "") {
    throw new HttpsError("invalid-argument", "Choose a case.");
  }

  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const casesRef = userRef.collection("cases");
  const outcome = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const casesSnap = await tx.get(casesRef);
    if (!userSnap.exists || userSnap.get("onboardingStatus") !== "complete") {
      return { error: "onboarding" };
    }
    if (userSnap.get("accountStatus") === "deletionScheduled") {
      return { error: "deletion" };
    }
    const target = casesSnap.docs.find((doc) => doc.id === caseId);
    if (!target) return { error: "missing" };
    if (target.get("status") === "archived") return { error: "archived" };

    applyWorkingCase(tx, userRef, userSnap, casesSnap, caseId);
    return { caseId };
  });
  throwCaseOutcome(outcome);
  return { caseId: outcome.caseId };
});

module.exports = {
  CASE_LIMIT,
  normalizeCaseName,
  canStartCase,
  countsTowardCaseLimit,
  OPEN_CASE_NAME,
  resolveWorkingCase,
  startCase,
  setWorkingCase,
  ensureWorkingCase,
};
