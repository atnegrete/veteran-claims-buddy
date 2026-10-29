'use strict';

// va:forms:inspect - dumps the AcroForm field inventory of an imported PDF and
// diffs it against the prior revision so changed/added/removed fillable fields
// are flagged before a mapping is authored (handoff 37.8). Reads a local PDF
// path (downloaded by import) and writes field-inventory.json beside it.

const fs = require('fs');
const path = require('path');

// Pure: normalize a list of field descriptors into a stable, sorted inventory.
// Keeps the optional maxLength (text fields) and options (radio/dropdown export
// values) so the mapper can render the right input and never invent a length.
function normalizeInventory(fields) {
  return [...fields]
    .map((field) => {
      const out = { name: String(field.name), type: String(field.type) };
      if (typeof field.maxLength === 'number' && field.maxLength > 0) {
        out.maxLength = field.maxLength;
      }
      if (Array.isArray(field.options) && field.options.length) {
        out.options = field.options.map(String);
      }
      return out;
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

// Pure: compare two inventories and report what changed between revisions.
function diffInventory(previous, next) {
  const prev = new Map(normalizeInventory(previous).map((f) => [f.name, f.type]));
  const now = new Map(normalizeInventory(next).map((f) => [f.name, f.type]));
  const added = [];
  const removed = [];
  const retyped = [];
  for (const [name, type] of now) {
    if (!prev.has(name)) added.push(name);
    else if (prev.get(name) !== type) retyped.push({ name, from: prev.get(name), to: type });
  }
  for (const name of prev.keys()) {
    if (!now.has(name)) removed.push(name);
  }
  return { added, removed, retyped, changed: added.length + removed.length + retyped.length };
}

// Requires pdf-lib (a functions dependency). Lazily required so the pure
// helpers above stay importable in environments without it.
async function extractFields(bytes) {
  const { PDFDocument, PDFTextField } = require('pdf-lib');
  const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
  const form = doc.getForm();
  return form.getFields().map((field) => {
    const entry = { name: field.getName(), type: field.constructor.name };
    try {
      if (field instanceof PDFTextField) {
        const max = field.getMaxLength();
        if (typeof max === 'number' && max > 0) entry.maxLength = max;
      } else if (typeof field.getOptions === 'function') {
        const options = field.getOptions();
        if (Array.isArray(options) && options.length) entry.options = options;
      }
    } catch (_) {
      // A field that refuses to report its constraints is still inventoried by
      // name and type; the mapper falls back to a plain text input.
    }
    return entry;
  });
}

async function inspectFile(pdfPath, deps = {}) {
  const read = deps.readFile ?? ((p) => fs.readFileSync(p));
  const extract = deps.extractFields ?? extractFields;
  const bytes = read(pdfPath);
  const inventory = normalizeInventory(await extract(bytes));
  const outPath = path.join(path.dirname(pdfPath), 'field-inventory.json');
  const prevPath = deps.previousInventoryPath;
  let diff = null;
  if (prevPath && fs.existsSync(prevPath)) {
    const previous = JSON.parse(read(prevPath).toString());
    diff = diffInventory(previous.fields || previous, inventory);
  }
  if (!deps.dryRun) {
    fs.writeFileSync(outPath, JSON.stringify({ fields: inventory }, null, 2));
  }
  return { outPath, inventory, diff };
}

async function main(argv) {
  const pdfPath = argv[0];
  if (!pdfPath) throw new Error('Pass the path to a downloaded form PDF.');
  const prevIndex = argv.indexOf('--previous');
  const previousInventoryPath = prevIndex >= 0 ? argv[prevIndex + 1] : undefined;
  const result = await inspectFile(pdfPath, { previousInventoryPath });
  console.log(`Wrote ${result.inventory.length} fields to ${result.outPath}.`);
  if (result.diff) {
    console.log(
      `Field changes vs previous: +${result.diff.added.length} -${result.diff.removed.length} ~${result.diff.retyped.length}.`,
    );
  }
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { normalizeInventory, diffInventory, inspectFile };
