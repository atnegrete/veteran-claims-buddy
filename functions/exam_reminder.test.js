const test = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const {
  EXAM_REMINDER_BODY,
  utcFromZoned,
  examStartPatch,
  examNeedsReminder,
  reminderMessage,
  remindUpcomingExamsRun,
} = require("./exam_reminder");

test("a Chicago winter exam is stored as UTC", () => {
  const starts = utcFromZoned("2026-01-15", "09:00", "America/Chicago");
  assert.equal(starts.toISOString(), "2026-01-15T15:00:00.000Z");
});

test("a Chicago summer exam follows daylight time", () => {
  const starts = utcFromZoned("2026-07-15", "09:00", "America/Chicago");
  assert.equal(starts.toISOString(), "2026-07-15T14:00:00.000Z");
});

test("an impossible time does not get a start", () => {
  assert.equal(utcFromZoned("2026-01-15", "25:00", "America/Chicago"), null);
  assert.equal(utcFromZoned("2026-01-15", "09:00", "Not/AZone"), null);
});

test("the same start is not written again", () => {
  const starts = utcFromZoned("2026-01-15", "09:00", "America/Chicago");
  assert.equal(
    examStartPatch({
      status: "active",
      examDate: "2026-01-15",
      examTime: "09:00",
      timezone: "America/Chicago",
      startsAt: Timestamp.fromDate(starts),
    }),
    null,
  );
});

test("the reminder names no condition", async () => {
  const now = new Date("2026-04-01T12:00:00.000Z");
  const startsAt = Timestamp.fromDate(new Date("2026-04-01T14:00:00.000Z"));
  const sent = [];
  let marked = false;
  const docs = {
    "users/uid1/settings/notifications": {
      exists: true,
      get: (field) => (field === "examReminders" ? true : null),
    },
    "users/uid1/settings/push": {
      exists: true,
      get: (field) => (field === "token" ? "token-1" : null),
    },
  };
  const db = {
    collectionGroup() {
      return {
        where() {
          return this;
        },
        async get() {
          return {
            docs: [
              {
                id: "exam1",
                data: () => ({
                  status: "active",
                  caseId: "case1",
                  examType: "Hearing loss",
                  startsAt,
                  reminderSentAt: null,
                }),
                ref: {
                  parent: { parent: { id: "uid1" } },
                  async set() {
                    marked = true;
                  },
                },
              },
            ],
          };
        },
      };
    },
    doc(path) {
      return {
        async get() {
          return docs[path];
        },
      };
    },
  };
  const count = await remindUpcomingExamsRun({
    db,
    now,
    send: async (message) => {
      sent.push(message);
    },
  });
  assert.equal(count, 1);
  assert.equal(marked, true);
  assert.equal(sent[0].notification.body, EXAM_REMINDER_BODY);
  assert.equal(JSON.stringify(sent[0]).includes("Hearing"), false);
  assert.equal(sent[0].data.route, "/cases/case1/exams/exam1/details");
});

test("a turned-off exam reminder is skipped", () => {
  assert.equal(
    examNeedsReminder({
      status: "active",
      startsAtMs: Date.parse("2026-04-01T14:00:00.000Z"),
      reminderSentAt: null,
      examReminders: false,
      nowMs: Date.parse("2026-04-01T12:00:00.000Z"),
    }),
    false,
  );
});

test("the message is only the generic sentence and a route", () => {
  const message = reminderMessage("/cases/case1/exams/exam1/details");
  assert.deepEqual(message, {
    notification: {
      title: "Veteran Claims Buddy",
      body: "Your exam starts in about 2 hours.",
    },
    data: { route: "/cases/case1/exams/exam1/details" },
  });
});
