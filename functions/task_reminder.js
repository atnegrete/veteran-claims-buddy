"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const TASK_REMINDER_TITLE = "Veteran Claims Buddy";
const TASK_REMINDER_BODY = "You have an upcoming Veteran Claims Buddy task.";

function utcDay(date) {
  return date.toISOString().slice(0, 10);
}

function taskRouteOk(caseId) {
  return typeof caseId === "string" && /^[A-Za-z0-9_-]+$/.test(caseId);
}

function taskNeedsReminder({
  status,
  sourceType,
  taskReminders,
  lastSentDay,
  today,
  accountStatus,
}) {
  if (status !== "open") return false;
  if (sourceType !== "systemCalculated") return false;
  if (taskReminders === false) return false;
  if (accountStatus === "deletionScheduled") return false;
  if (lastSentDay === today) return false;
  return true;
}

function taskReminderMessage(caseId) {
  return {
    notification: {
      title: TASK_REMINDER_TITLE,
      body: TASK_REMINDER_BODY,
    },
    data: { route: `/cases/${caseId}/tasks` },
  };
}

async function remindOpenTasksRun({ db, now, send }) {
  const today = utcDay(now);
  const snap = await db.collectionGroup("tasks").where("status", "==", "open").get();
  const byUser = new Map();
  for (const doc of snap.docs) {
    const uid = doc.ref.parent.parent && doc.ref.parent.parent.id;
    if (!uid || byUser.has(uid)) continue;
    const data = doc.data();
    if (!taskNeedsReminder({
      status: data.status,
      sourceType: data.sourceType,
      taskReminders: true,
      lastSentDay: null,
      today,
      accountStatus: "active",
    })) {
      continue;
    }
    if (!taskRouteOk(data.caseId)) continue;
    byUser.set(uid, { id: doc.id, caseId: data.caseId });
  }
  let sent = 0;
  for (const [uid, task] of byUser) {
    const user = await db.doc(`users/${uid}`).get();
    const prefs = await db.doc(`users/${uid}/settings/notifications`).get();
    const stamp = await db.doc(`users/${uid}/settings/taskReminder`).get();
    const taskReminders = prefs.exists ? prefs.get("taskReminders") : true;
    if (
      !taskNeedsReminder({
        status: "open",
        sourceType: "systemCalculated",
        taskReminders,
        lastSentDay: stamp.exists ? stamp.get("lastSentDay") : null,
        today,
        accountStatus: user.exists ? user.get("accountStatus") : null,
      })
    ) {
      continue;
    }
    const push = await db.doc(`users/${uid}/settings/push`).get();
    const token = push.exists ? push.get("token") : "";
    if (typeof token !== "string" || token.length === 0) continue;
    const message = taskReminderMessage(task.caseId);
    if (message.notification.body !== TASK_REMINDER_BODY) continue;
    try {
      await send({ token, ...message });
      await db.doc(`users/${uid}/settings/taskReminder`).set(
        {
          lastSentDay: today,
          taskId: task.id,
          schemaVersion: 1,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      sent += 1;
    } catch {
      console.error("task reminder failed", uid);
    }
  }
  return sent;
}

const remindOpenTasks = onSchedule("every 24 hours", async () => {
  await remindOpenTasksRun({
    db: getFirestore(),
    now: new Date(),
    send: (message) => getMessaging().send(message),
  });
});

module.exports = {
  TASK_REMINDER_BODY,
  utcDay,
  taskRouteOk,
  taskNeedsReminder,
  taskReminderMessage,
  remindOpenTasksRun,
  remindOpenTasks,
};
