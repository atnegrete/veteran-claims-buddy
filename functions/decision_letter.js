const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { rules: vaRules } = require("./va_rules");
const { validIsoDate } = require("./document_facts");

const outcomes = new Set([
  "granted",
  "denied",
  "deferred",
  "increased",
  "continued",
  "reduced",
  "other",
]);

const reasonCategories = new Set([
  "nexus",
  "diagnosis",
  "inServiceEvent",
  "severity",
  "other",
]);

const summaryMax = 2000;
const nameMax = 120;
const findingMax = 2000;
const reasonMax = 2000;
const evidenceMax = 200;

function clip(value, max) {
  if (typeof value !== "string") return "";
  const text = value.trim().replace(/\s+/g, " ");
  if (!text) return "";
  return text.length > max ? text.slice(0, max) : text;
}

function pageOf(value) {
  return Number.isInteger(value) && value > 0 && value <= 2000 ? value : null;
}

function ratingOf(value) {
  return Number.isInteger(value) && value >= 0 && value <= 100 && value % 10 === 0
    ? value
    : null;
}

function findingsFrom(raw) {
  if (!Array.isArray(raw)) return [];
  const findings = [];
  for (const item of raw) {
    const text = clip(item && item.text, findingMax);
    if (!text) continue;
    findings.push({ text, page: pageOf(item.page) });
    if (findings.length === 8) break;
  }
  return findings;
}

function reasonsFrom(raw) {
  if (!Array.isArray(raw)) return [];
  const reasons = [];
  for (const item of raw) {
    const text = clip(item && item.text, reasonMax);
    if (!text) continue;
    reasons.push({
      text,
      category: reasonCategories.has(item.category) ? item.category : "other",
      page: pageOf(item && item.page),
    });
    if (reasons.length === 8) break;
  }
  return reasons;
}

function evidenceFrom(raw) {
  if (!Array.isArray(raw)) return [];
  const evidence = [];
  for (const item of raw) {
    const text = clip(item, evidenceMax);
    if (!text) continue;
    evidence.push(text);
    if (evidence.length === 8) break;
  }
  return evidence;
}

function decisionFromModelText(text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { ok: false };
  }
  const decision =
    parsed && parsed.decision && typeof parsed.decision === "object"
      ? parsed.decision
      : null;
  if (!decision || Array.isArray(decision)) return { ok: false };
  const decisionDate = validIsoDate(decision.decisionDate)
    ? decision.decisionDate
    : null;
  if (!decisionDate) return { ok: false };
  const issues = [];
  const rawIssues = Array.isArray(decision.issues) ? decision.issues : [];
  for (const item of rawIssues) {
    if (!item || typeof item !== "object") continue;
    const displayName = clip(item.displayName, nameMax);
    if (!displayName) continue;
    const confidence =
      typeof item.extractionConfidence === "number" &&
      Number.isFinite(item.extractionConfidence) &&
      item.extractionConfidence >= 0 &&
      item.extractionConfidence <= 1
        ? Math.round(item.extractionConfidence * 100) / 100
        : null;
    issues.push({
      displayName,
      outcome: outcomes.has(item.outcome) ? item.outcome : "other",
      ratingPercent: ratingOf(item.ratingPercent),
      effectiveDate: validIsoDate(item.effectiveDate) ? item.effectiveDate : null,
      favorableFindings: findingsFrom(item.favorableFindings),
      reasons: reasonsFrom(item.reasons),
      evidenceConsidered: evidenceFrom(item.evidenceConsidered),
      extractionConfidence: confidence,
    });
    if (issues.length === 20) break;
  }
  if (issues.length === 0) return { ok: false };
  return {
    ok: true,
    decision: {
      decisionDate,
      receivedDate: validIsoDate(decision.receivedDate)
        ? decision.receivedDate
        : null,
      overallSummary: clip(decision.overallSummary, summaryMax),
      issues,
    },
  };
}

function oneYearAfter(isoDate, years = vaRules.reviewDeadlineYears) {
  const [year, month, day] = isoDate.split("-").map(Number);
  return new Date(Date.UTC(year + years, month - 1, day));
}

const decisionPrompt = [
  "Read this VA decision letter and return JSON only.",
  '{"facts":[{"factType":"decisionFinding","conditionText":"short name or null","factText":"one statement written in the letter","eventDate":"YYYY-MM-DD or null","page":1}],"decision":{"decisionDate":"YYYY-MM-DD","receivedDate":"YYYY-MM-DD or null","overallSummary":"what the letter decided, in its words","issues":[{"displayName":"condition name written in the letter","outcome":"granted|denied|deferred|increased|continued|reduced|other","ratingPercent":20,"effectiveDate":"YYYY-MM-DD or null","favorableFindings":[{"text":"a favorable finding written in the letter","page":1}],"reasons":[{"text":"a reason written in the letter","category":"nexus|diagnosis|inServiceEvent|severity|other","page":1}],"evidenceConsidered":["a source the letter says it considered"],"extractionConfidence":0.9}]}}',
  "Use only words written in the letter. Do not infer a rating, a date, or an outcome that is not written.",
  "ratingPercent is null when the letter does not state a percentage.",
  "overallSummary is at most a short paragraph.",
  "If this is not a decision letter, return {\"facts\":[],\"decision\":null}.",
].join(" ");

async function saveDecisionDraft({ db, uid, caseId, documentId, decision }) {
  const decisions = db.collection(`users/${uid}/decisions`);
  const existing = await decisions
    .where("sourceDocumentId", "==", documentId)
    .limit(1)
    .get();
  if (!existing.empty && existing.docs[0].get("status") === "confirmed") {
    return existing.docs[0].id;
  }
  const decisionRef = existing.empty ? decisions.doc() : existing.docs[0].ref;
  const issues = db.collection(`users/${uid}/conditions`);
  const onCase = await issues.where("activeCaseId", "==", caseId).get();
  const byName = new Map();
  for (const doc of onCase.docs) {
    const name = String(doc.get("displayName") || "")
      .trim()
      .toLowerCase();
    if (name && !byName.has(name)) byName.set(name, doc.id);
  }
  const priorIssues = await db
    .collection(`users/${uid}/decisionIssues`)
    .where("decisionId", "==", decisionRef.id)
    .get();
  const batch = db.batch();
  for (const doc of priorIssues.docs) batch.delete(doc.ref);
  batch.set(
    decisionRef,
    {
      caseId,
      decisionDate: decision.decisionDate,
      receivedDate: decision.receivedDate,
      sourceDocumentId: documentId,
      sourceType: "documentExtracted",
      status: "needsReview",
      benefitType: "compensation",
      overallSummary: decision.overallSummary,
      reviewDeadline: Timestamp.fromDate(oneYearAfter(decision.decisionDate)),
      deadlineRuleVersionId: vaRules.id,
      schemaVersion: 1,
      createdAt: existing.empty
        ? FieldValue.serverTimestamp()
        : existing.docs[0].get("createdAt") || FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  for (const issue of decision.issues) {
    const conditionId = byName.get(issue.displayName.toLowerCase()) || null;
    batch.set(db.collection(`users/${uid}/decisionIssues`).doc(), {
      decisionId: decisionRef.id,
      conditionId,
      displayName: issue.displayName,
      outcome: issue.outcome,
      ratingPercent: issue.ratingPercent,
      effectiveDate: issue.effectiveDate,
      favorableFindings: issue.favorableFindings.map((finding) => ({
        text: finding.text,
        page: finding.page,
        sourceDocumentId: documentId,
      })),
      reasons: issue.reasons.map((reason) => ({
        text: reason.text,
        category: reason.category,
        page: reason.page,
        sourceDocumentId: documentId,
      })),
      evidenceConsidered: issue.evidenceConsidered,
      extractionConfidence: issue.extractionConfidence,
      userConfirmed: false,
      schemaVersion: 1,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return decisionRef.id;
}

module.exports = {
  decisionFromModelText,
  decisionPrompt,
  oneYearAfter,
  saveDecisionDraft,
};
