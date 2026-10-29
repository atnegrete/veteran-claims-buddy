'use strict';

// One-off golden fill: for every committed mapping, resolve sentinel Veteran
// values and actually fill the cached PDF with pdf-lib. Confirms every mapped
// pdfField is a real, settable field on the imported revision (not just present
// in the inventory). Run: NODE_PATH=functions/node_modules node scripts/va_forms_fillcheck.js

const fs = require('fs');
const path = require('path');
const { PDFDocument } = require('pdf-lib');
const {
  canonicalFromDocs,
  resolveFieldValues,
} = require('../functions/form_generation');

const MAP_DIR = path.join(__dirname, '..', 'mappings', 'va-forms');
const CACHE = path.join(__dirname, '..', '.va-forms-cache');

const SENTINEL = canonicalFromDocs({
  identifiers: {
    legalFirstName: 'Jane',
    legalMiddleName: 'Quinn',
    legalLastName: 'Veteran',
    dateOfBirth: '1986-07-04',
    ssn: '123-45-6789',
    vaFileNumber: '12345678',
    phone: '+15551234567',
  },
  user: { email: 'jane@example.com' },
  service: { branch: 'Army', entryDate: '2008-01-01', separationDate: '2014-06-30' },
});

async function main() {
  const files = fs.readdirSync(MAP_DIR).filter((f) => f.endsWith('.mapping.json'));
  let ok = 0;
  for (const file of files) {
    const mapping = JSON.parse(fs.readFileSync(path.join(MAP_DIR, file), 'utf8'));
    const resolved = resolveFieldValues(mapping, SENTINEL, {
      'statement.body': 'Sentinel statement body.',
    });
    const pdfPath = path.join(CACHE, mapping.formNumber, 'original.pdf');
    const bytes = fs.readFileSync(pdfPath);
    const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
    const form = doc.getForm();
    let set = 0;
    const misses = [];
    for (const [name, entry] of Object.entries(resolved.values)) {
      try {
        form.getTextField(name).setText(entry.value);
        set += 1;
      } catch (error) {
        misses.push(`${name} :: ${error.message}`);
      }
    }
    await doc.save();
    const status = misses.length === 0 ? 'OK' : `MISS(${misses.length})`;
    console.log(
      `${mapping.formNumber}: ${status} — set ${set}/${Object.keys(resolved.values).length}` +
        (misses.length ? `\n   ${misses.join('\n   ')}` : ''),
    );
    if (misses.length === 0) ok += 1;
  }
  console.log(`\n${ok}/${files.length} forms filled cleanly.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
