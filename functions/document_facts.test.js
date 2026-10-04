const test = require("node:test");
const assert = require("node:assert/strict");
const {
  factsFromModelText,
  shouldStartRead,
  validIsoDate,
} = require("./document_facts");
const { originalDocumentPath } = require("./document_read");

test("a model reply becomes statements and drops inventions that are not usable", () => {
  const parsed = factsFromModelText(
    JSON.stringify({
      facts: [
        {
          factType: "symptom",
          conditionText: "Low back pain",
          factText: "The note says low-back pain after a lifting injury.",
          eventDate: "2011-04-02",
          page: 7,
          confidence: 0.964,
        },
        { factType: "nope", factText: "A finding with an unknown type." },
        { factText: "   " },
        { factType: "diagnosis", factText: "x".repeat(2001) },
      ],
    }),
  );
  assert.equal(parsed.ok, true);
  assert.equal(parsed.facts.length, 2);
  assert.equal(parsed.facts[0].factType, "symptom");
  assert.equal(parsed.facts[0].page, 7);
  assert.equal(parsed.facts[0].eventDate, "2011-04-02");
  assert.equal(parsed.facts[0].confidence, 0.96);
  assert.equal(parsed.facts[1].factType, "other");
  assert.equal(factsFromModelText("not json").ok, false);
  assert.equal(factsFromModelText('{"facts":[]}').facts.length, 0);
  assert.equal(validIsoDate("2011-02-31"), false);
});

test("a finished read is not started again", () => {
  assert.equal(shouldStartRead(null, 0), true);
  assert.equal(shouldStartRead({ status: "failed" }, 0), true);
  assert.equal(shouldStartRead({ status: "needsReview" }, 0), false);
  assert.equal(shouldStartRead({ status: "complete" }, 0), false);
  const recent = {
    status: "processing",
    startedAt: { toMillis: () => 1_000 },
  };
  assert.equal(shouldStartRead(recent, 60_000), false);
  assert.equal(shouldStartRead(recent, 1_000 + 6 * 60 * 1000), true);
});

test("only an original pdf jpeg or png is read", () => {
  assert.deepEqual(
    originalDocumentPath("users/u1/documents/d1/original.pdf"),
    {
      uid: "u1",
      documentId: "d1",
      extension: "pdf",
      contentType: "application/pdf",
    },
  );
  assert.equal(
    originalDocumentPath("users/u1/documents/d1/original.jpg").contentType,
    "image/jpeg",
  );
  assert.equal(
    originalDocumentPath("users/u1/documents/d1/derived/text.json"),
    null,
  );
});
