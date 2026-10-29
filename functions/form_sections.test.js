const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assembleDisabilityExplanation,
  build526ezSection,
  buildSections,
  disabilityExplainField,
  disabilityNameField,
  sectionDraftsFrom,
} = require("./form_sections");

test("assembleDisabilityExplanation joins connection notes and service evidence", () => {
  const text = assembleDisabilityExplanation({
    theories: [{ type: "direct", summary: "Twisted it on a run." }],
    links: [
      { evidenceType: "inServiceEvent", summary: "The run was during training." },
      { evidenceType: "severity", summary: "This note is not used." },
    ],
  });
  assert.equal(
    text,
    "Directly from service. Twisted it on a run. The run was during training.",
  );
});

test("assembleDisabilityExplanation names a secondary path without this-claim wording", () => {
  const text = assembleDisabilityExplanation({
    theories: [{ type: "secondary", summary: "Left knee" }],
  });
  assert.equal(text, "Connected to another condition. Left knee");
});

test("assembleDisabilityExplanation is empty when nothing was recorded", () => {
  assert.equal(
    assembleDisabilityExplanation({
      theories: [{ type: "direct", summary: "  " }],
      links: [{ evidenceType: "nexus", summary: "" }],
    }),
    "",
  );
});

test("build526ezSection writes one row per condition and prefers a reviewed draft", () => {
  const values = build526ezSection({
    issues: [
      { id: "b", displayName: "Back" },
      { id: "a", displayName: "Knee" },
    ],
    theoriesByIssue: {
      b: [{ type: "aggravation", summary: "Got worse after a fall." }],
    },
    linksByIssue: {},
    sectionDrafts: { a: "I reviewed this." },
  });
  assert.equal(values[disabilityNameField(0)], "Back");
  assert.equal(
    values[disabilityExplainField(0)],
    "Made worse in service. Got worse after a fall.",
  );
  assert.equal(values[disabilityNameField(1)], "Knee");
  assert.equal(values[disabilityExplainField(1)], "I reviewed this.");
  assert.equal(Object.keys(values).length, 4);
});

test("build526ezSection leaves the explanation blank when there is no note", () => {
  const values = build526ezSection({
    issues: [{ id: "x", displayName: "Tinnitus" }],
  });
  assert.equal(values[disabilityNameField(0)], "Tinnitus");
  assert.ok(!Object.values(values).some((value) => value.includes("Tinnitus") && value !== "Tinnitus"));
  assert.equal(Object.keys(values).length, 1);
});

test("buildSections is empty for a form with no tailored section", () => {
  assert.deepEqual(buildSections("21-4138", { issues: [{ id: "a", displayName: "Knee" }] }), {});
});

test("sectionDraftsFrom lets a blank live edit clear a saved draft", () => {
  const drafts = sectionDraftsFrom(
    { knee: "Saved.", back: "Keep." },
    { knee: "  ", ankle: "New." },
  );
  assert.deepEqual(drafts, { back: "Keep.", ankle: "New." });
});
