const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { PRIMARY_REGION } = require("./region");
const { assertEnrollmentConfirmed } = require("./auth_state");

initializeApp();
setGlobalOptions({ maxInstances: 10, region: PRIMARY_REGION });

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
