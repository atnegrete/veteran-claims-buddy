const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeCaseName,
  canStartCase,
  CASE_LIMIT,
  resolveWorkingCase,
  OPEN_CASE_NAME,
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
