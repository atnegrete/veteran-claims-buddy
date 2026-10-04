const factTypes = new Set([
  "diagnosis",
  "symptom",
  "serviceEvent",
  "treatment",
  "medication",
  "imagingFinding",
  "functionalImpact",
  "medicalOpinion",
  "decisionFinding",
  "other",
]);

const readLockMs = 5 * 60 * 1000;

function shouldStartRead(jobData, nowMs) {
  if (!jobData) return true;
  if (jobData.status === "needsReview" || jobData.status === "complete") {
    return false;
  }
  if (jobData.status === "processing") {
    const started = jobData.startedAt;
    const startedMs =
      started && typeof started.toMillis === "function"
        ? started.toMillis()
        : null;
    if (startedMs != null && nowMs - startedMs < readLockMs) return false;
  }
  return true;
}

function validIsoDate(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

function factsFromModelText(text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { ok: false, facts: [] };
  }
  const raw = Array.isArray(parsed)
    ? parsed
    : parsed && Array.isArray(parsed.facts)
      ? parsed.facts
      : null;
  if (!raw) return { ok: false, facts: [] };
  const facts = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const factText =
      typeof item.factText === "string" ? item.factText.trim() : "";
    if (factText.length < 1 || factText.length > 2000) continue;
    const condition =
      typeof item.conditionText === "string" ? item.conditionText.trim() : "";
    const page = Number.isInteger(item.page) ? item.page : null;
    const confidence =
      typeof item.confidence === "number" &&
      Number.isFinite(item.confidence) &&
      item.confidence >= 0 &&
      item.confidence <= 1
        ? Math.round(item.confidence * 100) / 100
        : null;
    facts.push({
      factType: factTypes.has(item.factType) ? item.factType : "other",
      conditionText:
        condition.length > 0 && condition.length <= 200 ? condition : null,
      factText,
      eventDate: validIsoDate(item.eventDate) ? item.eventDate : null,
      page: page != null && page > 0 && page <= 2000 ? page : null,
      confidence,
    });
    if (facts.length === 40) break;
  }
  return { ok: true, facts };
}

const factPrompt = [
  "Read this file and return JSON only.",
  '{"facts":[{"factType":"diagnosis|symptom|serviceEvent|treatment|medication|imagingFinding|functionalImpact|medicalOpinion|decisionFinding|other","conditionText":"short name or null","factText":"one statement written in the file","eventDate":"YYYY-MM-DD or null","page":1}]}',
  "Use only statements written in the file. Do not infer a diagnosis that is not written.",
  "factText is one sentence, close to the file's words.",
  "page is the page number when the file has pages, otherwise null.",
  "If the file has no clinical or claim statements, return {\"facts\":[]}.",
  "At most 40 facts. Skip duplicates.",
].join(" ");

module.exports = {
  shouldStartRead,
  factsFromModelText,
  factPrompt,
  validIsoDate,
};
