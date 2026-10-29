const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onUserCreated } = require("firebase-functions/v2/identity");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
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

const {
  startCase,
  setWorkingCase,
  ensureWorkingCase,
  completeCase,
  appealCase,
} = require("./cases");
const { createPurchaseIntent, revenueCatWebhook } = require("./commerce");
const {
  scheduleAccountDeletion,
  cancelAccountDeletion,
} = require("./account_deletion");
const { readUploadedDocument } = require("./document_read");
const { askVetBuddy } = require("./vet_buddy");
const {
  draftFormStatement,
  draftDisabilityExplanation,
} = require("./form_statements");
const { nexusInterviewStep } = require("./nexus_interview");
const {
  generateNexusLetters,
  reviseNexusLetter,
  downloadNexusLetter,
} = require("./nexus_generate");
const { generateForm, previewForm, downloadForm } = require("./form_generation");
const { syncExamStart, remindUpcomingExams } = require("./exam_reminder");
const { purgeDueAccounts } = require("./account_purge");
const { remindOpenTasks } = require("./task_reminder");
const {
  ensureAccountDocument,
  enrolledFormPhone,
  formEmail,
  seedFormContact,
} = require("./account_setup");

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

  const db = getFirestore();
  await ensureAccountDocument(db, user);
  await seedFormContact(db, uid, {
    phone: enrolledFormPhone(user),
    email: formEmail(user),
  });

  return { mfaEnrollmentConfirmed: true };
});

exports.provisionAccount = onUserCreated(async (event) => {
  const user = event.data;
  if (!user || !user.uid) return;
  await ensureAccountDocument(getFirestore(), user);
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
exports.completeCase = completeCase;
exports.appealCase = appealCase;
exports.createPurchaseIntent = createPurchaseIntent;
exports.revenueCatWebhook = revenueCatWebhook;
exports.scheduleAccountDeletion = scheduleAccountDeletion;
exports.cancelAccountDeletion = cancelAccountDeletion;

exports.askVetBuddy = askVetBuddy;
exports.draftFormStatement = draftFormStatement;
exports.draftDisabilityExplanation = draftDisabilityExplanation;
exports.nexusInterviewStep = nexusInterviewStep;
exports.generateNexusLetters = generateNexusLetters;
exports.reviseNexusLetter = reviseNexusLetter;
exports.downloadNexusLetter = downloadNexusLetter;
exports.generateForm = generateForm;
exports.previewForm = previewForm;
exports.downloadForm = downloadForm;
exports.syncExamStart = syncExamStart;
exports.remindUpcomingExams = remindUpcomingExams;
exports.purgeDueAccounts = purgeDueAccounts;
exports.remindOpenTasks = remindOpenTasks;

exports.countDocumentPages = onObjectFinalized(
  { timeoutSeconds: 300, memory: "1GiB" },
  async (event) => {
    await readUploadedDocument(event.data);
  },
);
