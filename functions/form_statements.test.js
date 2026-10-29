const test = require("node:test");
const assert = require("node:assert/strict");
const {
  draftFormStatementHandler,
  draftDisabilityExplanationHandler,
  cleanAnswers,
  finalizeStatement,
  parseStatement,
  serviceLine,
  nexusDisclaimer,
} = require("./form_statements");

test("cleanAnswers keeps text and drops blanks", () => {
  const cleaned = cleanAnswers({ a: " hurt my knee ", b: "   " });
  assert.deepEqual(cleaned, { a: "hurt my knee" });
});

test("cleanAnswers refuses a Social Security number", () => {
  assert.throws(() => cleanAnswers({ a: "my ssn is 123-45-6789" }));
});

test("finalizeStatement always appends the nexus disclaimer to a doctor draft", () => {
  const value = finalizeStatement("doctorDraft", "In my opinion the knee is linked to service.");
  assert.ok(value.includes(nexusDisclaimer));
});

test("finalizeStatement leaves a lay statement unchanged", () => {
  const value = finalizeStatement("lay", "My knee hurts every day.");
  assert.equal(value, "My knee hurts every day.");
  assert.ok(!value.includes(nexusDisclaimer));
});

test("parseStatement reads JSON and falls back to prose", () => {
  assert.equal(parseStatement('{"statement":"hi"}'), "hi");
  assert.equal(parseStatement("just prose"), "just prose");
});

test("serviceLine summarizes periods", () => {
  const line = serviceLine([
    { branch: "Army", startDate: "2008-01-01", endDate: "2012-01-01" },
    { branch: "", startDate: "x" },
  ]);
  assert.equal(line, "Army (2008-01-01 to 2012-01-01)");
});

test("the handler drafts a statement through injected dependencies", async () => {
  const result = await draftFormStatementHandler(
    { auth: { uid: "u1" }, data: { caseId: "c1", formNumber: "21-4138", statementKind: "lay", answers: { how: "My back hurts." } } },
    {
      requireReady: async () => "u1",
      firestore: { doc: () => ({ get: async () => ({ exists: false }) }) },
      loadContext: async () => ({ issues: ["Lower back"], service: "Army" }),
      generate: async () => "My back hurts daily.",
    },
  );
  assert.equal(result.statement, "My back hurts daily.");
});

test("draftDisabilityExplanationHandler drafts from saved connection notes", async () => {
  const result = await draftDisabilityExplanationHandler(
    { auth: { uid: "u1" }, data: { caseId: "c1", issueId: "knee" } },
    {
      requireReady: async () => "u1",
      loadIssueFacts: async () => ({
        displayName: "Knee",
        theories: [{ type: "direct", summary: "Twisted it on a run." }],
        links: [],
      }),
      generateExplanation: async ({ condition, source }) => {
        assert.equal(condition, "Knee");
        assert.match(source, /Twisted it on a run/);
        return "I twisted my knee on a run in service.";
      },
    },
  );
  assert.equal(result.statement, "I twisted my knee on a run in service.");
});

test("draftDisabilityExplanationHandler refuses when nothing was recorded", async () => {
  await assert.rejects(
    () =>
      draftDisabilityExplanationHandler(
        { auth: { uid: "u1" }, data: { caseId: "c1", issueId: "knee" } },
        {
          requireReady: async () => "u1",
          loadIssueFacts: async () => ({ displayName: "Knee", theories: [], links: [] }),
          generateExplanation: async () => "should not run",
        },
      ),
    /connects to your service/,
  );
});

test("the handler rejects an unknown statement kind", async () => {
  await assert.rejects(() =>
    draftFormStatementHandler(
      { auth: { uid: "u1" }, data: { caseId: "c1", formNumber: "21-4138", statementKind: "essay", answers: { a: "x" } } },
      { requireReady: async () => "u1" },
    ),
  );
});
