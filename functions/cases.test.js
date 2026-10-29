const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeCaseName,
  canStartCase,
  CASE_LIMIT,
  resolveWorkingCase,
  OPEN_CASE_NAME,
  caseIsOpen,
  countsTowardCaseLimit,
  caseUnlockLimitReached,
  classifyCaseDecision,
} = require("./cases");

test("a case name is trimmed and kept to 80 characters", () => {
  assert.deepEqual(normalizeCaseName("  Back   claim  "), {
    ok: true,
    name: "Back claim",
  });
  assert.equal(normalizeCaseName("   ").ok, false);
  assert.equal(normalizeCaseName("x".repeat(81)).ok, false);
  assert.equal(normalizeCaseName(12).ok, false);
});

test("an account with no open case gets one created", () => {
  assert.deepEqual(resolveWorkingCase([], null), { create: true });
  assert.deepEqual(
    resolveWorkingCase([{ id: "old", status: "archived" }], "old"),
    { create: true },
  );
  assert.equal(OPEN_CASE_NAME, "Open Case");
});

test("an existing open case is reused", () => {
  const cases = [
    { id: "case-1", status: "draft" },
    { id: "case-2", status: "draft" },
  ];
  assert.deepEqual(resolveWorkingCase(cases, "case-2"), {
    create: false,
    caseId: "case-2",
  });
  assert.deepEqual(resolveWorkingCase(cases, null), {
    create: false,
    caseId: "case-1",
  });
});

test("twelve open cases is the limit and archived cases do not count", () => {
  const open = Array.from({ length: CASE_LIMIT }, () => ({ status: "draft" }));
  assert.equal(canStartCase(open), false);
  assert.equal(
    canStartCase([...open.slice(0, CASE_LIMIT - 1), { status: "archived" }]),
    true,
  );
  assert.equal(canStartCase([{ status: "awaitingVA" }]), true);
});

test("completed and archived cases are not open and do not count to the limit", () => {
  assert.equal(caseIsOpen("draft"), true);
  assert.equal(caseIsOpen("completed"), false);
  assert.equal(caseIsOpen("archived"), false);
  assert.equal(countsTowardCaseLimit("completed"), false);
  assert.equal(countsTowardCaseLimit("archived"), false);
  assert.equal(countsTowardCaseLimit("draft"), true);
});

test("the single-case limit applies only to case-unlock premium with an open case", () => {
  const openCase = [{ status: "draft" }];
  // No premium yet: the free workspace is not limited here.
  assert.equal(caseUnlockLimitReached(null, openCase), false);
  // A subscription lifts the limit.
  assert.equal(
    caseUnlockLimitReached({ source: "subscription", isActive: true }, openCase),
    false,
  );
  // Case-unlock premium with an open case blocks another.
  assert.equal(
    caseUnlockLimitReached({ source: "caseUnlock", isActive: true }, openCase),
    true,
  );
  // Once the only case is completed, another may start.
  assert.equal(
    caseUnlockLimitReached({ source: "caseUnlock", isActive: true }, [
      { status: "completed" },
    ]),
    false,
  );
});

test("classifyCaseDecision: full denial or reduction may appeal", () => {
  assert.deepEqual(classifyCaseDecision([{ outcome: "denied" }]), {
    appealEligible: true,
    pending: false,
  });
  assert.deepEqual(
    classifyCaseDecision([{ outcome: "granted" }, { outcome: "reduced" }]),
    { appealEligible: true, pending: false },
  );
});

test("classifyCaseDecision: a grant or increase is complete-only", () => {
  assert.deepEqual(
    classifyCaseDecision([{ outcome: "granted" }, { outcome: "denied" }]),
    { appealEligible: false, pending: false },
  );
  assert.deepEqual(classifyCaseDecision([{ outcome: "increased" }]), {
    appealEligible: false,
    pending: false,
  });
});

test("classifyCaseDecision: an all-deferred or empty decision stays pending", () => {
  assert.deepEqual(classifyCaseDecision([{ outcome: "deferred" }]), {
    appealEligible: false,
    pending: true,
  });
  assert.deepEqual(classifyCaseDecision([]), {
    appealEligible: false,
    pending: true,
  });
});
