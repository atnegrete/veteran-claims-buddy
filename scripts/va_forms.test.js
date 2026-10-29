'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { classifyForm } = require('./va_forms_discover');
const { storagePath, revisionMetadata } = require('./va_forms_import');
const { normalizeInventory, diffInventory } = require('./va_forms_inspect');
const { validateMapping } = require('./va_forms_publish_mappings');
const {
  revisionDocId,
  mappingDocId,
  sha256,
  formsApiBase,
  parseFormsArgs,
  normalizeFormName,
  fetchFormInfo,
  VA_FORMS_API,
  VA_FORMS_API_SANDBOX,
} = require('./va_forms_common');

test('normalizeFormName ignores the VA prefix and punctuation', () => {
  assert.strictEqual(normalizeFormName('VA10182'), normalizeFormName('10182'));
  assert.strictEqual(normalizeFormName('21-526EZ'), '21526EZ');
});

test('fetchFormInfo matches VA10182 but keeps our canonical number', async () => {
  const fakeFetch = async () => ({
    ok: true,
    json: async () => ({
      data: [
        {
          attributes: {
            form_name: 'VA10182',
            title: 'Board Appeal',
            url: 'https://example/va10182.pdf',
            last_revision_on: '2021-01-01',
            sha256: 'abc',
            pages: 4,
          },
        },
      ],
    }),
  });
  const info = await fetchFormInfo('10182', 'key', { fetchImpl: fakeFetch });
  assert.strictEqual(info.formNumber, '10182');
  assert.strictEqual(info.apiFormName, 'VA10182');
  assert.strictEqual(info.revision, '2021-01-01');
});
const { isTracked, trackedFormNumbers } = require('./va_forms_catalog');

test('formsApiBase selects the sandbox host only when --sandbox is set', () => {
  assert.strictEqual(formsApiBase(parseFormsArgs(['--project', 'dev'])), VA_FORMS_API);
  assert.strictEqual(
    formsApiBase(parseFormsArgs(['--project', 'dev', '--sandbox'])),
    VA_FORMS_API_SANDBOX,
  );
  assert.match(VA_FORMS_API_SANDBOX, /sandbox-api\.va\.gov/);
});

test('classifyForm flags a never-imported form as NEW', () => {
  const verdict = classifyForm(null, { formNumber: '21-526EZ', revision: '2026-01', sha256: 'a' });
  assert.strictEqual(verdict.status, 'NEW');
});

test('classifyForm detects a changed revision or checksum', () => {
  const known = { revision: '2026-01', sha256: 'a' };
  assert.strictEqual(
    classifyForm(known, { revision: '2026-10', sha256: 'a' }).status,
    'NEW REVISION DETECTED',
  );
  assert.strictEqual(
    classifyForm(known, { revision: '2026-01', sha256: 'b' }).status,
    'NEW REVISION DETECTED',
  );
});

test('classifyForm reports unchanged when revision and checksum match', () => {
  const known = { revision: '2026-01', sha256: 'a' };
  assert.strictEqual(classifyForm(known, { revision: '2026-01', sha256: 'a' }).status, 'unchanged');
});

test('classifyForm handles a form the VA does not list', () => {
  assert.strictEqual(classifyForm(null, null).status, 'missing');
});

test('storagePath is backend-only reference path', () => {
  assert.strictEqual(
    storagePath('21-526EZ', '2026-01'),
    'reference/va-forms/21-526EZ/2026-01/original.pdf',
  );
});

test('revisionMetadata captures immutable identity', () => {
  const meta = revisionMetadata({
    formNumber: '21-526EZ',
    info: { title: 'Disability', revision: '2026-01', url: 'https://x/y.pdf', pages: 11 },
    sha: 'abc123',
    byteLength: 42,
    path: 'reference/va-forms/21-526EZ/2026-01/original.pdf',
  });
  assert.strictEqual(meta.templateSha256, 'abc123');
  assert.strictEqual(meta.status, 'imported');
  assert.strictEqual(meta.pageCount, 11);
  assert.strictEqual(meta.schemaVersion, 1);
});

test('revisionDocId and mappingDocId are stable', () => {
  assert.strictEqual(
    revisionDocId('21-526EZ', '2026-01', 'abcdef0123456789'),
    '21-526EZ__2026-01__abcdef012345',
  );
  assert.strictEqual(mappingDocId('21-526EZ', '2026-01'), '21-526EZ__2026-01');
});

test('sha256 is deterministic', () => {
  assert.strictEqual(sha256(Buffer.from('hello')), sha256(Buffer.from('hello')));
});

test('normalizeInventory sorts by field name', () => {
  const sorted = normalizeInventory([
    { name: 'b', type: 'PDFTextField' },
    { name: 'a', type: 'PDFTextField' },
  ]);
  assert.deepStrictEqual(sorted.map((f) => f.name), ['a', 'b']);
});

test('diffInventory surfaces added, removed, and retyped fields', () => {
  const prev = [
    { name: 'name', type: 'PDFTextField' },
    { name: 'gone', type: 'PDFTextField' },
    { name: 'flag', type: 'PDFTextField' },
  ];
  const next = [
    { name: 'name', type: 'PDFTextField' },
    { name: 'flag', type: 'PDFCheckBox' },
    { name: 'added', type: 'PDFTextField' },
  ];
  const diff = diffInventory(prev, next);
  assert.deepStrictEqual(diff.added, ['added']);
  assert.deepStrictEqual(diff.removed, ['gone']);
  assert.strictEqual(diff.retyped.length, 1);
  assert.strictEqual(diff.changed, 3);
});

test('validateMapping normalizes fields and rejects bad input', () => {
  const body = validateMapping({
    formNumber: '21-526EZ',
    revision: '2026-01',
    fields: [
      { pdfField: 'F[0].Name', label: 'Name', source: 'auto', group: 'vet.legalLastName', canonicalKey: 'vet.legalLastName', required: true },
      { pdfField: 'F[0].Box', source: 'constant', constantValue: '1', type: 'checkbox' },
      { pdfField: 'F[0].City', label: 'City', source: 'ask', group: 'ask:city' },
      { pdfField: 'F[0].Sig', source: 'dev' },
    ],
  });
  assert.strictEqual(body.fields.length, 4);
  assert.strictEqual(body.fields[0].required, true);
  assert.strictEqual(body.fields[0].source, 'auto');
  assert.strictEqual(body.fields[1].constantValue, '1');
  assert.strictEqual(body.fields[2].source, 'ask');
  assert.strictEqual(body.fields[3].source, 'dev');
  assert.strictEqual(body.schemaVersion, 2);
  // An ask field needs neither a canonicalKey nor a constant.
  assert.doesNotThrow(() =>
    validateMapping({
      formNumber: 'x',
      revision: '1',
      fields: [{ pdfField: 'a' }],
    }),
  );
  assert.throws(() => validateMapping({ formNumber: '', revision: '1', fields: [] }));
  // An auto field with no canonicalKey is invalid.
  assert.throws(() =>
    validateMapping({
      formNumber: 'x',
      revision: '1',
      fields: [{ pdfField: 'a', source: 'auto' }],
    }),
  );
});

test('catalog tracks the core compensation forms', () => {
  assert.ok(isTracked('21-526EZ'));
  assert.ok(isTracked('21-686c'));
  assert.ok(!isTracked('nexus'));
  assert.ok(trackedFormNumbers.length >= 13);
});
