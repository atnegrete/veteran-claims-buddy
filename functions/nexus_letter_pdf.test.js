const test = require("node:test");
const assert = require("node:assert/strict");
const { PDFDocument, StandardFonts } = require("pdf-lib");
const {
  buildDoctorLetterPdf,
  buildVetLetterPdf,
  sanitize,
  wrapParagraph,
} = require("./nexus_letter_pdf");

test("sanitize folds smart punctuation and drops non-WinAnsi characters", () => {
  assert.equal(sanitize("\u201Chi\u201D \u2014 it\u2019s fine\u2026"), '"hi" - it\'s fine...');
  assert.equal(sanitize("ok\u{1F600}"), "ok");
  assert.equal(sanitize(42), "");
});

test("wrapParagraph wraps to the pixel width and keeps blank lines", async () => {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.TimesRoman);
  const wrapped = wrapParagraph("one two three four five six seven eight", font, 11, 40);
  assert.ok(wrapped.length > 1, "a narrow width should wrap to several lines");
  assert.deepEqual(wrapParagraph("a\n\nb", font, 11, 400), ["a", "", "b"]);
});

const doctorParams = {
  identity: { legalName: "Jane Veteran", vaFileNumber: "A12345678" },
  condition: "Tinnitus",
  branch: "Army",
  sections: {
    recordsReviewed: "The veteran's reported history was reviewed.",
    clinicalSummary: "The veteran reports ringing in the ears beginning in service and continuing since.",
    inServiceBasis: "The veteran reports exposure to artillery noise.",
    suggested: {
      diagnosis: "Bilateral tinnitus.",
      rationale: "Noise exposure is a recognized cause of tinnitus.",
    },
    literature: [
      {
        citation: "Yankaskas, K. (2013). Hearing Research, 295, 3-8.",
        description: "Links military noise exposure to tinnitus.",
      },
    ],
  },
  basis: "the in-service event, injury, or exposure",
  disclaimer: "Draft only. Nothing here has been filed with the VA.",
};

const vetParams = {
  identity: { legalName: "Jane Veteran", vaFileNumber: "A12345678" },
  condition: "Tinnitus",
  branch: "Army",
  sections: {
    statement: "I have had ringing in my ears since my time in service.",
    citations: [
      { citation: "38 CFR 3.102", description: "The tie goes to me.", kind: "legal" },
      {
        citation: "Yankaskas, K. (2013). Hearing Research, 295, 3-8.",
        description: "Links military noise exposure to tinnitus.",
        kind: "medical",
      },
    ],
    closing: "I respectfully ask for fair and thorough consideration of the evidence.",
    presumptiveNote: "",
    presumptiveCitation: "",
  },
  disclaimer: "Draft only. Nothing here has been filed with the VA.",
};

test("buildDoctorLetterPdf returns a multi-page PDF including the suggested page", async () => {
  const bytes = await buildDoctorLetterPdf(doctorParams);
  assert.ok(bytes && bytes.length > 0);
  assert.equal(Buffer.from(bytes.slice(0, 5)).toString("latin1"), "%PDF-");
  const doc = await PDFDocument.load(bytes);
  assert.ok(doc.getPageCount() >= 2, "the doctor letter appends a suggested-draft page");
});

test("buildVetLetterPdf returns a PDF", async () => {
  const bytes = await buildVetLetterPdf(vetParams);
  assert.ok(bytes && bytes.length > 0);
  assert.equal(Buffer.from(bytes.slice(0, 5)).toString("latin1"), "%PDF-");
  const doc = await PDFDocument.load(bytes);
  assert.ok(doc.getPageCount() >= 1);
});

test("preview and print modes render different content for the fill-in sections", async () => {
  const preview = await buildDoctorLetterPdf(doctorParams, { mode: "preview" });
  const print = await buildDoctorLetterPdf(doctorParams, { mode: "print" });
  // Preview shows the "to be completed" placeholder; print leaves ruled blank
  // space instead, so the two renderings differ.
  assert.notEqual(
    Buffer.from(preview).toString("latin1"),
    Buffer.from(print).toString("latin1"),
  );
  assert.equal(Buffer.from(print.slice(0, 5)).toString("latin1"), "%PDF-");
});
