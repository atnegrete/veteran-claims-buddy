const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { assertEnrollmentConfirmed } = require("./auth_state");

const DELETION_GRACE_DAYS = 30;
const RECENT_LOGIN_SECONDS = 5 * 60;

function recentLoginOk(authTimeSeconds, nowSeconds) {
  if (typeof authTimeSeconds !== "number" || typeof nowSeconds !== "number") {
    return false;
  }
  return nowSeconds - authTimeSeconds <= RECENT_LOGIN_SECONDS;
}

function purgeAfterMillis(nowMillis) {
  return nowMillis + DELETION_GRACE_DAYS * 24 * 60 * 60 * 1000;
}

async function requireReadyVeteran(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!recentLoginOk(request.auth.token.auth_time, Date.now() / 1000)) {
    throw new HttpsError(
      "failed-precondition",
      "Enter your password again, then try that action.",
    );
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

const scheduleAccountDeletion = onCall(async (request) => {
  const uid = await requireReadyVeteran(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const purgeAfter = Timestamp.fromMillis(purgeAfterMillis(Date.now()));
  const outcome = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists || userSnap.get("onboardingStatus") !== "complete") {
      return { error: "onboarding" };
    }
    if (userSnap.get("accountStatus") === "deletionScheduled") {
      return { alreadyScheduled: true };
    }
    tx.update(userRef, {
      accountStatus: "deletionScheduled",
      deletionRequestedAt: FieldValue.serverTimestamp(),
      purgeAfter,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { scheduled: true };
  });
  if (outcome.error === "onboarding") {
    throw new HttpsError(
      "failed-precondition",
      "Finish onboarding before deleting the account.",
    );
  }
  return { accountStatus: "deletionScheduled" };
});

const cancelAccountDeletion = onCall(async (request) => {
  const uid = await requireReadyVeteran(request);
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const outcome = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists || userSnap.get("accountStatus") !== "deletionScheduled") {
      return { error: "notScheduled" };
    }
    tx.update(userRef, {
      accountStatus: "active",
      deletionRequestedAt: null,
      purgeAfter: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { cancelled: true };
  });
  if (outcome.error === "notScheduled") {
    throw new HttpsError("failed-precondition", "This account is not scheduled for deletion.");
  }
  return { accountStatus: "active" };
});

module.exports = {
  DELETION_GRACE_DAYS,
  recentLoginOk,
  purgeAfterMillis,
  scheduleAccountDeletion,
  cancelAccountDeletion,
};
