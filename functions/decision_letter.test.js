const test = require("node:test");
const assert = require("node:assert/strict");
const { decisionFromModelText, oneYearAfter } = require("./decision_letter");

test("a letter keeps only what is written", () => {
  const parsed = decisionFromModelText(
    JSON.stringify({
      facts: [],
      decision: {
        decisionDate: "2026-03-01",
        receivedDate: "nope",
        overallSummary: " Service connection for tinnitus is granted. ",
        issues: [
          {
            displayName: "Tinnitus",
            outcome: "granted",
            ratingPercent: 10,
            effectiveDate: "2025-01-01",
            favorableFindings: [{ text: "Noise exposure is conceded.", page: 2 }],
            reasons: [
              {
                text: "The exam linked the noise to the tinnitus.",
                category: "nexus",
                page: 3,
              },
            ],
            evidenceConsidered: ["VA exam"],
            extractionConfidence: 0.91,
          },
          { displayName: "", outcome: "denied" },
        ],
      },
    }),
  );
  assert.equal(parsed.ok, true);
  assert.equal(parsed.decision.receivedDate, null);
  assert.equal(parsed.decision.issues.length, 1);
  assert.equal(parsed.decision.issues[0].ratingPercent, 10);
  assert.equal(parsed.decision.issues[0].favorableFindings[0].page, 2);
});

test("a missing date or a made-up rating is not a decision", () => {
  assert.equal(
    decisionFromModelText(
      JSON.stringify({
        decision: { decisionDate: null, issues: [{ displayName: "Knee" }] },
      }),
    ).ok,
    false,
  );
  const parsed = decisionFromModelText(
    JSON.stringify({
      decision: {
        decisionDate: "2026-03-01",
        issues: [{ displayName: "Knee", outcome: "granted", ratingPercent: 15 }],
      },
    }),
  );
  assert.equal(parsed.decision.issues[0].ratingPercent, null);
  assert.equal(parsed.decision.issues[0].outcome, "granted");
});

test("one year after the decision date is the stored deadline", () => {
  assert.equal(oneYearAfter("2026-03-01").toISOString(), "2027-03-01T00:00:00.000Z");
});
