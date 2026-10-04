"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

function purgeMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "number") return value;
  return null;
}

function purgeDue(data, nowMillis) {
  if (!data || data.accountStatus !== "deletionScheduled") return false;
  const due = purgeMillis(data.purgeAfter);
  if (due == null) return false;
  return due <= nowMillis;
}

function userStoragePrefix(uid) {
  if (typeof uid !== "string" || !/^[A-Za-z0-9]{8,128}$/.test(uid)) {
    throw new Error("Refusing to purge that account.");
  }
  return `users/${uid}/`;
}

async function purgeDueAccountsRun({ db, auth, bucket, now }) {
  const snapshot = await db
    .collection("users")
    .where("accountStatus", "==", "deletionScheduled")
    .get();
  const purged = [];
  for (const doc of snapshot.docs) {
    if (!purgeDue(doc.data(), now.getTime())) continue;
    const prefix = userStoragePrefix(doc.id);
    await bucket.deleteFiles({ prefix });
    await db.recursiveDelete(doc.ref);
    try {
      await auth.deleteUser(doc.id);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    purged.push(doc.id);
  }
  return purged;
}

const purgeDueAccounts = onSchedule("every 24 hours", async () => {
  await purgeDueAccountsRun({
    db: getFirestore(),
    auth: getAuth(),
    bucket: getStorage().bucket(),
    now: new Date(),
  });
});

module.exports = {
  purgeMillis,
  purgeDue,
  userStoragePrefix,
  purgeDueAccountsRun,
  purgeDueAccounts,
};
