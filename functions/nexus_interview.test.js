const test = require("node:test");
const assert = require("node:assert/strict");
const { readPack } = require("./nexus_knowledge");
const {
  nexusInterviewStepHandler,
  resolvedSlotIds,
  questionPrompt,
} = require("./nexus_interview");

const pack = readPack();
const statePath = "users/u1/conditions/i1/nexusLetter/current";

function fakeDb(initial = {}) {
  const store = new Map(Object.entries(initial));
  return {
    store,
    doc(path) {
      return {
        async get() {
          const data = store.get(path);
          return { exists: data !== undefined, data: () => data };
        },
        async set(value, opts = {}) {
          if (opts.merge && store.get(path)) {
            store.set(path, { ...store.get(path), ...value });
          } else {
            store.set(path, value);
          }
        },
      };
    },
  };
}

const context = {
  condition: "Tinnitus",
  theories: [],
  links: [],
  connectionSource: "Exposed to artillery noise at Fort Sill.",
  service: [],
  deployments: [],
  exposures: [],
};

function deps(db, over = {}) {
  return {
    requireReady: async () => "u1",
    firestore: db,
    loadNexusContext: async () => context,
    pack,
    completeJson: async () => ({ question: "Tell me more about this?", help: "" }),
    ...over,
  };
}

const request = {
  auth: { uid: "u1" },
  data: { caseId: "c1", issueId: "i1", nexusKind: "direct" },
};

test("resolvedSlotIds collects seeded and answered slots", () => {
  const ids = resolvedSlotIds([
    { slotId: "a", seeded: true },
    { slotId: "b", resolved: true },
    { slotId: "c", seeded: false, resolved: false },
  ]);
  assert.deepEqual([...ids].sort(), ["a", "b"]);
});

test("questionPrompt names the slot topic and forbids identifiers", () => {
  const slot = {
    id: "symptomOnset",
    label: "When symptoms started",
    guidance: "Ask when the symptoms first began.",
  };
  const prompt = questionPrompt(context, "direct", slot, {});
  assert.match(prompt, /When symptoms started/);
  assert.match(prompt, /Social Security number/i);
});

test("the interview seeds known facts and asks the first open slot", async () => {
  const db = fakeDb();
  const result = await nexusInterviewStepHandler(request, deps(db));
  assert.equal(result.done, false);
  assert.ok(result.question);
  // inServiceEvent is seeded from the saved connection, so it is not asked.
  assert.equal(result.question.slotId, "reportedDiagnosis");
  // direct has five slots; the seeded one leaves four to ask.
  assert.equal(result.progress.total, 4);
  assert.equal(result.progress.answered, 0);
});

test("answering every open slot completes the interview", async () => {
  const db = fakeDb();
  let result = await nexusInterviewStepHandler(request, deps(db));
  let guard = 0;
  while (!result.done && guard++ < 12) {
    result = await nexusInterviewStepHandler(
      { ...request, data: { ...request.data, answer: "my answer" } },
      deps(db),
    );
  }
  assert.equal(result.done, true);
  assert.equal(result.question, null);
  assert.equal(db.store.get(statePath).interview.complete, true);
});

test("an SSN in an answer is rejected", async () => {
  const db = fakeDb();
  await nexusInterviewStepHandler(request, deps(db));
  await assert.rejects(
    () =>
      nexusInterviewStepHandler(
        { ...request, data: { ...request.data, answer: "my ssn is 123-45-6789" } },
        deps(db),
      ),
    /Social Security number|account number/i,
  );
});

test("restart clears the transcript and completion", async () => {
  const db = fakeDb();
  let result = await nexusInterviewStepHandler(request, deps(db));
  let guard = 0;
  while (!result.done && guard++ < 12) {
    result = await nexusInterviewStepHandler(
      { ...request, data: { ...request.data, answer: "x" } },
      deps(db),
    );
  }
  const after = await nexusInterviewStepHandler(
    { ...request, data: { ...request.data, restart: true } },
    deps(db),
  );
  assert.equal(after.done, false);
  assert.equal(after.progress.answered, 0);
  assert.equal(db.store.get(statePath).interview.complete, false);
});
