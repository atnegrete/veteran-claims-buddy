const { FieldValue } = require("firebase-admin/firestore");

const defaultTimezone = "America/Chicago";

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * The account document a new Auth user needs before any client write.
 * Later screens update it. This does not copy a phone number: enrollment
 * happens after the account exists.
 */
function accountDocument(user, now) {
  return {
    email: text(user && user.email),
    emailVerified: user && user.emailVerified === true,
    onboardingStatus: "inProgress",
    onboardingStep: "welcome",
    timezone: defaultTimezone,
    preferredLanguage: "en",
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
  };
}

/** The enrolled U.S. mobile number, or empty when Auth has none yet. */
function enrolledFormPhone(user) {
  const factors = user && user.multiFactor && user.multiFactor.enrolledFactors;
  if (!Array.isArray(factors)) return "";
  for (const factor of factors) {
    const phone = text(factor && factor.phoneNumber);
    if (/^\+1\d{10}$/.test(phone)) return phone;
  }
  return "";
}

function formEmail(user) {
  const email = text(user && user.email);
  if (!email || email.length > 254) return "";
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return "";
  return email;
}

/**
 * Creates users/{uid} when it is missing. An existing document is left alone
 * so onboarding progress is not reset.
 */
async function ensureAccountDocument(db, user) {
  const uid = user && user.uid;
  if (!uid) return;
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return;
    tx.set(ref, accountDocument(user, FieldValue.serverTimestamp()));
  });
}

/**
 * Copies the enrolled phone and the sign-in email onto the form-fill
 * identifiers only while those copies are still empty.
 */
async function seedFormContact(db, uid, { phone = "", email = "" } = {}) {
  if (!uid || (!phone && !email)) return;
  const ref = db.doc(`users/${uid}/identifiers/profile`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? snap.data() || {} : {};
    const nextPhone = text(current.phone) || phone;
    const nextEmail = text(current.email) || email;
    if (
      snap.exists &&
      nextPhone === text(current.phone) &&
      nextEmail === text(current.email)
    ) {
      return;
    }
    const now = FieldValue.serverTimestamp();
    tx.set(
      ref,
      {
        legalFirstName: text(current.legalFirstName),
        legalMiddleName: text(current.legalMiddleName),
        legalLastName: text(current.legalLastName),
        dateOfBirth: text(current.dateOfBirth),
        ssn: text(current.ssn),
        vaFileNumber: text(current.vaFileNumber),
        phone: nextPhone,
        email: nextEmail,
        mailingStreet: text(current.mailingStreet),
        mailingUnit: text(current.mailingUnit),
        mailingCity: text(current.mailingCity),
        mailingState: text(current.mailingState),
        mailingZip: text(current.mailingZip),
        schemaVersion: 1,
        createdAt: current.createdAt || now,
        updatedAt: now,
      },
      { merge: true },
    );
  });
}

module.exports = {
  accountDocument,
  enrolledFormPhone,
  formEmail,
  ensureAccountDocument,
  seedFormContact,
};
