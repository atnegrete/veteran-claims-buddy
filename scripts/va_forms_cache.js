'use strict';

// One-off helper (not wired into package.json): downloads every allowlisted
// form PDF into a git-ignored .va-forms-cache/ dir and writes each field
// inventory beside it, so mappings can be authored against the real AcroForm
// field names. Safe to delete; reads only public PDFs. Honors --sandbox.

const fs = require('fs');
const path = require('path');
const { fetchFormInfo, formsApiBase, parseFormsArgs } = require('./va_forms_common');
const { trackedFormNumbers } = require('./va_forms_catalog');
const { inspectFile, diffInventory } = require('./va_forms_inspect');
const { loadEnv, sniffProject } = require('./load_env');

async function main(argv) {
  loadEnv(sniffProject(argv));
  const args = parseFormsArgs(argv);
  if (!args.apiKey) throw new Error('Set VA_FORMS_API_KEY (or --api-key).');
  const base = formsApiBase(args);
  const root = path.join(__dirname, '..', '.va-forms-cache');
  fs.mkdirSync(root, { recursive: true });
  for (const form of trackedFormNumbers) {
    try {
      const info = await fetchFormInfo(form, args.apiKey, { base });
      if (!info || !info.url) {
        console.error(`SKIP ${form}: not listed / no url`);
        continue;
      }
      const res = await fetch(info.url);
      if (!res.ok) {
        console.error(`SKIP ${form}: download ${res.status}`);
        continue;
      }
      const bytes = Buffer.from(await res.arrayBuffer());
      const dir = path.join(root, form);
      fs.mkdirSync(dir, { recursive: true });
      const pdfPath = path.join(dir, 'original.pdf');
      fs.writeFileSync(pdfPath, bytes);
      const { inventory } = await inspectFile(pdfPath);
      // Commit a reproducible field inventory (public form metadata) so the
      // mapping-validation test can guarantee every pdfField in a mapping
      // actually exists in the imported revision.
      const invDir = path.join(__dirname, '..', 'mappings', 'va-forms', 'inventory');
      fs.mkdirSync(invDir, { recursive: true });
      const invPath = path.join(invDir, `${form}.json`);

      // Revision-drift signal: if a committed inventory already exists, report
      // what changed so the mapper can be re-validated for a new revision.
      let drift = '';
      if (fs.existsSync(invPath)) {
        const prev = JSON.parse(fs.readFileSync(invPath, 'utf8'));
        const d = diffInventory(prev.fields || [], inventory);
        if (prev.revision !== info.revision) {
          drift = ` [revision ${prev.revision} -> ${info.revision}]`;
        }
        if (d.changed > 0) {
          drift += ` [fields +${d.added.length} -${d.removed.length} ~${d.retyped.length}]`;
        }
      }

      fs.writeFileSync(
        invPath,
        `${JSON.stringify({ formNumber: form, revision: info.revision, fields: inventory }, null, 2)}\n`,
      );
      console.log(`${form} (${info.revision}): ${inventory.length} fields${drift}`);
    } catch (error) {
      console.error(`SKIP ${form}: ${error.message}`);
    }
  }
  console.log(`\nCached under ${root}`);
}

main(process.argv.slice(2)).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
