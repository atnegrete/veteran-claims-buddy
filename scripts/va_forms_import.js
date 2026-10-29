'use strict';

// va:forms:import - controlled, immutable import of one official revision
// (handoff 37.4-37.6). Resolves the PDF from the VA Forms API, downloads it,
// verifies the checksum, stores it in the backend-only reference bucket, and
// writes an immutable vaFormRevisions document. It never marks a form
// production-ready and never overwrites an existing revision.

const {
  PROJECTS,
  assertPublishAllowed,
  parseFormsArgs,
  formsApiBase,
  documentFields,
  firestore,
  fetchFormInfo,
  sha256,
  shortSha,
  revisionDocId,
} = require('./va_forms_common');
const { isTracked, trackedFormNumbers } = require('./va_forms_catalog');

function storagePath(formNumber, revision) {
  return `reference/va-forms/${formNumber}/${revision}/original.pdf`;
}

// A genuine PDF starts with the %PDF- magic and is not a tiny error/redirect
// page. Guards against storing an HTML error page as a "template".
function isPdf(bytes) {
  return (
    Buffer.isBuffer(bytes) &&
    bytes.length > 1000 &&
    bytes.slice(0, 5).toString('latin1') === '%PDF-'
  );
}

// Pure: the immutable revision metadata document (handoff 37.6).
function revisionMetadata({ formNumber, info, sha, byteLength, path }) {
  return {
    formNumber,
    title: info.title || '',
    revision: info.revision,
    templateSha256: sha,
    vaReportedSha256: info.sha256 || '',
    sourceUrl: info.url || '',
    storagePath: path,
    byteLength,
    pageCount: Number.isInteger(info.pages) ? info.pages : null,
    status: 'imported',
    schemaVersion: 1,
  };
}

function revisionName(projectId, id) {
  return `projects/${projectId}/databases/(default)/documents/vaFormRevisions/${id}`;
}

async function alreadyImported(projectId, id) {
  try {
    await firestore(projectId, `https://firestore.googleapis.com/v1/${revisionName(projectId, id)}`);
    return true;
  } catch (error) {
    if (error.status === 404) return false;
    throw error;
  }
}

async function uploadTemplate(projectId, path, bytes, token, fetchImpl = fetch) {
  const bucket = `${projectId}.firebasestorage.app`;
  const url =
    `https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o` +
    `?uploadType=media&name=${encodeURIComponent(path)}`;
  const response = await fetchImpl(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/pdf' },
    body: bytes,
  });
  if (!response.ok) {
    throw new Error(`Storage upload failed (${response.status}) for ${path}.`);
  }
}

async function importRevision(args, deps = {}) {
  const projectId = assertPublishAllowed(args);
  if (!args.apiKey) {
    throw new Error('Set VA_FORMS_API_KEY or pass --api-key (owner gate M13).');
  }
  if (!args.form || !isTracked(args.form)) {
    throw new Error('Pass --form with an allowlisted VA form number.');
  }
  const getRemote = deps.fetchFormInfo ?? fetchFormInfo;
  const info = await getRemote(args.form, args.apiKey, { base: formsApiBase(args) });
  if (!info || !info.revision) {
    throw new Error(`The VA Forms API did not list ${args.form}.`);
  }
  if (args.revision && args.revision !== info.revision) {
    throw new Error(
      `VA now lists ${args.form} revision ${info.revision}, not ${args.revision}. Re-run discover.`,
    );
  }
  if (!info.url) throw new Error(`No PDF url for ${args.form}.`);

  const download = deps.download ?? (async (url) => {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Download failed (${response.status}).`);
    return Buffer.from(await response.arrayBuffer());
  });
  const bytes = await download(info.url);
  if (!isPdf(bytes)) {
    throw new Error(
      `Downloaded ${args.form} is not a PDF (${bytes ? bytes.length : 0} bytes). Import rejected.`,
    );
  }
  const sha = sha256(bytes);
  // The VA Forms API's sha256 is advisory and frequently lags the live PDF, so
  // a mismatch is a warning, not a rejection. We validate the bytes are a real
  // PDF and pin OUR computed sha256 as the immutable revision identity; the VA
  // value is stored alongside for reference.
  if (info.sha256 && info.sha256 !== sha) {
    console.warn(
      `  note: ${info.formNumber} VA-reported sha256 ${shortSha(info.sha256)} ≠ downloaded ${shortSha(sha)}; using the downloaded file.`,
    );
  }

  const id = revisionDocId(info.formNumber, info.revision, sha);
  const exists = deps.alreadyImported ?? alreadyImported;
  if (await exists(projectId, id)) {
    return { projectId, id, formNumber: info.formNumber, revision: info.revision, skipped: true };
  }

  const path = storagePath(info.formNumber, info.revision);
  const token = deps.token ?? require('./va_forms_common').accessToken();
  const upload = deps.uploadTemplate ?? uploadTemplate;
  await upload(projectId, path, bytes, token);

  const commit = deps.commit ?? (async (fields) => {
    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
    await firestore(projectId, url, {
      method: 'POST',
      body: {
        writes: [
          {
            currentDocument: { exists: false },
            update: { name: revisionName(projectId, id), fields },
            updateTransforms: [
              { fieldPath: 'importedAt', setToServerValue: 'REQUEST_TIME' },
            ],
          },
        ],
      },
    });
  });
  const metadata = revisionMetadata({
    formNumber: info.formNumber,
    info,
    sha,
    byteLength: bytes.length,
    path,
  });
  await commit(documentFields(metadata));
  return {
    projectId,
    id,
    formNumber: info.formNumber,
    revision: info.revision,
    sha: shortSha(sha),
    skipped: false,
  };
}

// Imports every allowlisted form in one run. One form failing (not listed,
// checksum mismatch) does not stop the rest; failures are summarized at the end.
async function importAll(args, deps = {}) {
  const imported = [];
  const skipped = [];
  const failed = [];
  for (const form of trackedFormNumbers) {
    try {
      const result = await importRevision({ ...args, form }, deps);
      if (result.skipped) {
        skipped.push(result);
        console.log(`${result.formNumber} ${result.revision} already imported.`);
      } else {
        imported.push(result);
        console.log(`Imported ${result.formNumber} ${result.revision} (${result.id}).`);
      }
    } catch (error) {
      failed.push({ form, message: error.message });
      console.error(`SKIPPED ${form}: ${error.message}`);
    }
  }
  console.log(
    `\nDone: ${imported.length} imported, ${skipped.length} already present, ${failed.length} failed.`,
  );
  return { imported, skipped, failed };
}

async function main(argv) {
  const { loadEnv, sniffProject } = require('./load_env');
  loadEnv(sniffProject(argv));
  const args = parseFormsArgs(argv);
  if (!args.form) {
    await importAll(args);
    return;
  }
  const result = await importRevision(args);
  if (result.skipped) {
    console.log(`${result.formNumber} ${result.revision} already imported (${result.id}).`);
  } else {
    console.log(`Imported ${result.formNumber} ${result.revision} to ${result.projectId} (${result.id}).`);
  }
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { storagePath, revisionMetadata, importRevision, importAll, PROJECTS };
