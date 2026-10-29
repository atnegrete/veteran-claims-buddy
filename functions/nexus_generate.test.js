const test = require("node:test");
const assert = require("node:assert/strict");
const { readPack } = require("./nexus_knowledge");
const {
  generateNexusLettersHandler,
  reviseNexusLetterHandler,
  downloadNexusLetterHandler,
  assembleDoctor,
  assembleVet,
} = require("./nexus_generate");

const pack = readPack();
const statePath = "users/u1/conditions/i1/nexusLetter/current";
const noMatch = { pathways: [] };
const context = {
  condition: "Tinnitus",
  theories: [],
  links: [],
  connectionSource: "noise",
  service: [],
  deployments: [],
  exposures: [],
};

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

function baseDeps(db, over = {}) {
  return {
    requireReady: async () => "u1",
    firestore: db,
    loadNexusContext: async () => context,
    loadIdentity: async () => ({ legalName: "Jane Veteran", vaFileNumber: "A12345678" }),
    matchPresumptive: () => noMatch,
    pack,
    buildDoctorLetterPdf: async () => Buffer.from("DOCTORPDF"),
    buildVetLetterPdf: async () => Buffer.from("VETPDF"),
    ...over,
  };
}

const request = { auth: { uid: "u1" }, data: { caseId: "c1", issueId: "i1" } };

test("generate is blocked until the interview is complete", async () => {
  const db = fakeDb({
    [statePath]: { kind: "direct", interview: { transcript: [], complete: false } },
  });
  await assert.rejects(
    () => generateNexusLettersHandler(request, baseDeps(db)),
    /Answer the questions/i,
  );
});

test("generate renders both letters once the interview is complete", async () => {
  const db = fakeDb({
    [statePath]: {
      kind: "direct",
      interview: {
        transcript: [{ slotId: "reportedDiagnosis", answer: "Tinnitus", resolved: true }],
        complete: true,
      },
      doctorLetter: null,
      vetLetter: null,
    },
  });
  const draft = {
    doctor: {
      recordsReviewed: "r",
      clinicalSummary: "h",
      inServiceBasis: "b",
      suggested: { diagnosis: "d", rationale: "why" },
    },
    veteran: {
      statement: "I ...",
      legalPoints: [{ standardId: "benefitOfDoubt", point: "the tie goes to me" }],
      closing: "Please give this fair consideration.",
      presumptiveNote: "this should be dropped",
    },
  };
  const result = await generateNexusLettersHandler(
    request,
    baseDeps(db, { draft: async () => draft }),
  );
  assert.equal(Buffer.from(result.doctorPdfBase64, "base64").toString(), "DOCTORPDF");
  assert.equal(Buffer.from(result.vetPdfBase64, "base64").toString(), "VETPDF");
  const stored = db.store.get(statePath);
  assert.ok(stored.doctorLetter.sections);
  assert.ok(stored.vetLetter.sections);
  // The presumptive note is dropped when no pathway matched.
  assert.equal(stored.vetLetter.sections.presumptiveNote, "");
});

test("assembleDoctor organizes a clinical summary and injects vetted literature", () => {
  const doctor = assembleDoctor(
    {
      recordsReviewed: "r",
      clinicalSummary: "An organized third-person narrative.",
      inServiceBasis: "b",
      suggested: { diagnosis: "Dx", rationale: "why" },
    },
    context,
    pack,
    "direct",
  );
  assert.equal(doctor.sections.recordsReviewed, "r");
  assert.equal(doctor.sections.clinicalSummary, "An organized third-person narrative.");
  assert.ok(!("reportedHistory" in doctor.sections), "reportedHistory is replaced by clinicalSummary");
  assert.equal(doctor.sections.suggested.diagnosis, "Dx");
  // Tinnitus matches the curated hearing-loss-tinnitus set, so literature is injected.
  assert.ok(
    Array.isArray(doctor.sections.literature) && doctor.sections.literature.length >= 1,
    "medical literature is injected for a matched condition",
  );
  assert.ok(doctor.basis && doctor.basis.length > 0, "basis is passed through for the opinion line");
  assert.ok(!("opinionSuggested" in doctor), "the suggested opinion statement is removed");
});

test("assembleVet keeps only legal points that resolve in the pack", () => {
  const vet = assembleVet(
    {
      statement: "I ...",
      legalPoints: [
        { standardId: "benefitOfDoubt", point: "real point" },
        { standardId: "madeUpRule", point: "fabricated point" },
      ],
      closing: "please consider",
      presumptiveNote: "x",
    },
    context,
    pack,
    noMatch,
  );
  assert.equal(vet.legalPoints.length, 1);
  assert.equal(vet.legalPoints[0].standardId, "benefitOfDoubt");
  assert.ok(vet.legalPoints[0].citation);
  assert.equal(vet.closing, "please consider");
  assert.equal(vet.presumptiveNote, "");
});

test("assembleVet de-duplicates citations that share an authority string", () => {
  // atLeastAsLikelyAsNot and benefitOfDoubt both cite 38 U.S.C. 5107(b); 38 CFR 3.102.
  const vet = assembleVet(
    {
      statement: "I ...",
      legalPoints: [
        { standardId: "atLeastAsLikelyAsNot", point: "fifty percent is enough" },
        { standardId: "benefitOfDoubt", point: "the tie goes to me" },
      ],
      closing: "c",
    },
    { condition: "Back strain" }, // no curated match: only the general legal points
    pack,
    noMatch,
  );
  const strings = vet.citations.map((entry) => entry.citation);
  assert.equal(new Set(strings).size, strings.length, "no citation string prints twice");
  assert.equal(strings.length, 1, "the two standards collapse to one shared authority");
});

test("assembleVet injects the matched condition's vetted legal and medical citations", () => {
  const vet = assembleVet(
    {
      statement: "I ...",
      legalPoints: [{ standardId: "benefitOfDoubt", point: "p" }],
      closing: "c",
    },
    context, // condition "Tinnitus"
    pack,
    noMatch,
  );
  assert.ok(
    vet.citations.some((entry) => entry.kind === "medical"),
    "a medical citation is injected",
  );
  assert.ok(
    vet.citations.some((entry) => /3\.385/.test(entry.citation)),
    "the condition-specific legal citation is injected",
  );
});

test("revise refuses an unknown letter", async () => {
  const db = fakeDb({
    [statePath]: {
      kind: "direct",
      interview: { transcript: [], complete: true },
      doctorLetter: { sections: {} },
    },
  });
  await assert.rejects(
    () =>
      reviseNexusLetterHandler(
        { ...request, data: { ...request.data, letter: "nope", instruction: "shorter" } },
        baseDeps(db),
      ),
    /Unknown letter/i,
  );
});

test("revise is blocked before the letters exist", async () => {
  const db = fakeDb({
    [statePath]: {
      kind: "direct",
      interview: { transcript: [], complete: true },
      doctorLetter: null,
    },
  });
  await assert.rejects(
    () =>
      reviseNexusLetterHandler(
        { ...request, data: { ...request.data, letter: "doctor", instruction: "shorter" } },
        baseDeps(db),
      ),
    /Generate the letters/i,
  );
});

test("download re-renders a stored letter as a clean, print-mode copy", async () => {
  const db = fakeDb({
    [statePath]: {
      kind: "direct",
      interview: { transcript: [], complete: true },
      doctorLetter: {
        sections: {
          recordsReviewed: "r",
          clinicalSummary: "s",
          inServiceBasis: "b",
          suggested: { diagnosis: "d", rationale: "why" },
          literature: [],
        },
      },
      vetLetter: { sections: { statement: "I", citations: [], closing: "c" } },
    },
  });
  let captured = null;
  const result = await downloadNexusLetterHandler(
    { ...request, data: { ...request.data, letter: "doctor" } },
    baseDeps(db, {
      buildDoctorLetterPdf: async (_params, options) => {
        captured = options;
        return Buffer.from("CLEANPDF");
      },
    }),
  );
  assert.equal(Buffer.from(result.pdfBase64, "base64").toString(), "CLEANPDF");
  assert.equal(captured.watermark, false);
  assert.equal(captured.mode, "print");
});

test("download is blocked before the letters exist", async () => {
  const db = fakeDb({
    [statePath]: {
      kind: "direct",
      interview: { transcript: [], complete: true },
      doctorLetter: null,
    },
  });
  await assert.rejects(
    () =>
      downloadNexusLetterHandler(
        { ...request, data: { ...request.data, letter: "doctor" } },
        baseDeps(db),
      ),
    /Generate the letters/i,
  );
});
