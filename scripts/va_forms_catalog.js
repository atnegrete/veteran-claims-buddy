'use strict';

// The supported-form allowlist for the acquisition tooling (handoff 37.29).
// Mirrors the v1 and v1-support forms in app/lib/forms/form_catalog.dart. The
// nexus letter is intentionally absent: it is evidence the app drafts, not an
// official VA PDF to import. Exact availability and revision always come from
// the authoritative VA Forms API at import time.

const trackedForms = [
  { formNumber: '21-0966', benefit: 'compensation' },
  { formNumber: '21-526EZ', benefit: 'compensation' },
  { formNumber: '21-4138', benefit: 'compensation' },
  { formNumber: '21-10210', benefit: 'compensation' },
  { formNumber: '21-0781', benefit: 'compensation' },
  { formNumber: '21-4142', benefit: 'compensation' },
  { formNumber: '21-4142a', benefit: 'compensation' },
  { formNumber: '21-8940', benefit: 'compensation' },
  { formNumber: '21-4192', benefit: 'compensation' },
  { formNumber: '20-0995', benefit: 'appeals' },
  { formNumber: '20-0996', benefit: 'appeals' },
  { formNumber: '10182', benefit: 'appeals' },
  { formNumber: '20-10206', benefit: 'records' },
  { formNumber: '21-686c', benefit: 'dependents' },
  { formNumber: '21-674', benefit: 'dependents' },
  { formNumber: '21-0845', benefit: 'compensation' },
];

const trackedFormNumbers = trackedForms.map((form) => form.formNumber);

function isTracked(formNumber) {
  return trackedFormNumbers.includes(formNumber);
}

module.exports = { trackedForms, trackedFormNumbers, isTracked };
