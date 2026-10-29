// Loads the curated nexus knowledge pack bundled under functions/knowledge/nexus.
// The pack is deterministic, versioned reference data (no external calls): the
// medical/legal standards, the per-kind letter patterns, and the presumptive
// pathways. See docs/nexus-knowledge.md for the schema and the update loop.
const fs = require("fs");
const path = require("path");

const packDir = path.join(__dirname, "knowledge", "nexus");

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

// Every *.json under presumptive/ is a pathway, so adding a file ships a new
// pathway with no code change.
function readPresumptive() {
  return readDir("presumptive");
}

// Every *.json under conditions/ is a curated per-condition citation set
// (vetted legal + medical citations), so adding a file ships a new condition
// with no code change.
function readConditions() {
  return readDir("conditions");
}

function readDir(sub) {
  const dir = path.join(packDir, sub);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((name) => name.endsWith(".json"))
    .sort()
    .map((name) => readJson(path.join(dir, name)));
}

function readPack() {
  const manifest = readJson(path.join(packDir, "manifest.json"));
  const standardsFile = readJson(path.join(packDir, "standards.json"));
  const patternsFile = readJson(path.join(packDir, "letter-patterns.json"));
  const standards = {};
  for (const entry of standardsFile.standards || []) {
    if (entry && entry.id) standards[entry.id] = entry;
  }
  return {
    manifest,
    standards,
    standardsList: standardsFile.standards || [],
    patterns: patternsFile.patterns || {},
    presumptive: readPresumptive(),
    conditions: readConditions(),
  };
}

let cached = null;

// Cached for the function runtime; tests read fresh with readPack().
function loadPack() {
  if (!cached) cached = readPack();
  return cached;
}

function standardsByIds(pack, ids) {
  return (ids || []).map((id) => pack.standards[id]).filter(Boolean);
}

function patternFor(pack, nexusKind) {
  return pack.patterns[nexusKind] || pack.patterns.direct;
}

module.exports = {
  loadPack,
  readPack,
  standardsByIds,
  patternFor,
  packDir,
};
