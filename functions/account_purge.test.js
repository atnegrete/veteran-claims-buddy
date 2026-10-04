const test = require("node:test");
const assert = require("node:assert/strict");
const {
  purgeDue,
  userStoragePrefix,
  purgeDueAccountsRun,
} = require("./account_purge");

test("a scheduled account is purged only after the grace period", () => {
  const now = Date.parse("2026-10-04T00:00:00.000Z");
  assert.equal(
    purgeDue(
      { accountStatus: "deletionScheduled", purgeAfter: now },
      now,
    ),
    true,
  );
  assert.equal(
    purgeDue(
      { accountStatus: "deletionScheduled", purgeAfter: now + 1 },
      now,
    ),
    false,
  );
  assert.equal(
    purgeDue({ accountStatus: "active", purgeAfter: now }, now),
    false,
  );
  assert.equal(
    purgeDue({ accountStatus: "deletionScheduled", purgeAfter: null }, now),
    false,
  );
});

test("storage deletion stays under that one user", () => {
  assert.equal(userStoragePrefix("abcdefghijklmnop"), "users/abcdefghijklmnop/");
  assert.throws(() => userStoragePrefix("../vaRuleVersions"), /Refusing/);
  assert.throws(() => userStoragePrefix("users/abcdefghijklmnop"), /Refusing/);
});

test("the job deletes one due account and leaves a future one", async () => {
  const now = new Date("2026-10-04T00:00:00.000Z");
  const dueRef = { id: "abcdefghijklmnop" };
  const laterRef = { id: "qrstuvwxyzabcdef" };
  const deleted = [];
  const storage = [];
  const authDeleted = [];
  const db = {
    collection() {
      return {
        where() {
          return {
            async get() {
              return {
                docs: [
                  {
                    id: dueRef.id,
                    ref: dueRef,
                    data: () => ({
                      accountStatus: "deletionScheduled",
                      purgeAfter: now.getTime(),
                    }),
                  },
                  {
                    id: laterRef.id,
                    ref: laterRef,
                    data: () => ({
                      accountStatus: "deletionScheduled",
                      purgeAfter: now.getTime() + 1000,
                    }),
                  },
                ],
              };
            },
          };
        },
      };
    },
    async recursiveDelete(ref) {
      deleted.push(ref.id);
    },
  };
  const purged = await purgeDueAccountsRun({
    db,
    auth: {
      async deleteUser(uid) {
        authDeleted.push(uid);
      },
    },
    bucket: {
      async deleteFiles({ prefix }) {
        storage.push(prefix);
      },
    },
    now,
  });
  assert.deepEqual(purged, ["abcdefghijklmnop"]);
  assert.deepEqual(deleted, ["abcdefghijklmnop"]);
  assert.deepEqual(storage, ["users/abcdefghijklmnop/"]);
  assert.deepEqual(authDeleted, ["abcdefghijklmnop"]);
});
