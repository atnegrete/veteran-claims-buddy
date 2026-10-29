'use strict';

// Tiny, zero-dependency .env loader for the va:forms:* tooling. Layered:
//   1. .env            (shared defaults)
//   2. .env.<project>  (per-project override, e.g. .env.dev / .env.prod)
// The real shell environment always wins over a file, and a project file wins
// over the shared .env. These files hold secrets (the VA Forms API key) and are
// git-ignored; .env.example documents the format.

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');

function parseEnv(text) {
  const out = {};
  for (const rawLine of text.split('\n')) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq < 0) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    // Strip matching surrounding quotes, if any.
    if (
      value.length >= 2 &&
      ((value[0] === '"' && value[value.length - 1] === '"') ||
        (value[0] === "'" && value[value.length - 1] === "'"))
    ) {
      value = value.slice(1, -1);
    }
    if (key) out[key] = value;
  }
  return out;
}

function readFileIfExists(file) {
  try {
    return parseEnv(fs.readFileSync(file, 'utf8'));
  } catch (_) {
    return {};
  }
}

// Loads .env then .env.<project>, setting only keys not already present in the
// real environment (so `export KEY=...` still wins). Returns the applied keys.
function loadEnv(project) {
  const layers = [readFileIfExists(path.join(repoRoot, '.env'))];
  if (project) {
    layers.push(readFileIfExists(path.join(repoRoot, `.env.${project}`)));
  }
  const merged = Object.assign({}, ...layers);
  const applied = [];
  for (const [key, value] of Object.entries(merged)) {
    if (process.env[key] === undefined) {
      process.env[key] = value;
      applied.push(key);
    }
  }
  return applied;
}

// Reads the --project value from argv without a full parse, so env can load
// before the real argument parser reads process.env.
function sniffProject(argv) {
  const index = argv.indexOf('--project');
  return index >= 0 ? argv[index + 1] || '' : '';
}

module.exports = { loadEnv, sniffProject, parseEnv };
