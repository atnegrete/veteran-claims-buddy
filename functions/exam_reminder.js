const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const EXAM_REMINDER_TITLE = "Veteran Claims Buddy";
const EXAM_REMINDER_BODY = "Your exam starts in about 2 hours.";
const REMINDER_LEAD_MS = 2 * 60 * 60 * 1000;
const REMINDER_WINDOW_MS = 15 * 60 * 1000;

function utcFromZoned(examDate, examTime, timeZone) {
  if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(examDate || "")) return null;
  if (!/^[0-9]{2}:[0-9]{2}$/.test(examTime || "")) return null;
  const [year, month, day] = examDate.split("-").map(Number);
  const [hour, minute] = examTime.split(":").map(Number);
  if (hour > 23 || minute > 59) return null;
  let zone;
  try {
    zone = new Intl.DateTimeFormat("en-US", { timeZone }).resolvedOptions()
      .timeZone;
  } catch {
    return null;
  }
  if (zone !== timeZone) return null;
  const guess = new Date(Date.UTC(year, month - 1, day, hour, minute));
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(guess);
  const pick = (type) => {
    const part = parts.find((item) => item.type === type);
    return Number(part ? part.value : "0");
  };
  let wallHour = pick("hour");
  if (wallHour === 24) wallHour = 0;
  const wall = Date.UTC(
    pick("year"),
    pick("month") - 1,
    pick("day"),
    wallHour,
    pick("minute"),
    pick("second"),
  );
  return new Date(guess.getTime() - (wall - guess.getTime()));
}

function millisOf(value) {
  if (value == null) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

function examStartPatch(data) {
  if (!data || data.status !== "active") return null;
  const startsAt = utcFromZoned(data.examDate, data.examTime, data.timezone);
  if (!startsAt) return null;
  const current = millisOf(data.startsAt);
  if (current != null && Math.abs(current - startsAt.getTime()) < 1000) {
    return null;
  }
  return { startsAt };
}

function examNeedsReminder({
  status,
  startsAtMs,
  reminderSentAt,
  examReminders,
  nowMs,
}) {
  if (status !== "active") return false;
  if (reminderSentAt) return false;
  if (examReminders === false) return false;
  if (typeof startsAtMs !== "number") return false;
  const lead = startsAtMs - nowMs;
  return (
    lead >= REMINDER_LEAD_MS - REMINDER_WINDOW_MS &&
    lead <= REMINDER_LEAD_MS + REMINDER_WINDOW_MS
  );
}

function reminderMessage(route) {
  return {
    notification: {
      title: EXAM_REMINDER_TITLE,
      body: EXAM_REMINDER_BODY,
    },
    data: { route: String(route || "") },
  };
}

async function remindUpcomingExamsRun({ db, now, send }) {
  const start = new Date(now.getTime() + REMINDER_LEAD_MS - REMINDER_WINDOW_MS);
  const end = new Date(now.getTime() + REMINDER_LEAD_MS + REMINDER_WINDOW_MS);
  const snap = await db
    .collectionGroup("exams")
    .where("startsAt", ">=", Timestamp.fromDate(start))
    .where("startsAt", "<=", Timestamp.fromDate(end))
    .get();
  let sent = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const uid = doc.ref.parent.parent.id;
    const prefs = await db.doc(`users/${uid}/settings/notifications`).get();
    const examReminders = prefs.exists ? prefs.get("examReminders") : true;
    if (
      !examNeedsReminder({
        status: data.status,
        startsAtMs: millisOf(data.startsAt),
        reminderSentAt: data.reminderSentAt,
        examReminders,
        nowMs: now.getTime(),
      })
    ) {
      continue;
    }
    const push = await db.doc(`users/${uid}/settings/push`).get();
    const token = push.get("token");
    if (typeof token !== "string" || token.length === 0) continue;
    const message = reminderMessage(
      `/cases/${data.caseId}/exams/${doc.id}/details`,
    );
    try {
      await send({ token, ...message });
      await doc.ref.set(
        { reminderSentAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      sent += 1;
    } catch {
      console.error("exam reminder failed", doc.id);
    }
  }
  return sent;
}

const syncExamStart = onDocumentWritten(
  "users/{uid}/exams/{examId}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const patch = examStartPatch(after.data());
    if (!patch) return;
    await after.ref.set(
      {
        startsAt: Timestamp.fromDate(patch.startsAt),
        reminderSentAt: null,
      },
      { merge: true },
    );
  },
);

const remindUpcomingExams = onSchedule("every 15 minutes", async () => {
  await remindUpcomingExamsRun({
    db: getFirestore(),
    now: new Date(),
    send: (message) => getMessaging().send(message),
  });
});

module.exports = {
  EXAM_REMINDER_BODY,
  utcFromZoned,
  examStartPatch,
  examNeedsReminder,
  reminderMessage,
  remindUpcomingExamsRun,
  syncExamStart,
  remindUpcomingExams,
};
