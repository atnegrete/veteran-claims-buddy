const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { VertexAI } = require("@google-cloud/vertexai");
const { assertEnrollmentConfirmed } = require("./auth_state");
const { blockedIdentifier } = require("./vet_buddy");
const { assembleDisabilityExplanation } = require("./form_sections");

const modelName = "gemini-2.5-flash";

const statementKinds = new Set(["lay", "doctorDraft"]);
const maxStatementChars = 8000;
const maxAnswerChars = 4000;
const nexusDisclaimer =
  "This is a draft for your physician to review, edit, and sign only if they agree. It is not a medical opinion and nothing here has been filed with the VA.";

function clip(value, max) {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  return trimmed.length <= max ? trimmed : trimmed.slice(0, max);
}

// Pure: normalize and bound the per-form answers, and reject a Social Security
// number or long account number before it is ever sent to the model.
function cleanAnswers(answers) {
  if (!answers || typeof answers !== "object") return {};
  const cleaned = {};
  let total = 0;
  for (const [key, value] of Object.entries(answers)) {
    if (typeof key !== "string" || typeof value !== "string") continue;
    const text = clip(value, maxAnswerChars);
    if (!text) continue;
    if (blockedIdentifier(text)) {
      throw new HttpsError(
        "invalid-argument",
        "Don't include a Social Security number or a long account number. Those go on the identifiers step, not in a statement.",
      );
    }
    total += text.length;
    if (total > maxAnswerChars * 4) break;
    cleaned[clip(key, 80)] = text;
  }
  return cleaned;
}

function serviceLine(periods) {
  return (periods || [])
    .map((period) => {
      const branch = clip(period.branch, 60);
      const start = clip(period.startDate, 10);
      const end = clip(period.endDate, 10) || "present";
      if (!branch) return "";
      return `${branch} (${start || "?"} to ${end})`;
    })
    .filter(Boolean)
    .join("; ");
}

const instructionsByKind = {
  lay: [
    "You help a U.S. military Veteran (or a witness) write a first-person statement for a VA claim.",
    "Write plainly and honestly in the first person. Be specific but use only the facts provided.",
    "Do not invent dates, diagnoses, events, or quotations that were not provided.",
    "Do not state a medical opinion or a legal conclusion, and do not say anything has been filed with the VA.",
  ].join(" "),
  doctorDraft: [
    "You draft an UNSIGNED nexus letter for a Veteran to bring to their own physician.",
    "It must read as a draft the physician will review, edit, and sign only if they agree.",
    "Use only the facts provided. Do not fabricate findings, test results, or a diagnosis.",
    "Do not present it as a final or signed medical opinion. The physician is the author.",
  ].join(" "),
};

function promptFor({ kind, formNumber, context, answers, nexusKind, reasonText }) {
  const nexusLines = {
    direct:
      "The draft links one condition to the Veteran's military service.",
    secondary:
      "The draft links one condition to another condition the VA already service-connected. Do not link it to an in-service event unless the facts say so.",
    aggravation:
      "The draft is about a condition the Veteran already had that got worse in service.",
    supplemental:
      "The draft is new evidence for a Supplemental Claim or a Board evidence lane. It must address the prior decision. It must not repeat a letter the VA already has.",
  };
  const header = instructionsByKind[kind];
  const facts = {
    formNumber,
    issues: context.issues,
    service: context.service,
    answers,
    nexusKind: nexusKind || "",
    decisionReason: reasonText || "",
  };
  const focus = nexusLines[nexusKind] || "";
  const closing =
    kind === "doctorDraft"
      ? `End the letter with this exact sentence on its own line: "${nexusDisclaimer}"`
      : "Keep it concise. Do not add a signature block.";
  return [header, focus, `Facts you may use (JSON):\n${JSON.stringify(facts)}`, closing, 'Reply with JSON only: {"statement":"..."}.']
    .filter(Boolean)
    .join("\n\n");
}

function parseStatement(text) {
  const raw = typeof text === "string" ? text.trim() : "";
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  const body = start >= 0 && end > start ? raw.slice(start, end + 1) : raw;
  try {
    const data = JSON.parse(body);
    if (data && typeof data.statement === "string") return data.statement;
  } catch (_) {
    // Fall back to the raw prose.
  }
  return raw;
}

// Pure: make sure a doctor draft always carries the disclaimer, and bound size.
function finalizeStatement(kind, text) {
  let value = clip(text, maxStatementChars);
  if (!value) return "";
  if (kind === "doctorDraft" && !value.includes(nexusDisclaimer)) {
    value = clip(`${value}\n\n${nexusDisclaimer}`, maxStatementChars);
  }
  return value;
}

function projectId() {
  return process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
}

function explanationPrompt({ condition, source }) {
  return [
    "You help a U.S. military Veteran explain how one condition relates to service, for the disabilities section of VA Form 21-526EZ.",
    "Write one short paragraph in plain words, in the first person.",
    "Use only the facts provided. Do not invent dates, events, diagnoses, test results, or a medical opinion.",
    "Do not say anything has been filed with the VA.",
    `Condition: ${condition}`,
    `Facts the Veteran already recorded:\n${source}`,
    'Reply with JSON only: {"statement":"..."}.',
  ].join("\n\n");
}

async function completePrompt(prompt) {
  const vertex = new VertexAI({ project: projectId(), location: "us-central1" });
  const model = vertex.getGenerativeModel({
    model: modelName,
    generationConfig: { temperature: 0.3, responseMimeType: "application/json" },
  });
  const result = await model.generateContent({
    contents: [{ role: "user", parts: [{ text: prompt }] }],
  });
  const parts = result.response?.candidates?.[0]?.content?.parts ?? [];
  return parseStatement(parts.map((part) => part.text ?? "").join(""));
}

async function generate({ kind, formNumber, context, answers, nexusKind, reasonText }) {
  return completePrompt(
    promptFor({ kind, formNumber, context, answers, nexusKind, reasonText }),
  );
}

async function generateExplanation({ condition, source }) {
  return completePrompt(explanationPrompt({ condition, source }));
}

async function loadContext(db, uid, caseId) {
  const caseDoc = await db.doc(`users/${uid}/cases/${caseId}`).get();
  if (!caseDoc.exists) return null;
  const [issueSnap, periodSnap] = await Promise.all([
    db
      .collection(`users/${uid}/conditions`)
      .where("activeCaseId", "==", caseId)
      .get(),
    db.collection(`users/${uid}/servicePeriods`).get(),
  ]);
  return {
    issues: issueSnap.docs
      .map((doc) => clip(doc.data().displayName, 120))
      .filter(Boolean),
    service: serviceLine(periodSnap.docs.map((doc) => doc.data())),
  };
}

async function requireReady(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const user = await getAuth().getUser(request.auth.uid);
  if (!assertEnrollmentConfirmed(user).ok) {
    throw new HttpsError(
      "failed-precondition",
      "Verified email and an enrolled text-message check are required.",
    );
  }
  return request.auth.uid;
}

async function draftFormStatementHandler(request, deps = {}) {
  const ready = deps.requireReady ?? requireReady;
  const uid = await ready(request);
  const data = request.data || {};
  const caseId = data.caseId;
  const formNumber = clip(data.formNumber, 20);
  const kind = data.statementKind;
  if (typeof caseId !== "string" || caseId.length < 1 || caseId.length > 128) {
    throw new HttpsError("invalid-argument", "That claim could not be opened.");
  }
  if (!formNumber) {
    throw new HttpsError("invalid-argument", "That form could not be opened.");
  }
  if (!statementKinds.has(kind)) {
    throw new HttpsError("invalid-argument", "Unknown statement kind.");
  }
  const answers = cleanAnswers(data.answers);
  if (Object.keys(answers).length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Answer at least one question before drafting.",
    );
  }
  const db = deps.firestore ?? getFirestore();
  const account = await db.doc(`users/${uid}`).get();
  if (account.exists && account.data().accountStatus === "deletionScheduled") {
    throw new HttpsError(
      "failed-precondition",
      "This account is scheduled for deletion.",
    );
  }
  const load = deps.loadContext ?? loadContext;
  const context = await load(db, uid, caseId);
  if (!context) {
    throw new HttpsError("not-found", "That claim is not on this account.");
  }
  let text;
  try {
    text = await (deps.generate ?? generate)({
      kind,
      formNumber,
      context,
      answers,
      nexusKind: clip(typeof data.nexusKind === "string" ? data.nexusKind : "", 40),
      reasonText: clip(typeof data.reasonText === "string" ? data.reasonText : "", 2000),
    });
  } catch (error) {
    console.error("draft statement failed");
    throw new HttpsError("internal", "The draft could not be written. Try again.");
  }
  return { statement: finalizeStatement(kind, text) };
}

async function loadIssueFacts(db, uid, caseId, issueId) {
  const issueDoc = await db.doc(`users/${uid}/conditions/${issueId}`).get();
  if (!issueDoc.exists) return null;
  const issue = issueDoc.data();
  if (issue.activeCaseId !== caseId) return null;
  const [theorySnap, linkSnap] = await Promise.all([
    db.collection(`users/${uid}/conditions/${issueId}/theories`).get(),
    db
      .collection(`users/${uid}/evidenceLinks`)
      .where("conditionId", "==", issueId)
      .get(),
  ]);
  return {
    displayName: clip(issue.displayName, 120),
    theories: theorySnap.docs.map((doc) => ({
      type: doc.data().type,
      summary: doc.data().summary,
    })),
    links: linkSnap.docs.map((doc) => ({
      evidenceType: doc.data().evidenceType,
      summary: doc.data().summary,
    })),
  };
}

// Drafts the free-text "how this condition relates to service" cell for one
// claimed condition, using only the connection notes and evidence already
// saved. Refuses when there is nothing to draw from.
async function draftDisabilityExplanationHandler(request, deps = {}) {
  const ready = deps.requireReady ?? requireReady;
  const uid = await ready(request);
  const data = request.data || {};
  const caseId = data.caseId;
  const issueId = clip(data.issueId, 128);
  if (typeof caseId !== "string" || caseId.length < 1 || caseId.length > 128) {
    throw new HttpsError("invalid-argument", "That claim could not be opened.");
  }
  if (!issueId) {
    throw new HttpsError("invalid-argument", "That condition could not be opened.");
  }
  const facts = deps.loadIssueFacts
    ? await deps.loadIssueFacts(deps.firestore, uid, caseId, issueId)
    : await loadIssueFacts(deps.firestore ?? getFirestore(), uid, caseId, issueId);
  if (!facts) {
    throw new HttpsError("not-found", "That condition is not on this claim.");
  }
  const source = assembleDisabilityExplanation(facts);
  if (!source) {
    throw new HttpsError(
      "failed-precondition",
      "Add how this condition connects to your service before drafting.",
    );
  }
  if (blockedIdentifier(source) || blockedIdentifier(facts.displayName)) {
    throw new HttpsError(
      "invalid-argument",
      "Don't include a Social Security number or a long account number.",
    );
  }
  let text;
  try {
    text = await (deps.generateExplanation ?? generateExplanation)({
      condition: facts.displayName,
      source,
    });
  } catch (error) {
    console.error("disability explanation draft failed");
    throw new HttpsError("internal", "The draft could not be written. Try again.");
  }
  const statement = finalizeStatement("lay", text);
  if (!statement) {
    throw new HttpsError("internal", "The draft came back empty. Try again.");
  }
  return { statement };
}

const draftDisabilityExplanation = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  (request) => draftDisabilityExplanationHandler(request),
);

const draftFormStatement = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  (request) => draftFormStatementHandler(request),
);

module.exports = {
  draftFormStatement,
  draftFormStatementHandler,
  draftDisabilityExplanation,
  draftDisabilityExplanationHandler,
  explanationPrompt,
  cleanAnswers,
  finalizeStatement,
  parseStatement,
  serviceLine,
  nexusDisclaimer,
};
