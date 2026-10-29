'use strict';

// Golden check for the authored field mappings. Guarantees every mapping that
// will be published actually matches the imported revision: each pdfField exists
// in that revision's committed field inventory, each canonicalKey is one the
// canonical profile can supply, and there is exactly one mapping per tracked
// form. This is what makes auto-fill safe to publish without a live PDF in CI.

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const { validateMapping } = require('./va_forms_publish_mappings');
const { buildMapping } = require('./va_forms_automap');
const { trackedFormNumbers } = require('./va_forms_catalog');

const MAP_DIR = path.join(__dirname, '..', 'mappings', 'va-forms');
const INV_DIR = path.join(MAP_DIR, 'inventory');

// Keys the canonical profile can produce (base + derived). Mirrors
// CanonicalKeys in app/lib/forms/va_form_mapping.dart and the derivations in
// functions/form_generation.js. statement.body is supplied per package form.
const KNOWN_KEYS = new Set([
  'vet.legalFirstName', 'vet.legalMiddleName', 'vet.legalLastName',
  'vet.dateOfBirth', 'vet.ssn', 'vet.vaFileNumber', 'vet.email', 'vet.phone',
  'vet.priorVaClaim', 'vet.priorClaimFileNumber',
  'service.branch', 'service.entryDate', 'service.separationDate',
  'statement.body',
  'vet.legalMiddleInitial', 'vet.ssnArea', 'vet.ssnGroup', 'vet.ssnSerial',
  'vet.dobYear', 'vet.dobMonth', 'vet.dobDay',
  'vet.phoneAreaCode', 'vet.phonePrefix', 'vet.phoneLine',
  'vet.fullName', 'vet.dobUsSlashes', 'vet.phoneUsDashes',
]);

const mappingFiles = fs
  .readdirSync(MAP_DIR)
  .filter((f) => f.endsWith('.mapping.json'));

test('a mapping exists for every tracked form', () => {
  const haveForm = new Set(
    mappingFiles.map((f) => f.replace(/\.mapping\.json$/, '')),
  );
  for (const form of trackedFormNumbers) {
    assert.ok(haveForm.has(form), `missing mapping for ${form}`);
  }
});

for (const file of mappingFiles) {
  const mapping = JSON.parse(fs.readFileSync(path.join(MAP_DIR, file), 'utf8'));
  const form = mapping.formNumber;

  test(`${form}: validates and matches its imported revision`, () => {
    // Shape is exactly what the publisher will accept.
    const body = validateMapping(mapping);
    assert.equal(body.formNumber, form);
    assert.ok(body.fields.length > 0, 'has at least one field');

    const invPath = path.join(INV_DIR, `${form}.json`);
    const inv = JSON.parse(fs.readFileSync(invPath, 'utf8'));
    assert.equal(mapping.revision, inv.revision, 'revision matches inventory');
    const valid = new Set(inv.fields.map((f) => f.name));

    const seen = new Set();
    for (const field of mapping.fields) {
      assert.ok(valid.has(field.pdfField), `${form}: unknown pdfField ${field.pdfField}`);
      assert.ok(!seen.has(field.pdfField), `${form}: duplicate ${field.pdfField}`);
      seen.add(field.pdfField);
      if (field.source === 'auto') {
        assert.ok(field.canonicalKey, `${form}: auto field ${field.pdfField} has no key`);
        assert.ok(KNOWN_KEYS.has(field.canonicalKey), `${form}: unknown key ${field.canonicalKey}`);
      } else if (field.source === 'constant') {
        assert.ok(field.constantValue != null, `${form}: ${field.pdfField} constant has no value`);
      }
    }
  });
}

test('21-0966 writes the start of the email on the top line', () => {
  const mapping = JSON.parse(
    fs.readFileSync(path.join(MAP_DIR, '21-0966.mapping.json'), 'utf8'),
  );
  const emails = mapping.fields
    .filter((field) => field.canonicalKey === 'vet.email')
    .map((field) => field.pdfField);
  assert.deepEqual(emails, [
    'F[0].Page_1[0].EMAIL_ADDRESS[1]',
    'F[0].Page_1[0].EMAIL_ADDRESS[0]',
  ]);
});

test('21-0966 checks the veteran prior-claim answer and only that file number', () => {
  const mapping = JSON.parse(
    fs.readFileSync(path.join(MAP_DIR, '21-0966.mapping.json'), 'utf8'),
  );
  const field = (suffix) => mapping.fields.find((item) => item.pdfField.endsWith(suffix));
  const radio = field('RadioButtonList[2]');
  assert.equal(radio.source, 'auto');
  assert.equal(radio.canonicalKey, 'vet.priorVaClaim');
  const veteranFile = field('VA_File_Number[0]');
  assert.equal(veteranFile.source, 'auto');
  assert.equal(veteranFile.canonicalKey, 'vet.priorClaimFileNumber');
  const claimantFile = field('VA_File_Number[1]');
  assert.equal(claimantFile.source, 'ask');
  assert.equal(claimantFile.canonicalKey, undefined);
  const claimantRadio = field('RadioButtonList[0]');
  assert.equal(claimantRadio.source, 'ask');
});

test('the committed mappings equal a fresh automap run', () => {
  // The mapping files are the reviewed output of the automapper. If they drift
  // from what the automapper now produces, regenerate and re-review.
  for (const file of mappingFiles) {
    const committed = JSON.parse(fs.readFileSync(path.join(MAP_DIR, file), 'utf8'));
    const inv = JSON.parse(
      fs.readFileSync(path.join(INV_DIR, `${committed.formNumber}.json`), 'utf8'),
    );
    const fresh = buildMapping(inv);
    assert.deepEqual(committed, fresh, `${committed.formNumber} drifted from automap`);
  }
});
