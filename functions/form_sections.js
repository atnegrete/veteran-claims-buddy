"use strict";

// Per-form section builders. A form is filled only from canonical identity,
// constants, and these hard-coded sections. A field that is not named here is
// left blank. Nothing in this file is typed by the Veteran into a generic
// field list.

const DISABILITY_ROW_COUNT = 35;
const FIRST_PAGE_ROWS = 15;
const SECTION_DRAFT_MAX = 8000;

// Mirrors connectionTypes in app/lib/claim/claim_issue.dart.
const CONNECTION_LABELS = {
  direct: "Directly from service",
  secondary: "Connected to another condition",
  aggravation: "Made worse in service",
  presumptive: "One service may presume",
  increase: "A higher rating than one already granted",
};

function str(value) {
  return typeof value === "string" ? value.trim() : "";
}

function subformForRow(index) {
  return index < FIRST_PAGE_ROWS ? 10 : 14;
}

function disabilityNameField(index) {
  return `F[0].#subform[${subformForRow(index)}].CURRENTDISABILITY[${index}]`;
}

function disabilityExplainField(index) {
  return (
    `F[0].#subform[${subformForRow(index)}].` +
    `ExplainHowDisabilityRelatesToEvent_Exposure_Injury[${index}]`
  );
}

// Pure: one paragraph from the connection notes and the in-service / nexus
// evidence the Veteran already saved for this condition. Empty when none of
// that exists. Mirrors disabilityExplanation in
// app/lib/claim/disability_explanation.dart.
function assembleDisabilityExplanation({ theories = [], links = [] } = {}) {
  const parts = [];
  for (const theory of theories) {
    const summary = str(theory && theory.summary);
    if (!summary) continue;
    const label = CONNECTION_LABELS[theory.type];
    parts.push(label ? `${label}. ${summary}` : summary);
  }
  for (const link of links) {
    const type = link && link.evidenceType;
    if (type !== "inServiceEvent" && type !== "nexus") continue;
    const summary = str(link.summary);
    if (summary) parts.push(summary);
  }
  return parts.join(" ");
}

function orderedIssues(issues) {
  return (Array.isArray(issues) ? issues : [])
    .filter((issue) => issue && str(issue.displayName) && str(issue.id))
    .slice()
    .sort((a, b) => {
      const byName = str(a.displayName).localeCompare(str(b.displayName));
      if (byName !== 0) return byName;
      return str(a.id).localeCompare(str(b.id));
    })
    .slice(0, DISABILITY_ROW_COUNT);
}

// Saved drafts win over the assembled paragraph. A blank draft falls back to
// the assembled text. The began/worsened date is not stored, so it stays blank.
function build526ezSection({
  issues = [],
  theoriesByIssue = {},
  linksByIssue = {},
  sectionDrafts = {},
} = {}) {
  const values = {};
  orderedIssues(issues).forEach((issue, index) => {
    values[disabilityNameField(index)] = str(issue.displayName);
    const drafted = str(sectionDrafts[issue.id]).slice(0, SECTION_DRAFT_MAX);
    const assembled = assembleDisabilityExplanation({
      theories: theoriesByIssue[issue.id] || [],
      links: linksByIssue[issue.id] || [],
    });
    const text = drafted || assembled;
    if (text) values[disabilityExplainField(index)] = text;
  });
  return values;
}

function buildSections(formNumber, context = {}) {
  if (formNumber === "21-526EZ") return build526ezSection(context);
  return {};
}

// Live editor drafts win over what is already saved. A blank live value clears
// the saved draft so the assembled paragraph is used again.
function sectionDraftsFrom(saved, live) {
  const merged = {};
  if (saved && typeof saved === "object") {
    for (const [key, value] of Object.entries(saved)) {
      const text = str(value).slice(0, SECTION_DRAFT_MAX);
      if (text) merged[key] = text;
    }
  }
  if (live && typeof live === "object") {
    for (const [key, value] of Object.entries(live)) {
      const text = str(value).slice(0, SECTION_DRAFT_MAX);
      if (text) merged[key] = text;
      else delete merged[key];
    }
  }
  return merged;
}

module.exports = {
  DISABILITY_ROW_COUNT,
  SECTION_DRAFT_MAX,
  CONNECTION_LABELS,
  disabilityNameField,
  disabilityExplainField,
  assembleDisabilityExplanation,
  orderedIssues,
  build526ezSection,
  buildSections,
  sectionDraftsFrom,
};
