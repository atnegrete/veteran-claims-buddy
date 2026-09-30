const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { PRIMARY_REGION } = require("./region");
const {
  assertEnrollmentConfirmed,
  assertNoEnrolledFactor,
} = require("./auth_state");

initializeApp();
setGlobalOptions({ maxInstances: 10, region: PRIMARY_REGION });

const { startCase, setWorkingCase, ensureWorkingCase } = require("./cases");
const {
  scheduleAccountDeletion,
  cancelAccountDeletion,
} = require("./account_deletion");

exports.confirmAuthState = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const uid = request.auth.uid;
  const user = await getAuth().getUser(uid);
  if (!assertEnrollmentConfirmed(user).ok) {
    throw new HttpsError(
      "failed-precondition",
      "Verified email and an enrolled text-message check are required.",
    );
  }

  await getFirestore().doc(`users/${uid}/security/authState`).set({
    emailVerified: true,
    mfaEnrollmentConfirmed: true,
    mfaEnrollmentConfirmedAt: FieldValue.serverTimestamp(),
  });

  return { mfaEnrollmentConfirmed: true };
});

exports.clearAuthState = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const uid = request.auth.uid;
  const user = await getAuth().getUser(uid);
  if (!assertNoEnrolledFactor(user).ok) {
    throw new HttpsError(
      "failed-precondition",
      "A text-message check is still enrolled.",
    );
  }

  await getFirestore().doc(`users/${uid}/security/authState`).set(
    {
      emailVerified: user.emailVerified === true,
      mfaEnrollmentConfirmed: false,
    },
    { merge: true },
  );

  return { mfaEnrollmentConfirmed: false };
});

exports.startCase = startCase;
exports.setWorkingCase = setWorkingCase;
exports.ensureWorkingCase = ensureWorkingCase;
exports.scheduleAccountDeletion = scheduleAccountDeletion;
exports.cancelAccountDeletion = cancelAccountDeletion;
