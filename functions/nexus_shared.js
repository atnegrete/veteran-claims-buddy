// Shared helpers for the Nexus Letters flow (interview, generation, revision).
// Pure helpers plus the Vertex JSON completion and the few Firestore reads the
// three modules have in common. Nothing here files with the VA.
const { HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { VertexAI } = require("@google-cloud/vertexai");
const { assertEnrollmentConfirmed } = require("./auth_state");
const { patternFor } = require("./nexus_knowledge");

// The interview phrases one question at a time: fast and cheap is fine. The
// drafting phase writes the letters, so it defaults to a stronger model and a
// slightly warmer temperature for fuller prose. Both are env-overridable so the
// owner can retune without a code change.
const interviewModel = process.env.NEXUS_INTERVIEW_MODEL || "gemini-2.5-flash";
const draftModel = process.env.NEXUS_DRAFT_MODEL || "gemini-2.5-pro";
const interviewTemperature = 0.3;
const draftTemperature = (() => {
  const raw = Number(process.env.NEXUS_DRAFT_TEMPERATURE);
  return Number.isFinite(raw) && raw >= 0 && raw <= 1 ? raw : 0.45;
})();
const maxAnswerChars = 2000;
const maxInstructionChars = 500;

function clip(value, max) {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  return trimmed.length <= max ? trimmed : trimmed.slice(0, max);
}

function projectId() {
  return process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
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

// The one state document per condition that the whole flow reads and writes.
function stateDocPath(uid, issueId) {
  return `users/${uid}/conditions/${issueId}/nexusLetter/current`;
}

function interviewSlotsFor(pack, nexusKind) {
  const pattern = patternFor(pack, nexusKind);
  return Array.isArray(pattern.interviewSlots) ? pattern.interviewSlots : [];
}

// Pure: seed a slot from facts already saved on the condition. A non-empty
// seed means the interview can skip that question. An empty string means ask.
function slotSeed(context, slotId) {
  const theories = Array.isArray(context.theories) ? context.theories : [];
  const links = Array.isArray(context.links) ? context.links : [];
  const byType = (type) =>
    theories
      .filter((theory) => theory.type === type)
      .map((theory) => clip(theory.summary, 500))
      .filter(Boolean)
      .join(" ");
  const linkText = (predicate) =>
    links
      .filter(predicate)
      .map((link) => clip(link.summary, 300))
      .filter(Boolean)
      .join(" ");
  switch (slotId) {
    case "inServiceEvent":
      return clip(context.connectionSource, 1500) || byType("direct");
    case "primaryCondition":
      return byType("secondary");
    case "worsening":
      return byType("aggravation");
    case "treatmentRecords":
      return linkText(() => true);
    case "providerStatements":
      return linkText((link) => link.evidenceType === "nexus");
    default:
      return "";
  }
}

function parseJsonObject(text) {
  const raw = typeof text === "string" ? text.trim() : "";
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  const body = start >= 0 && end > start ? raw.slice(start, end + 1) : raw;
  try {
    const data = JSON.parse(body);
    return data && typeof data === "object" ? data : {};
  } catch (_) {
    return {};
  }
}

async function completeJson(prompt, options = {}) {
  const model = options.model || interviewModel;
  const temperature =
    typeof options.temperature === "number" ? options.temperature : interviewTemperature;
  const vertex = new VertexAI({ project: projectId(), location: "us-central1" });
  const generative = vertex.getGenerativeModel({
    model,
    generationConfig: { temperature, responseMimeType: "application/json" },
  });
  const result = await generative.generateContent({
    contents: [{ role: "user", parts: [{ text: prompt }] }],
  });
  const parts = result.response?.candidates?.[0]?.content?.parts ?? [];
  return parseJsonObject(parts.map((part) => part.text ?? "").join(""));
}

// Draft with the stronger model, and if it is unavailable (for example the
// draft model is not enabled in this project), log the real reason and fall
// back to the interview model so the letters still generate. deps is for tests.
async function completeDraftJson(prompt, deps = {}) {
  const complete = deps.complete || completeJson;
  const primary = deps.draftModel || draftModel;
  const fallback = deps.interviewModel || interviewModel;
  try {
    return await complete(prompt, { model: primary, temperature: draftTemperature });
  } catch (error) {
    if (primary === fallback) throw error;
    console.error(`nexus draft model ${primary} failed; falling back to ${fallback}`, error);
    return complete(prompt, { model: fallback, temperature: draftTemperature });
  }
}

// The Veteran's legal name and VA file number for a letter header.
async function loadIdentity(db, uid) {
  const doc = await db.doc(`users/${uid}/identifiers/profile`).get();
  const data = doc.exists ? doc.data() : {};
  const legalName = [
    clip(data.legalFirstName, 60),
    clip(data.legalMiddleName, 60),
    clip(data.legalLastName, 60),
  ]
    .filter(Boolean)
    .join(" ");
  return { legalName, vaFileNumber: clip(data.vaFileNumber, 40) };
}

// Pure: the resolved slotId -> answer map from a stored transcript (seeded
// facts and typed answers alike). Empty answers are left out.
function answeredFrom(transcript) {
  const answered = {};
  for (const entry of Array.isArray(transcript) ? transcript : []) {
    if (!entry || typeof entry.slotId !== "string") continue;
    const answer = clip(entry.answer, maxAnswerChars);
    if (answer) answered[entry.slotId] = answer;
  }
  return answered;
}

module.exports = {
  interviewModel,
  draftModel,
  interviewTemperature,
  draftTemperature,
  maxAnswerChars,
  maxInstructionChars,
  clip,
  projectId,
  requireReady,
  stateDocPath,
  interviewSlotsFor,
  slotSeed,
  parseJsonObject,
  completeJson,
  completeDraftJson,
  loadIdentity,
  answeredFrom,
};
