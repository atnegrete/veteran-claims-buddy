// Shared nexus context + the presumptive matcher. For one claimed condition it
// gathers the facts already saved on the claim (loadNexusContext) and flags
// when the condition may be presumptive (matchPresumptive), so the Veteran can
// see that a paid nexus letter may not be needed. The interview, generation,
// and revision live in nexus_interview.js and nexus_generate.js. Nothing here
// files with the VA.
const { assembleDisabilityExplanation } = require("./form_sections");
const { serviceLine } = require("./form_statements");

function clip(value, max) {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  return trimmed.length <= max ? trimmed : trimmed.slice(0, max);
}

// Pure: normalize free text for loose matching.
function normalize(value) {
  return (typeof value === "string" ? value : "")
    .toLowerCase()
    .replace(/[^a-z0-9 ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Pure: do two YYYY-MM-DD ranges overlap? An empty end means "to present".
function rangesOverlap(aStart, aEnd, bStart, bEnd) {
  const toNum = (value, fallback) => {
    const s = typeof value === "string" ? value.trim() : "";
    if (!s) return fallback;
    const n = Number(s.slice(0, 10).replace(/-/g, ""));
    return Number.isFinite(n) ? n : fallback;
  };
  const as = toNum(aStart, 0);
  const ae = toNum(aEnd, 99999999);
  const bs = toNum(bStart, 0);
  const be = toNum(bEnd, 99999999);
  return as <= be && bs <= ae;
}

// Pure: given the Veteran's facts and the pack, find presumptive pathways whose
// qualifying service or exposure the Veteran plausibly meets, and flag when the
// claimed condition itself appears on a matched pathway's list.
function matchPresumptive(context, pack) {
  const exposures = (context.exposures || []).map((entry) => entry.type);
  const serviceRanges = [
    ...(context.service || []).map((period) => [period.startDate, period.endDate]),
    ...(context.deployments || []).map((entry) => [entry.startDate, entry.endDate]),
  ];
  const locationHay = normalize(
    [
      ...(context.deployments || []).map((entry) => `${entry.country} ${entry.notes}`),
      ...(context.exposures || []).map((entry) => entry.description),
    ].join(" "),
  );
  const branches = (context.service || []).map((period) => period.branch);
  const conditionNorm = normalize(context.condition);

  const pathways = [];
  for (const pathway of pack.presumptive || []) {
    const qualifying = pathway.qualifyingService || {};
    const exposureMatch = (pathway.exposures || []).some(
      (type) => type !== "other" && exposures.includes(type),
    );
    const locationMatch = (qualifying.locations || []).some((loc) => {
      const needle = normalize(loc);
      return needle.length > 0 && locationHay.includes(needle);
    });
    const dateMatch = (qualifying.dateRanges || []).some((range) =>
      serviceRanges.some(([start, end]) => rangesOverlap(start, end, range.start, range.end)),
    );
    const branchOk =
      !(qualifying.branches && qualifying.branches.length) ||
      branches.some((branch) => qualifying.branches.includes(branch));
    const serviceMatch = locationMatch && dateMatch && branchOk;
    if (!exposureMatch && !serviceMatch) continue;
    const conditionMatch =
      conditionNorm.length >= 4 &&
      (pathway.presumptiveConditions || []).some((name) => {
        const normalized = normalize(name);
        return (
          normalized.length >= 4 &&
          (normalized.includes(conditionNorm) || conditionNorm.includes(normalized))
        );
      });
    pathways.push({
      id: pathway.id,
      label: pathway.label,
      authority: pathway.authority,
      citation: pathway.citation,
      sourceAsOf: pathway.sourceAsOf,
      conditions: pathway.presumptiveConditions || [],
      matchedBy: { exposure: exposureMatch, location: locationMatch, date: dateMatch },
      conditionMatch,
    });
  }
  const strong = pathways.filter((pathway) => pathway.conditionMatch);
  const advisory = strong.length > 0;
  const advisoryText = advisory
    ? `This condition may qualify as presumptive under ${strong[0].label} (${strong[0].citation}). If it does, a presumptive claim can be granted without a paid nexus letter.`
    : "";
  return { pathways, advisory, advisoryText };
}

// Pure: bound a curated citation list to safe lengths and shape.
function cleanCitations(list) {
  return (Array.isArray(list) ? list : [])
    .map((entry) => ({
      citation: clip(entry && entry.citation, 300),
      description: clip(entry && entry.description, 300),
    }))
    .filter((entry) => entry.citation)
    .slice(0, 8);
}

// Pure: match the claimed condition (free text) to a curated per-condition
// citation set and return its vetted legal + medical citations. The model never
// writes these; the server injects them, so the same claim yields the same
// citations every run. An unmatched condition returns empty lists (the general
// legal standards still apply). Matching mirrors matchPresumptive's loose
// condition compare on normalized text.
function conditionCitationsFor(context, pack) {
  const empty = { matchedId: "", matchedLabel: "", legal: [], medical: [] };
  const conditionNorm = normalize(context && context.condition);
  if (conditionNorm.length < 3) return empty;
  for (const set of (pack && pack.conditions) || []) {
    const terms = Array.isArray(set.matchTerms) ? set.matchTerms : [];
    const hit = terms.some((term) => {
      const needle = normalize(term);
      return (
        needle.length >= 3 &&
        (conditionNorm.includes(needle) || needle.includes(conditionNorm))
      );
    });
    if (hit) {
      return {
        matchedId: set.id || "",
        matchedLabel: set.label || "",
        legal: cleanCitations(set.legalCitations),
        medical: cleanCitations(set.medicalCitations),
      };
    }
  }
  return empty;
}

// Gathers the facts already saved on one condition: the connection theories and
// evidence links, the service periods, deployments, and exposures. Returns null
// when the condition is not on this claim.
async function loadNexusContext(db, uid, caseId, issueId) {
  const issueDoc = await db.doc(`users/${uid}/conditions/${issueId}`).get();
  if (!issueDoc.exists) return null;
  const issue = issueDoc.data();
  if (issue.activeCaseId !== caseId) return null;
  const [theorySnap, linkSnap, periodSnap, deploymentSnap, exposureSnap] = await Promise.all([
    db.collection(`users/${uid}/conditions/${issueId}/theories`).get(),
    db.collection(`users/${uid}/evidenceLinks`).where("conditionId", "==", issueId).get(),
    db.collection(`users/${uid}/servicePeriods`).get(),
    db.collection(`users/${uid}/deployments`).get(),
    db.collection(`users/${uid}/exposures`).get(),
  ]);
  const theories = theorySnap.docs.map((doc) => ({
    type: doc.data().type,
    summary: clip(doc.data().summary, 500),
  }));
  const links = linkSnap.docs.map((doc) => ({
    evidenceType: doc.data().evidenceType,
    summary: clip(doc.data().summary, 500),
  }));
  const service = periodSnap.docs
    .map((doc) => {
      const data = doc.data();
      return {
        branch: clip(data.branch, 60),
        component: clip(data.component, 40),
        startDate: clip(data.startDate, 10),
        endDate: clip(data.endDate, 10),
        occupation: clip(data.primaryOccupationText, 120),
      };
    })
    .filter((period) => period.branch);
  const deployments = deploymentSnap.docs
    .map((doc) => {
      const data = doc.data();
      return {
        country: clip(data.country, 80),
        notes: clip(data.notes || data.locationText, 300),
        startDate: clip(data.startDate, 10),
        endDate: clip(data.endDate, 10),
        combatRelated: data.combatRelated === true,
      };
    })
    .filter((entry) => entry.country || entry.notes);
  const exposures = exposureSnap.docs
    .map((doc) => {
      const data = doc.data();
      return { type: clip(data.type, 40), description: clip(data.description, 500) };
    })
    .filter((entry) => entry.type);
  return {
    condition: clip(issue.displayName, 120),
    theories,
    links,
    connectionSource: assembleDisabilityExplanation({ theories, links }),
    service,
    serviceSummary: serviceLine(periodSnap.docs.map((doc) => doc.data())),
    deployments,
    exposures,
  };
}

module.exports = {
  clip,
  normalize,
  rangesOverlap,
  matchPresumptive,
  conditionCitationsFor,
  loadNexusContext,
};
