const test = require("node:test");
const assert = require("node:assert/strict");
const { readPack, standardsByIds, patternFor } = require("./nexus_knowledge");

const pack = readPack();

test("the manifest is versioned with a changelog", () => {
  assert.match(pack.manifest.version, /^\d+\.\d+\.\d+$/);
  assert.ok(pack.manifest.reviewedOn);
  assert.ok(Array.isArray(pack.manifest.changelog) && pack.manifest.changelog.length > 0);
});

test("every standard is complete and ids are unique", () => {
  const ids = new Set();
  for (const standard of pack.standardsList) {
    assert.ok(standard.id, "standard needs an id");
    assert.ok(standard.label, `${standard.id} needs a label`);
    assert.ok(standard.citation, `${standard.id} needs a citation`);
    assert.ok(standard.plainText && standard.plainText.length > 10, `${standard.id} needs plainText`);
    assert.ok(standard.lastReviewed, `${standard.id} needs lastReviewed`);
    assert.ok(!ids.has(standard.id), `duplicate standard id ${standard.id}`);
    ids.add(standard.id);
  }
});

test("each letter pattern resolves its standards and has ordered components", () => {
  for (const kind of ["direct", "secondary", "aggravation", "supplemental"]) {
    const pattern = patternFor(pack, kind);
    assert.ok(pattern, `pattern ${kind} is missing`);
    assert.ok(pattern.label, `pattern ${kind} needs a label`);
    const resolved = standardsByIds(pack, pattern.standardIds);
    assert.equal(
      resolved.length,
      pattern.standardIds.length,
      `pattern ${kind} references an unknown standard id`,
    );
    assert.ok(pattern.components.length >= 4, `pattern ${kind} needs components`);
    for (const component of pattern.components) {
      assert.ok(component.id, `pattern ${kind} component needs an id`);
      assert.ok(component.label, `pattern ${kind} component needs a label`);
      assert.ok(component.guidance, `pattern ${kind} component needs guidance`);
    }
  }
});

test("every curated condition set has match terms and well-formed citations", () => {
  assert.ok(Array.isArray(pack.conditions), "the conditions layer should load");
  assert.ok(pack.conditions.length >= 1, "expected at least one curated condition");
  const ids = new Set();
  for (const set of pack.conditions) {
    assert.ok(set.id, "condition set needs an id");
    assert.ok(!ids.has(set.id), `duplicate condition id ${set.id}`);
    ids.add(set.id);
    assert.ok(set.label, `${set.id} needs a label`);
    assert.ok(
      Array.isArray(set.matchTerms) && set.matchTerms.length > 0,
      `${set.id} needs matchTerms`,
    );
    const citations = [...(set.legalCitations || []), ...(set.medicalCitations || [])];
    assert.ok(citations.length > 0, `${set.id} needs at least one citation`);
    for (const entry of citations) {
      assert.ok(
        entry.citation && entry.citation.length > 3,
        `${set.id} citation needs text`,
      );
      assert.ok(
        entry.description && entry.description.length > 3,
        `${set.id} citation needs a description`,
      );
    }
  }
});

test("every presumptive pathway carries a citation and sourceAsOf", () => {
  const ids = new Set();
  assert.ok(pack.presumptive.length >= 5, "expected at least five pathways");
  for (const pathway of pack.presumptive) {
    assert.ok(pathway.id, "pathway needs an id");
    assert.ok(!ids.has(pathway.id), `duplicate pathway id ${pathway.id}`);
    ids.add(pathway.id);
    assert.ok(pathway.label, `${pathway.id} needs a label`);
    assert.ok(pathway.authority, `${pathway.id} needs an authority`);
    assert.ok(pathway.citation, `${pathway.id} needs a citation`);
    assert.ok(pathway.sourceAsOf, `${pathway.id} needs sourceAsOf`);
    assert.ok(pathway.qualifyingService, `${pathway.id} needs qualifyingService`);
    assert.ok(Array.isArray(pathway.exposures), `${pathway.id} needs exposures`);
    assert.ok(
      Array.isArray(pathway.presumptiveConditions) &&
        pathway.presumptiveConditions.length > 0,
      `${pathway.id} needs presumptiveConditions`,
    );
    for (const condition of pathway.presumptiveConditions) {
      assert.ok(
        typeof condition === "string" && condition.trim().length > 0,
        `${pathway.id} has an empty condition`,
      );
    }
    for (const range of pathway.qualifyingService.dateRanges || []) {
      assert.ok(range.start, `${pathway.id} date range needs a start`);
    }
  }
});
