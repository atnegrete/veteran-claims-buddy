'use strict';

// va:forms:publish-mappings - publishes a revision-specific field mapping to
// vaFormMappings/{form}__{revision} (handoff 37.9). Mirrors the other
// publishers (gcloud token + Firestore REST, dev/prod guard). Dev may be
// re-published; prod refuses to replace an existing mapping.

const fs = require('fs');
const {
  PROJECTS,
  assertPublishAllowed,
  parseFormsArgs,
  documentFields,
  firestore,
  mappingDocId,
} = require('./va_forms_common');

const FIELD_TYPES = new Set(['text', 'date', 'checkbox', 'radio']);
const FIELD_SOURCES = new Set(['auto', 'ask', 'constant', 'dev']);

// Pure: validate a mapping file and return a normalized document body. The v2
// schema lists every fillable field with a `source`: `auto` (a certain Veteran
// value from a canonicalKey), `ask` (the Veteran fills it), `constant`, or
// `dev` (signatures / office-use, hidden from the editor). Fields that share a
// `group` are one editor input that fills every matching PDF field.
function validateMapping(mapping) {
  if (!mapping || typeof mapping !== 'object') {
    throw new Error('Mapping file must be an object.');
  }
  if (typeof mapping.formNumber !== 'string' || mapping.formNumber === '') {
    throw new Error('Mapping formNumber is required.');
  }
  if (typeof mapping.revision !== 'string' || mapping.revision === '') {
    throw new Error('Mapping revision is required.');
  }
  if (!Array.isArray(mapping.fields) || mapping.fields.length === 0) {
    throw new Error('Mapping fields are required.');
  }
  const seen = new Set();
  const fields = mapping.fields.map((field) => {
    if (!field || typeof field.pdfField !== 'string' || field.pdfField === '') {
      throw new Error('Each field needs a pdfField.');
    }
    if (seen.has(field.pdfField)) {
      throw new Error(`Duplicate pdfField: ${field.pdfField}`);
    }
    seen.add(field.pdfField);
    const type = field.type || 'text';
    if (!FIELD_TYPES.has(type)) {
      throw new Error(`Field ${field.pdfField} has an unknown type: ${type}`);
    }
    const source =
      field.source ||
      (field.canonicalKey ? 'auto' : field.constantValue !== undefined ? 'constant' : 'ask');
    if (!FIELD_SOURCES.has(source)) {
      throw new Error(`Field ${field.pdfField} has an unknown source: ${source}`);
    }
    if (source === 'auto' && !field.canonicalKey) {
      throw new Error(`Field ${field.pdfField} is auto but has no canonicalKey.`);
    }
    if (source === 'constant' && field.constantValue === undefined) {
      throw new Error(`Field ${field.pdfField} is constant but has no constantValue.`);
    }
    const published = {
      pdfField: field.pdfField,
      label: field.label || field.pdfField,
      group: typeof field.group === 'string' ? field.group : null,
      source,
      canonicalKey: field.canonicalKey || null,
      constantValue: field.constantValue === undefined ? null : String(field.constantValue),
      options: Array.isArray(field.options) ? field.options.map(String) : null,
      maxLength: Number.isInteger(field.maxLength) ? field.maxLength : null,
      required: field.required === true,
      type,
    };
    if (typeof field.role === 'string' && field.role !== '') published.role = field.role;
    return published;
  });
  const body = {
    formNumber: mapping.formNumber,
    revisionId: mapping.revision,
    fields,
    schemaVersion: 2,
  };
  if (mapping.download && typeof mapping.download === 'object') {
    body.download = mapping.download;
  }
  return body;
}

function mappingName(projectId, id) {
  return `projects/${projectId}/databases/(default)/documents/vaFormMappings/${id}`;
}

async function exists(projectId, id) {
  try {
    await firestore(projectId, `https://firestore.googleapis.com/v1/${mappingName(projectId, id)}`);
    return true;
  } catch (error) {
    if (error.status === 404) return false;
    throw error;
  }
}

async function publishMapping(args, deps = {}) {
  const projectId = assertPublishAllowed(args);
  if (!args.file) throw new Error('Pass --file with the mapping JSON path.');
  const body = validateMapping(JSON.parse(fs.readFileSync(args.file, 'utf8')));
  const id = mappingDocId(body.formNumber, body.revisionId);
  const check = deps.exists ?? exists;
  if (projectId === PROJECTS.prod && (await check(projectId, id))) {
    throw new Error('Refusing to replace an existing production mapping.');
  }
  const commit = deps.commit ?? (async (fields) => {
    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
    await firestore(projectId, url, {
      method: 'POST',
      body: {
        writes: [
          {
            update: { name: mappingName(projectId, id), fields },
            updateTransforms: [
              { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
            ],
          },
        ],
      },
    });
  });
  await commit(documentFields(body));
  return { projectId, id, fields: body.fields.length };
}

// Publishes every authored mapping in mappings/va-forms/*.mapping.json. One
// failing mapping does not stop the rest; failures are summarized at the end.
async function publishAll(args, deps = {}) {
  const dir = require('path').join(__dirname, '..', 'mappings', 'va-forms');
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.mapping.json'))
    .sort();
  const published = [];
  const failed = [];
  for (const file of files) {
    try {
      const result = await publishMapping({ ...args, file: require('path').join(dir, file) }, deps);
      published.push(result);
      console.log(`Published vaFormMappings/${result.id} (${result.fields} fields).`);
    } catch (error) {
      failed.push({ file, message: error.message });
      console.error(`SKIPPED ${file}: ${error.message}`);
    }
  }
  console.log(`\nDone: ${published.length} published, ${failed.length} failed.`);
  return { published, failed };
}

async function main(argv) {
  const { loadEnv, sniffProject } = require('./load_env');
  loadEnv(sniffProject(argv));
  const args = parseFormsArgs(argv);
  if (!args.file) {
    await publishAll(args);
    return;
  }
  const result = await publishMapping(args);
  console.log(`Published vaFormMappings/${result.id} (${result.fields} fields) to ${result.projectId}.`);
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { validateMapping, publishMapping, publishAll };
