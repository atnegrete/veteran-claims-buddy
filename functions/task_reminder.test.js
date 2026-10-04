const test = require("node:test");
const assert = require("node:assert/strict");
const {
  TASK_REMINDER_BODY,
  taskNeedsReminder,
  taskReminderMessage,
  remindOpenTasksRun,
} = require("./task_reminder");

const today = "2026-10-04";
const now = new Date("2026-10-04T15:00:00.000Z");

test("the lock screen does not name the task", () => {
  const message = taskReminderMessage("case-1");
  assert.equal(message.notification.body, TASK_REMINDER_BODY);
  assert.equal(
    message.notification.body,
    "You have an upcoming Veteran Claims Buddy task.",
  );
  assert.equal(message.notification.body.includes("Hearing"), false);
  assert.equal(message.data.route, "/cases/case-1/tasks");
});

test("a turned-off preference or a same-day reminder is skipped", () => {
  const open = {
    status: "open",
    sourceType: "systemCalculated",
    taskReminders: true,
    lastSentDay: null,
    today,
    accountStatus: "active",
  };
  assert.equal(taskNeedsReminder(open), true);
  assert.equal(taskNeedsReminder({ ...open, taskReminders: false }), false);
  assert.equal(taskNeedsReminder({ ...open, lastSentDay: today }), false);
  assert.equal(
    taskNeedsReminder({ ...open, accountStatus: "deletionScheduled" }),
    false,
  );
});

test("one open task sends the generic sentence once", async () => {
  const sent = [];
  const stamps = [];
  const db = {
    collectionGroup() {
      return {
        where() {
          return {
            async get() {
              return {
                docs: [
                  {
                    id: "next-case-1",
                    data: () => ({
                      status: "open",
                      sourceType: "systemCalculated",
                      caseId: "case-1",
                      title: "Choose a review for Hearing loss",
                    }),
                    ref: { parent: { parent: { id: "user-1" } } },
                  },
                ],
              };
            },
          };
        },
      };
    },
    doc(path) {
      return {
        async get() {
          if (path.endsWith("/settings/notifications")) {
            return { exists: true, get: (key) => (key === "taskReminders" ? true : null) };
          }
          if (path.endsWith("/settings/push")) {
            return { exists: true, get: () => "token-1" };
          }
          if (path.endsWith("/settings/taskReminder")) {
            return { exists: false, get: () => null };
          }
          return { exists: true, get: () => "active" };
        },
        async set(data) {
          stamps.push(data);
        },
      };
    },
  };
  const count = await remindOpenTasksRun({
    db,
    now,
    send: async (message) => {
      sent.push(message);
    },
  });
  assert.equal(count, 1);
  assert.equal(sent[0].notification.body, TASK_REMINDER_BODY);
  assert.equal(sent[0].notification.body.includes("Hearing"), false);
  assert.equal(sent[0].data.route, "/cases/case-1/tasks");
  assert.equal(stamps[0].lastSentDay, today);
});
