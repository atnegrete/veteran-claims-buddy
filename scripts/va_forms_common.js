'use strict';

// Shared helpers for the va:forms:* tooling. Reuses the project guard and the
// Firestore value encoder from publish_questionnaire.js so the acquisition
// scripts behave exactly like the other publishers (gcloud access token +
// Firestore REST, dev/prod guard, --confirm-prod for prod).

const { execFileSync } = require('child_process');
const crypto = require('crypto');
const { PROJECTS, assertPublishAllowed, toValue } = require('./publish_questionnaire');

// The VA Forms API is open data (public form metadata, no PII). The sandbox and
// production hosts return the same real form catalog; the only difference is the
// host a given key is authorized for. A sandbox key (immediate, no approval)
// works against the sandbox host; a production key needs a production-access
// request. Either is fine for us: we only read form metadata + the public PDF
// url, and the PDFs download from VA's public web server with no key at all.
const VA_FORMS_API = 'https://api.va.gov/services/va_forms/v0/forms';
const VA_FORMS_API_SANDBOX =
  'https://sandbox-api.va.gov/services/va_forms/v0/forms';

function parseFormsArgs(argv) {
  function flag(name) {
    const index = argv.indexOf(name);
    return index >= 0 ? argv[index + 1] : '';
  }
  return {
    project: flag('--project'),
    form: flag('--form'),
    revision: flag('--revision'),
    file: flag('--file'),
    apiKey: flag('--api-key') || process.env.VA_FORMS_API_KEY || '',
    sandbox: argv.includes('--sandbox') || process.env.VA_FORMS_API_SANDBOX === '1',
    confirmProd: argv.includes('--confirm-prod'),
  };
}

// The VA Forms API host to call for this run. `--sandbox` (or
// VA_FORMS_API_SANDBOX=1) selects the sandbox host for a sandbox key.
function formsApiBase(args) {
  return args && args.sandbox ? VA_FORMS_API_SANDBOX : VA_FORMS_API;
}

function documentFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    fields[key] = toValue(value);
  }
  return fields;
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function shortSha(sha) {
  return (sha || '').slice(0, 12);
}

// A form's number can contain characters that are awkward in a document id
// (none today, but keep it defensive and stable).
function safeFormId(formNumber) {
  return String(formNumber).replace(/[^A-Za-z0-9-]/g, '_');
}

function revisionDocId(formNumber, revision, sha) {
  return `${safeFormId(formNumber)}__${revision}__${shortSha(sha)}`;
}

function mappingDocId(formNumber, revision) {
  return `${safeFormId(formNumber)}__${revision}`;
}

function accessToken() {
  return execFileSync('gcloud', ['auth', 'print-access-token'], {
    encoding: 'utf8',
  }).trim();
}

// Retries a network call a few times on a transient failure (a thrown "fetch
// failed", DNS, reset). An HTTP error with a status is not retried; the caller
// decides on those. Keeps the acquisition scripts resilient and repeatable.
async function withRetry(fn, { tries = 3, label = 'request' } = {}) {
  let lastError;
  for (let attempt = 1; attempt <= tries; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      if (error && typeof error.status === 'number') throw error;
      lastError = error;
      if (attempt < tries) {
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
      }
    }
  }
  const error = new Error(
    `${label} failed after ${tries} tries: ${lastError ? lastError.message : 'unknown error'}`,
  );
  error.cause = lastError;
  throw error;
}

async function firestore(projectId, url, { method = 'GET', body } = {}) {
  const response = await withRetry(
    () =>
      fetch(url, {
        method,
        headers: {
          Authorization: `Bearer ${accessToken()}`,
          'x-goog-user-project': projectId,
          'Content-Type': 'application/json',
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      }),
    { label: 'Firestore request' },
  );
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const message = data.error?.message || text || response.statusText;
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  return data;
}

// Calls the VA Forms API for one form and returns the current revision info, or
// null when the VA does not list it. The API is open-data; the key only meters
// usage (handoff 37.3).
async function fetchFormInfo(
  formNumber,
  apiKey,
  { base = VA_FORMS_API, fetchImpl = fetch } = {},
) {
  const url = `${base}?query=${encodeURIComponent(formNumber)}`;
  const response = await withRetry(
    () => fetchImpl(url, { headers: { apikey: apiKey } }),
    { label: `VA Forms API (${formNumber})` },
  );
  if (!response.ok) {
    throw new Error(`VA Forms API ${response.status} for ${formNumber}.`);
  }
  const body = await response.json();
  const rows = Array.isArray(body.data) ? body.data : [];
  const target = normalizeFormName(formNumber);
  const match = rows.find(
    (row) => normalizeFormName(row.attributes?.form_name) === target,
  );
  if (!match) return null;
  const attrs = match.attributes || {};
  return {
    // Our canonical catalog number (e.g. 10182), not the API's form_name
    // (e.g. VA10182), so revisions, mappings, and the app all key on the same
    // value. apiFormName keeps the VA-reported name for reference.
    formNumber,
    apiFormName: attrs.form_name || formNumber,
    title: attrs.title || '',
    url: attrs.url || '',
    revision: attrs.last_revision_on || '',
    sha256: attrs.sha256 || '',
    pages: Number.isInteger(attrs.pages) ? attrs.pages : null,
  };
}

// The VA Forms API reports some numbers with a "VA" prefix and/or different
// punctuation (e.g. VA10182 for 10182). Normalize both sides so an allowlisted
// number matches regardless of that cosmetic difference.
function normalizeFormName(value) {
  return String(value || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .replace(/^VA/, '');
}

module.exports = {
  PROJECTS,
  VA_FORMS_API,
  VA_FORMS_API_SANDBOX,
  formsApiBase,
  normalizeFormName,
  assertPublishAllowed,
  parseFormsArgs,
  documentFields,
  sha256,
  shortSha,
  safeFormId,
  revisionDocId,
  mappingDocId,
  accessToken,
  firestore,
  fetchFormInfo,
};
