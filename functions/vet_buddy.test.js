const test = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const {
  acceptedLinks,
  askVetBuddyHandler,
  blockedIdentifier,
  caseSnapshot,
  guardedReply,
  modelContents,
  sessionIsOpen,
  statementFromFact,
  safeReply,
} = require("./vet_buddy");

test("a social security number or a long account number is refused", () => {
  assert.equal(blockedIdentifier("123-45-6789"), "ssn");
  assert.equal(blockedIdentifier("the number is 123456789"), "ssn");
  assert.equal(blockedIdentifier("call 5551234567"), null);
  assert.equal(blockedIdentifier("account 1234567890123"), "account");
  assert.equal(blockedIdentifier("What is still missing?"), null);
});

test("the snapshot keeps confirmed statements and leaves the file out", () => {
  assert.equal(
    statementFromFact({
      reviewStatus: "unreviewed",
      factText: "Not confirmed yet.",
    }),
    null,
  );
  assert.deepEqual(
    statementFromFact({
      reviewStatus: "corrected",
      factText: "From the file.",
      correctedText: "The Veteran's correction.",
      page: 2,
    }),
    { text: "The Veteran's correction.", page: 2 },
  );
  const snapshot = caseSnapshot({
    issues: [{ id: "back", displayName: "Low back pain" }],
    documents: [
      {
        id: "doc-1",
        name: "Decision.pdf",
        documentType: "decisionLetter",
        uploadStatus: "uploaded",
        storagePath: "users/u/documents/d/original.pdf",
      },
      {
        id: "doc-2",
        name: "Draft.pdf",
        documentType: "other",
        uploadStatus: "uploading",
      },
    ],
    statements: [
      {
        documentId: "doc-1",
        documentName: "Decision.pdf",
        text: "Granted.",
        page: 1,
      },
    ],
  });
  assert.deepEqual(snapshot.issues, [{ id: "back", name: "Low back pain" }]);
  assert.deepEqual(snapshot.documents, [
    { id: "doc-1", name: "Decision.pdf", kind: "decisionLetter" },
  ]);
  assert.equal(JSON.stringify(snapshot).includes("original.pdf"), false);
  assert.equal(snapshot.confirmedStatements[0].text, "Granted.");
  assert.equal(snapshot.snapshotTruncated, false);
});

test("the snapshot keeps every confirmed item until the size ceiling", () => {
  const issues = Array.from({ length: 50 }, (_, index) => ({
    id: `issue-${index}`,
    displayName: `Condition ${index}`,
  }));
  const snapshot = caseSnapshot({ issues, documents: [], statements: [] });
  assert.equal(snapshot.issues.length, 50);
  assert.equal(snapshot.snapshotTruncated, false);

  const one = caseSnapshot({
    issues: [{ id: "a", displayName: "Alpha" }],
  });
  const budget = JSON.stringify({
    issues: one.issues,
    documents: [],
    confirmedStatements: [],
  }).length;
  const cut = caseSnapshot(
    {
      issues: [
        { id: "a", displayName: "Alpha" },
        { id: "b", displayName: "Beta is longer" },
      ],
    },
    budget,
  );
  assert.equal(cut.issues.length, 1);
  assert.equal(cut.snapshotTruncated, true);
});

test("a reply cannot claim the app filed the claim or give a chance", () => {
  assert.equal(
    safeReply("I filed your claim."),
    "I can explain what is saved on this claim. I cannot file it, decide it, or give a chance of approval.",
  );
  assert.equal(
    safeReply("There is a 40% chance."),
    "I can explain what is saved on this claim. I cannot file it, decide it, or give a chance of approval.",
  );
  assert.equal(safeReply("  "), "That is not in this claim yet.");
  assert.equal(
    safeReply("The decision letter is saved on this claim."),
    "The decision letter is saved on this claim.",
  );
});

test("links stay on known screens and known records", () => {
  const snapshot = {
    issues: [{ id: "back", name: "Low back pain" }],
    documents: [{ id: "doc-1", name: "Decision.pdf" }],
  };
  assert.deepEqual(
    acceptedLinks(
      [
        { target: "questions", label: "Questions" },
        { target: "issue", issueId: "missing", label: "Nope" },
        { target: "issue", issueId: "back", label: "Low back pain" },
        { target: "document", documentId: "doc-1" },
        { target: "https://example.com", label: "Outside" },
        { target: "questions", label: "Again" },
      ],
      snapshot,
    ),
    [
      { target: "questions", label: "Questions" },
      { target: "issue", label: "Low back pain", issueId: "back" },
      { target: "document", label: "Decision.pdf", documentId: "doc-1" },
    ],
  );
  assert.deepEqual(
    guardedReply("I filed your claim.", [{ target: "questions" }], snapshot)
      .links,
    [],
  );
});

test("a session closes when its end time is reached", () => {
  const expiresAt = Timestamp.fromMillis(1_000);
  assert.equal(sessionIsOpen(expiresAt, 999), true);
  assert.equal(sessionIsOpen(expiresAt, 1_000), false);
});

test("a follow-up turn stays one user message after the model", () => {
  const contents = modelContents({
    snapshot: { issues: [], documents: [], confirmedStatements: [] },
    snapshotTruncated: false,
    history: [
      { role: "user", content: "What is saved?" },
      { role: "assistant", content: "Low back pain." },
    ],
    question: "Where do I edit it?",
  });
  assert.deepEqual(
    contents.map((turn) => turn.role),
    ["user", "model", "user"],
  );
  assert.equal(contents[0].parts[0].text.includes("What is saved?"), true);
  assert.equal(contents[2].parts[0].text, "Where do I edit it?");
});

function memoryDb() {
  const docs = new Map();
  let seq = 0;
  function docRef(path) {
    return {
      id: path.split("/").pop(),
      path,
      async get() {
        const data = docs.get(path);
        return { exists: data !== undefined, data: () => data };
      },
      async set(data, options) {
        const prev = docs.get(path);
        docs.set(
          path,
          options && options.merge && prev ? { ...prev, ...data } : data,
        );
      },
      collection(name) {
        return collectionRef(`${path}/${name}`);
      },
    };
  }
  function collectionRef(path) {
    return {
      doc(id) {
        return docRef(`${path}/${id || `auto${++seq}`}`);
      },
      where(field, op, value) {
        return {
          async get() {
            const found = [];
            const prefix = `${path}/`;
            for (const [docPath, data] of docs) {
              if (!docPath.startsWith(prefix)) continue;
              const rest = docPath.slice(prefix.length);
              if (rest.includes("/")) continue;
              if (op === "==" && data[field] === value) {
                found.push({ id: rest, data: () => data });
              }
            }
            return { docs: found };
          },
        };
      },
      async add(data) {
        const ref = this.doc();
        await ref.set(data);
        return ref;
      },
    };
  }
  return { doc: (path) => docRef(path), docs };
}

function assistantMessages(db) {
  const rows = [];
  for (const [path, data] of db.docs) {
    if (path.includes("/messages/") && data.role === "assistant") rows.push(data);
  }
  return rows;
}

test("an open session reuses the snapshot and a later one reads the claim again", async () => {
  const db = memoryDb();
  let loads = 0;
  let clock = 0;
  const loaded = {
    issues: [{ id: "back", name: "Low back pain" }],
    documents: [],
    confirmedStatements: [],
    snapshotTruncated: false,
  };
  const calls = [];
  const deps = {
    requireReady: async () => "user-1",
    firestore: db,
    now: () => clock,
    loadSnapshot: async () => {
      loads += 1;
      return loaded;
    },
    generate: async (input) => {
      calls.push(input);
      return {
        reply: "Low back pain is on this claim.",
        links: [
          { target: "issue", issueId: "back", label: "Low back pain" },
          { target: "issue", issueId: "missing", label: "Nope" },
        ],
      };
    },
  };
  const request = { data: { caseId: "case-1", text: "What is saved?" } };
  await askVetBuddyHandler(request, deps);
  clock = 60 * 1000;
  await askVetBuddyHandler(
    { data: { caseId: "case-1", text: "Where do I edit it?" } },
    deps,
  );
  assert.equal(loads, 1);
  assert.equal(calls[1].history.length, 2);
  assert.equal(calls[1].history[0].content, "What is saved?");
  assert.deepEqual(calls[1].snapshot, {
    issues: [{ id: "back", name: "Low back pain" }],
    documents: [],
    confirmedStatements: [],
  });
  assert.deepEqual(assistantMessages(db)[0].links, [
    { target: "issue", label: "Low back pain", issueId: "back" },
  ]);

  clock = 20 * 60 * 1000;
  await askVetBuddyHandler(
    { data: { caseId: "case-1", text: "Start again" } },
    deps,
  );
  assert.equal(loads, 2);
  assert.equal(calls[2].history.length, 0);

  clock += 1000;
  await askVetBuddyHandler(
    { data: { caseId: "case-1", endSession: true } },
    deps,
  );
  clock += 1000;
  await askVetBuddyHandler(
    { data: { caseId: "case-1", text: "After the session ended" } },
    deps,
  );
  assert.equal(loads, 3);
  assert.equal(calls[3].history.length, 0);
  assert.equal(calls.length, 4);
});
