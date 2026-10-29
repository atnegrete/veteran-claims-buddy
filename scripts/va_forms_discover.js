'use strict';

// va:forms:discover - owner-triggered, read-only revision check (handoff 37.3).
// Calls the VA Forms API for every allowlisted form, compares the VA-reported
// revision/checksum to what is already imported into vaFormRevisions, and
// prints a deterministic report. It performs NO activation and writes nothing.

const {
  PROJECTS,
  parseFormsArgs,
  formsApiBase,
  firestore,
  fetchFormInfo,
} = require('./va_forms_common');
const { trackedFormNumbers } = require('./va_forms_catalog');

// Pure: decide a form's status from what we know vs what the VA reports.
function classifyForm(known, remote) {
  if (!remote || !remote.revision) {
    return { status: 'missing', action: 'VA source did not list this form.' };
  }
  if (!known) {
    return {
      status: 'NEW',
      action: `import --form ${remote.formNumber} --revision ${remote.revision}`,
    };
  }
  if (known.revision !== remote.revision || known.sha256 !== remote.sha256) {
    return {
      status: 'NEW REVISION DETECTED',
      action: `import --form ${remote.formNumber} --revision ${remote.revision}`,
    };
  }
  return { status: 'unchanged', action: '' };
}

function projectFromArgs(args) {
  const projectId = PROJECTS[args.project];
  if (!projectId) throw new Error('Pass --project dev or --project prod.');
  return projectId;
}

// The most recently imported revision we know for a form.
async function knownRevision(projectId, formNumber) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: 'vaFormRevisions' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'formNumber' },
          op: 'EQUAL',
          value: { stringValue: formNumber },
        },
      },
      orderBy: [{ field: { fieldPath: 'revision' }, direction: 'DESCENDING' }],
      limit: 1,
    },
  };
  const rows = await firestore(projectId, url, { method: 'POST', body });
  const doc = rows.find((row) => row.document)?.document;
  if (!doc) return null;
  // Compare the VA-reported sha to what the VA reported when we imported (not to
  // our own computed templateSha256, which intentionally differs because the VA
  // Forms API's hash lags the live PDF). Revision date is the primary signal.
  return {
    revision: doc.fields?.revision?.stringValue || '',
    sha256: doc.fields?.vaReportedSha256?.stringValue || '',
  };
}

async function report(args, deps = {}) {
  const projectId = projectFromArgs(args);
  if (!args.apiKey) {
    throw new Error('Set VA_FORMS_API_KEY or pass --api-key (owner gate M13).');
  }
  const getKnown = deps.knownRevision ?? knownRevision;
  const getRemote = deps.fetchFormInfo ?? fetchFormInfo;
  const base = formsApiBase(args);
  const lines = [
    'VA FORM DISCOVERY',
    `Source: ${args.sandbox ? 'sandbox' : 'production'} (${base})`,
    '',
  ];
  const results = [];
  for (const formNumber of trackedFormNumbers) {
    const known = await getKnown(projectId, formNumber);
    const remote = await getRemote(formNumber, args.apiKey, { base });
    const verdict = classifyForm(known, remote);
    results.push({ formNumber, known, remote, verdict });
    lines.push(formNumber);
    lines.push(`  Known revision: ${known ? known.revision : '(none)'}`);
    lines.push(`  VA revision:    ${remote ? remote.revision : '(not listed)'}`);
    lines.push(`  Status: ${verdict.status}`);
    if (remote && remote.revision) {
      if (verdict.action) {
        lines.push(
          `  Action: va:forms:import -- --form ${formNumber} --revision ${remote.revision}`,
        );
      }
    } else {
      lines.push('  Action: not listed by the VA Forms API; check the form number.');
    }
    lines.push('');
  }
  return { projectId, results, text: lines.join('\n') };
}

async function main(argv) {
  const { loadEnv, sniffProject } = require('./load_env');
  loadEnv(sniffProject(argv));
  const args = parseFormsArgs(argv);
  const result = await report(args);
  console.log(result.text);
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { classifyForm, report };
