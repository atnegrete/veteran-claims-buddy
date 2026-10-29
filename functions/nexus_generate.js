// Generates and revises the two Nexus Letters for one condition. Gated on a
// complete interview. One grounded Gemini call drafts structured sections for
// both letters; the physician letter never asserts a diagnosis or opinion, and
// the veteran statement cites only standards from the pack. A revise call
// applies one natural-language tweak to one letter. Nothing files with the VA.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const {
  loadNexusContext,
  matchPresumptive,
  conditionCitationsFor,
  normalize,
} = require("./nexus_letter");
const { loadPack, standardsByIds, patternFor } = require("./nexus_knowledge");
const { nexusDisclaimer } = require("./form_statements");
const { blockedIdentifier } = require("./vet_buddy");
const { buildDoctorLetterPdf, buildVetLetterPdf } = require("./nexus_letter_pdf");
const shared = require("./nexus_shared");

const vetDisclaimer =
  "This statement was prepared with an automated tool from information you provided. Read it, correct anything that is wrong, and sign it only if it is true. It is general information, not legal or medical advice, and nothing here has been filed with the VA.";

const letters = new Set(["doctor", "veteran"]);

// Pure: the grounding block shared by the generate and revise prompts.
function groundingBlock(context, pack, nexusKind, answered, matches) {
  const pattern = patternFor(pack, nexusKind);
  const basis = pattern.basisDescription;
  const standards = standardsByIds(pack, pattern.standardIds).map((standard) => ({
    id: standard.id,
    plainText: standard.plainText,
  }));
  const presumptive = matches.pathways.map((pathway) => ({
    id: pathway.id,
    label: pathway.label,
    citation: pathway.citation,
    mayCoverThisCondition: pathway.conditionMatch,
  }));
  const facts = {
    condition: context.condition,
    nexusKind,
    basis,
    service: context.service,
    deployments: context.deployments,
    exposures: context.exposures,
    connectionNotes: context.connectionSource,
    interviewAnswers: answered,
  };
  return [
    `Facts (JSON):\n${JSON.stringify(facts)}`,
    `Legal standards you may rely on (JSON; use the ids exactly):\n${JSON.stringify(standards)}`,
    `Presumptive pathways relevant to this veteran (JSON; empty means none):\n${JSON.stringify(presumptive)}`,
  ].join("\n\n");
}

const doctorRules = [
  "DOCTOR letter (an unsigned draft a physician will review, complete, and sign only if they agree):",
  "Write about the veteran in the third person ('The veteran reports ...', 'The veteran served ...').",
  "- recordsReviewed: one or two sentences naming, in general terms, the history and records available to review (the veteran's reported history and any records the veteran named). Do not claim records that were not provided.",
  "- clinicalSummary: an organized, factual narrative (prose, not a list) a clinician can build on. When the facts support it, cover the onset and course of the condition, whether symptoms have continued since service, the functional impact the veteran describes, and the context of any treatment or records. ORGANIZE the facts into clear connected prose; do NOT merely restate the interview answers one by one, and do NOT add facts that were not provided. Use several sentences, not a single line.",
  "- inServiceBasis: the reported in-service event, exposure, worsening, or service-connected condition, in the third person, with any date or place the veteran gave. Report only.",
  "- Do NOT state a diagnosis, a medical rationale, or an opinion anywhere in recordsReviewed, clinicalSummary, or inServiceBasis. Those are completed by the physician.",
  "- suggested.diagnosis and suggested.rationale: optional language the physician MAY adopt, each phrased as a suggestion a clinician would confirm. Keep them grounded in the facts. suggested.rationale may give brief clinical reasoning for why the condition could be linked to the in-service basis.",
].join("\n");

const vetRules = [
  "VETERAN statement (a statement the veteran signs):",
  "- statement: first person ('I ...'), plain and honest: the veteran's account and why they believe it connects to service. Do NOT assert a medical diagnosis, EXCEPT to repeat what the veteran said a provider told them (for example 'My doctor told me ...').",
  "- legalPoints: 2 to 4 items, each {standardId, point}. standardId MUST be one of the provided standard ids, and every item MUST use a DIFFERENT standardId (never repeat a standard). point explains that standard in plain words tied to THIS claim. Do not cite any rule that was not provided.",
  "- closing: 2 to 4 sentences for a 'Closing Remarks' paragraph. Briefly summarize the claim, respectfully ask the VA for fair and thorough consideration of the evidence, and affirm that the statements are true and correct to the best of the veteran's knowledge. First person. Do not restate the whole statement.",
  "- presumptiveNote: one or two sentences ONLY if a presumptive pathway is provided and may cover this condition; otherwise an empty string.",
].join("\n");

function generatePrompt(context, pack, nexusKind, answered, matches) {
  return [
    "You prepare the content for two documents for a U.S. military veteran's VA claim about ONE condition.",
    "Use ONLY the facts provided. Do not invent diagnoses, test results, records, dates, events, or findings.",
    groundingBlock(context, pack, nexusKind, answered, matches),
    doctorRules,
    vetRules,
    'Reply with JSON only: {"doctor":{"recordsReviewed":"","clinicalSummary":"","inServiceBasis":"","suggested":{"diagnosis":"","rationale":""}},"veteran":{"statement":"","legalPoints":[{"standardId":"","point":""}],"closing":"","presumptiveNote":""}}.',
  ].join("\n\n");
}

function revisePrompt(letter, current, instruction, context, pack, nexusKind, answered, matches) {
  const schema =
    letter === "doctor"
      ? '{"recordsReviewed":"","clinicalSummary":"","inServiceBasis":"","suggested":{"diagnosis":"","rationale":""}}'
      : '{"statement":"","legalPoints":[{"standardId":"","point":""}],"closing":"","presumptiveNote":""}';
  const rules = letter === "doctor" ? doctorRules : vetRules;
  return [
    `You revise the ${letter === "doctor" ? "physician letter" : "veteran statement"} for a VA claim about ONE condition.`,
    "Apply the veteran's requested change. Keep every rule below. Use ONLY the facts provided; do not invent anything.",
    "If the request asks for something the rules forbid (for example, asserting a diagnosis in the physician letter, or citing a rule that was not provided), keep the document within the rules.",
    groundingBlock(context, pack, nexusKind, answered, matches),
    rules,
    `Current content (JSON):\n${JSON.stringify(current)}`,
    `Requested change:\n${instruction}`,
    `Reply with JSON only in this shape: ${schema}.`,
  ].join("\n\n");
}

// Pure: drop entries without a citation and collapse repeats by normalized
// citation string (keep the first), so the same authority never prints twice.
function dedupeCitations(entries) {
  const seen = new Set();
  const out = [];
  for (const entry of Array.isArray(entries) ? entries : []) {
    const citation = entry && typeof entry.citation === "string" ? entry.citation : "";
    if (!citation) continue;
    const key = normalize(citation);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(entry);
  }
  return out;
}

// Pure: the distinct branches of service for the letter header.
function branchOfService(context) {
  const branches = [];
  for (const period of (context && context.service) || []) {
    const branch = shared.clip(period.branch, 60);
    if (branch && !branches.includes(branch)) branches.push(branch);
  }
  return branches.join(", ");
}

// Pure: validate and bound the model's doctor content. The diagnosis, rationale,
// and opinion stay out of the body; the matched condition's vetted medical
// literature is injected (not written by the model).
function assembleDoctor(raw, context, pack, nexusKind) {
  const doctor = raw && typeof raw === "object" ? raw : {};
  const suggested = doctor.suggested && typeof doctor.suggested === "object" ? doctor.suggested : {};
  const pattern = patternFor(pack, nexusKind);
  const basis = pattern.basisDescription;
  const literature = dedupeCitations(conditionCitationsFor(context, pack).medical);
  return {
    sections: {
      recordsReviewed: shared.clip(doctor.recordsReviewed, 3000),
      clinicalSummary: shared.clip(doctor.clinicalSummary, 4000),
      inServiceBasis: shared.clip(doctor.inServiceBasis, 3000),
      suggested: {
        diagnosis: shared.clip(suggested.diagnosis, 1500),
        rationale: shared.clip(suggested.rationale, 3000),
      },
      literature,
    },
    basis,
  };
}

// Pure: validate and bound the model's veteran content. The general legal
// standards the model picked (de-duplicated by id) plus the matched condition's
// vetted legal and medical citations become one de-duplicated "Legal & Medical
// Citations" list; the model never writes a citation string.
function assembleVet(raw, context, pack, matches) {
  const vet = raw && typeof raw === "object" ? raw : {};
  const standards = pack.standards || {};
  const seenIds = new Set();
  const legalPoints = (Array.isArray(vet.legalPoints) ? vet.legalPoints : [])
    .map((point) => ({
      standardId: typeof point.standardId === "string" ? point.standardId : "",
      point: shared.clip(point.point, 1200),
    }))
    .filter((point) => {
      if (!point.point || !standards[point.standardId]) return false;
      if (seenIds.has(point.standardId)) return false;
      seenIds.add(point.standardId);
      return true;
    })
    .slice(0, 4)
    .map((point) => ({ ...point, citation: standards[point.standardId].citation }));

  const curated = conditionCitationsFor(context, pack);
  const citations = dedupeCitations([
    ...legalPoints.map((point) => ({
      citation: point.citation,
      description: point.point,
      kind: "legal",
    })),
    ...curated.legal.map((entry) => ({ ...entry, kind: "legal" })),
    ...curated.medical.map((entry) => ({ ...entry, kind: "medical" })),
  ]).slice(0, 6);

  const strong = matches.pathways.find((pathway) => pathway.conditionMatch) || null;
  return {
    statement: shared.clip(vet.statement, 6000),
    legalPoints,
    citations,
    closing: shared.clip(vet.closing, 1500),
    presumptiveNote: strong ? shared.clip(vet.presumptiveNote, 800) : "",
    presumptiveCitation: strong ? strong.citation : "",
  };
}

function doctorParams(identity, context, doctor) {
  return {
    identity,
    condition: context.condition,
    branch: branchOfService(context),
    sections: doctor.sections,
    basis: doctor.basis,
    disclaimer: nexusDisclaimer,
  };
}

function vetParams(identity, context, vet) {
  return {
    identity,
    condition: context.condition,
    branch: branchOfService(context),
    sections: vet,
    disclaimer: vetDisclaimer,
  };
}

async function requireCondition(request, deps) {
  const uid = await (deps.requireReady ?? shared.requireReady)(request);
  const data = request.data || {};
  const caseId = data.caseId;
  const issueId = shared.clip(data.issueId, 128);
  if (typeof caseId !== "string" || caseId.length < 1 || caseId.length > 128) {
    throw new HttpsError("invalid-argument", "That claim could not be opened.");
  }
  if (!issueId) {
    throw new HttpsError("invalid-argument", "That condition could not be opened.");
  }
  const db = deps.firestore ?? getFirestore();
  const account = await db.doc(`users/${uid}`).get();
  if (account.exists && account.data().accountStatus === "deletionScheduled") {
    throw new HttpsError("failed-precondition", "This account is scheduled for deletion.");
  }
  const context = await (deps.loadNexusContext ?? loadNexusContext)(db, uid, caseId, issueId);
  if (!context) {
    throw new HttpsError("not-found", "That condition is not on this claim.");
  }
  if (blockedIdentifier(context.condition)) {
    throw new HttpsError(
      "invalid-argument",
      "Don't include a Social Security number or a long account number.",
    );
  }
  return { uid, db, caseId, issueId, context };
}

async function generateNexusLettersHandler(request, deps = {}) {
  const { uid, db, issueId, context } = await requireCondition(request, deps);
  const ref = db.doc(shared.stateDocPath(uid, issueId));
  const snap = await ref.get();
  const state = snap.exists ? snap.data() : null;
  if (!state || !state.interview || state.interview.complete !== true) {
    throw new HttpsError("failed-precondition", "Answer the questions before the letters are generated.");
  }
  const nexusKind = shared.clip(state.kind, 40) || "direct";
  const answered = shared.answeredFrom(state.interview.transcript);
  const pack = deps.pack ?? loadPack();
  const matches = (deps.matchPresumptive ?? matchPresumptive)(context, pack);
  const identity = await (deps.loadIdentity ?? shared.loadIdentity)(db, uid);

  let draft;
  try {
    draft = await (deps.draft ?? ((prompt) => shared.completeDraftJson(prompt)))(
      generatePrompt(context, pack, nexusKind, answered, matches),
    );
  } catch (error) {
    console.error("nexus generate failed", error);
    throw new HttpsError("internal", "The letters could not be written. Try again.");
  }
  const doctor = assembleDoctor(draft && draft.doctor, context, pack, nexusKind);
  const vet = assembleVet(draft && draft.veteran, context, pack, matches);

  const [doctorBytes, vetBytes] = await Promise.all([
    (deps.buildDoctorLetterPdf ?? buildDoctorLetterPdf)(
      doctorParams(identity, context, doctor),
      { watermark: true, mode: "preview" },
    ),
    (deps.buildVetLetterPdf ?? buildVetLetterPdf)(vetParams(identity, context, vet), {
      watermark: true,
      mode: "preview",
    }),
  ]);

  await ref.set(
    {
      doctorLetter: { sections: doctor.sections },
      vetLetter: { sections: vet },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    doctorPdfBase64: Buffer.from(doctorBytes).toString("base64"),
    vetPdfBase64: Buffer.from(vetBytes).toString("base64"),
  };
}

async function reviseNexusLetterHandler(request, deps = {}) {
  const { uid, db, issueId, context } = await requireCondition(request, deps);
  const data = request.data || {};
  const letter = shared.clip(typeof data.letter === "string" ? data.letter : "", 20);
  if (!letters.has(letter)) {
    throw new HttpsError("invalid-argument", "Unknown letter.");
  }
  const instruction = shared.clip(data.instruction, shared.maxInstructionChars);
  if (!instruction) {
    throw new HttpsError("invalid-argument", "Say what to change.");
  }
  if (blockedIdentifier(instruction)) {
    throw new HttpsError(
      "invalid-argument",
      "Don't include a Social Security number or a long account number.",
    );
  }
  const ref = db.doc(shared.stateDocPath(uid, issueId));
  const snap = await ref.get();
  const state = snap.exists ? snap.data() : null;
  const stored =
    state && (letter === "doctor" ? state.doctorLetter : state.vetLetter);
  if (!stored || !stored.sections) {
    throw new HttpsError("failed-precondition", "Generate the letters before asking for a change.");
  }
  const nexusKind = shared.clip(state.kind, 40) || "direct";
  const answered = shared.answeredFrom(state.interview && state.interview.transcript);
  const pack = deps.pack ?? loadPack();
  const matches = (deps.matchPresumptive ?? matchPresumptive)(context, pack);
  const identity = await (deps.loadIdentity ?? shared.loadIdentity)(db, uid);

  const current =
    letter === "doctor"
      ? {
          recordsReviewed: stored.sections.recordsReviewed,
          clinicalSummary: stored.sections.clinicalSummary,
          inServiceBasis: stored.sections.inServiceBasis,
          suggested: stored.sections.suggested,
        }
      : {
          statement: stored.sections.statement,
          legalPoints: stored.sections.legalPoints,
          closing: stored.sections.closing,
          presumptiveNote: stored.sections.presumptiveNote,
        };

  let revised;
  try {
    revised = await (deps.draft ?? ((prompt) => shared.completeDraftJson(prompt)))(
      revisePrompt(letter, current, instruction, context, pack, nexusKind, answered, matches),
    );
  } catch (error) {
    console.error("nexus revise failed", error);
    throw new HttpsError("internal", "The change could not be made. Try again.");
  }

  let pdfBase64;
  if (letter === "doctor") {
    const doctor = assembleDoctor(revised, context, pack, nexusKind);
    const bytes = await (deps.buildDoctorLetterPdf ?? buildDoctorLetterPdf)(
      doctorParams(identity, context, doctor),
      { watermark: true, mode: "preview" },
    );
    await ref.set(
      { doctorLetter: { sections: doctor.sections }, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    pdfBase64 = Buffer.from(bytes).toString("base64");
  } else {
    const vet = assembleVet(revised, context, pack, matches);
    const bytes = await (deps.buildVetLetterPdf ?? buildVetLetterPdf)(
      vetParams(identity, context, vet),
      { watermark: true, mode: "preview" },
    );
    await ref.set(
      { vetLetter: { sections: vet }, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    pdfBase64 = Buffer.from(bytes).toString("base64");
  }
  return { letter, pdfBase64 };
}

// Re-renders one already-generated letter as a clean, unwatermarked, print-mode
// PDF for the Veteran to keep. It writes nothing; it reads the server-owned
// stored sections and the saved facts.
async function downloadNexusLetterHandler(request, deps = {}) {
  const { uid, db, issueId, context } = await requireCondition(request, deps);
  const data = request.data || {};
  const letter = shared.clip(typeof data.letter === "string" ? data.letter : "", 20);
  if (!letters.has(letter)) {
    throw new HttpsError("invalid-argument", "Unknown letter.");
  }
  const ref = db.doc(shared.stateDocPath(uid, issueId));
  const snap = await ref.get();
  const state = snap.exists ? snap.data() : null;
  const stored = state && (letter === "doctor" ? state.doctorLetter : state.vetLetter);
  if (!stored || !stored.sections) {
    throw new HttpsError("failed-precondition", "Generate the letters before downloading a copy.");
  }
  const nexusKind = shared.clip(state.kind, 40) || "direct";
  const pack = deps.pack ?? loadPack();
  const identity = await (deps.loadIdentity ?? shared.loadIdentity)(db, uid);

  let bytes;
  if (letter === "doctor") {
    const basis = patternFor(pack, nexusKind).basisDescription;
    bytes = await (deps.buildDoctorLetterPdf ?? buildDoctorLetterPdf)(
      doctorParams(identity, context, { sections: stored.sections, basis }),
      { watermark: false, mode: "print" },
    );
  } else {
    bytes = await (deps.buildVetLetterPdf ?? buildVetLetterPdf)(
      vetParams(identity, context, stored.sections),
      { watermark: false, mode: "print" },
    );
  }
  return { letter, pdfBase64: Buffer.from(bytes).toString("base64") };
}

const generateNexusLetters = onCall(
  { timeoutSeconds: 180, memory: "1GiB" },
  (request) => generateNexusLettersHandler(request),
);

const reviseNexusLetter = onCall(
  { timeoutSeconds: 180, memory: "1GiB" },
  (request) => reviseNexusLetterHandler(request),
);

const downloadNexusLetter = onCall(
  { timeoutSeconds: 120, memory: "1GiB" },
  (request) => downloadNexusLetterHandler(request),
);

module.exports = {
  generateNexusLetters,
  generateNexusLettersHandler,
  reviseNexusLetter,
  reviseNexusLetterHandler,
  downloadNexusLetter,
  downloadNexusLetterHandler,
  generatePrompt,
  revisePrompt,
  assembleDoctor,
  assembleVet,
  vetDisclaimer,
};
