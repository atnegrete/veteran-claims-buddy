'use strict';

const crypto = require('crypto');
const { execFileSync } = require('child_process');
const fs = require('fs');

const { PROJECTS, assertPublishAllowed, toValue } = require('./publish_questionnaire');

function validateRules(rules) {
  if (!rules || typeof rules !== 'object' || Array.isArray(rules)) {
    throw new Error('VA rules file must be an object.');
  }
  if (rules.id !== 'va-rules') throw new Error('VA rules id must be va-rules.');
  if (!Number.isInteger(rules.version) || rules.version < 1) {
    throw new Error('VA rules version must be an integer.');
  }
  if (!['active', 'draft', 'retired'].includes(rules.status)) {
    throw new Error('VA rules status must be active, draft, or retired.');
  }
  if (rules.schemaVersion !== 1) throw new Error('VA rules schemaVersion must be 1.');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(rules.effectiveFrom || '')) {
    throw new Error('VA rules effectiveFrom must be YYYY-MM-DD.');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(rules.retrievedAt || '')) {
    throw new Error('VA rules retrievedAt must be YYYY-MM-DD.');
  }
  if (
    !Number.isInteger(rules.reviewDeadlineYears) ||
    rules.reviewDeadlineYears < 1 ||
    rules.reviewDeadlineYears > 10
  ) {
    throw new Error('reviewDeadlineYears must be from 1 to 10.');
  }
  const expected = {
    supplemental: ['supplementalClaim', '20-0995'],
    higherLevel: ['higherLevelReview', '20-0996'],
    board: ['boardAppeal', '10182'],
  };
  if (!Array.isArray(rules.reviews) || rules.reviews.length !== 3) {
    throw new Error('Three review paths are required.');
  }
  const seen = new Set();
  for (const review of rules.reviews) {
    const pair = expected[review.path];
    if (!pair || review.type !== pair[0] || review.formId !== pair[1] || seen.has(review.path)) {
      throw new Error(`Unknown review path ${review.path}.`);
    }
    seen.add(review.path);
  }
  if (!Array.isArray(rules.sources) || rules.sources.length === 0) {
    throw new Error('A source is required.');
  }
  const sourceIds = new Set();
  for (const source of rules.sources) {
    if (!/^[a-z0-9-]+$/.test(source.id || '') || sourceIds.has(source.id)) {
      throw new Error('Source id is required.');
    }
    sourceIds.add(source.id);
    if (!source.title || typeof source.title !== 'string' || source.title.length > 120) {
      throw new Error(`Source ${source.id} needs a title.`);
    }
    if (!/^https:\/\/www\.va\.gov\//.test(source.url || '')) {
      throw new Error(`Source ${source.id} must be a VA page.`);
    }
  }
  return rules;
}

function assertRulesReplace(existingStatus, projectId) {
  if (existingStatus === 'active' && projectId !== PROJECTS.dev) {
    throw new Error(
      'Refusing to replace VA rules that are already active. Publish a new id.',
    );
  }
}

function contentHash(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function documentFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    fields[key] = toValue(value);
  }
  return fields;
}

function accessToken() {
  return execFileSync('gcloud', ['auth', 'print-access-token'], {
    encoding: 'utf8',
  }).trim();
}

async function api(projectId, url, { method = 'GET', body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken()}`,
      'x-goog-user-project': projectId,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
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

function ruleName(projectId, id) {
  return `projects/${projectId}/databases/(default)/documents/vaRuleVersions/${id}`;
}

function sourceName(projectId, id) {
  return `projects/${projectId}/databases/(default)/documents/vaKnowledgeSources/${id}`;
}

async function existingStatus(projectId, id) {
  try {
    const document = await api(
      projectId,
      `https://firestore.googleapis.com/v1/${ruleName(projectId, id)}`,
    );
    return document.fields?.status?.stringValue || '';
  } catch (error) {
    if (error.status === 404) return '';
    throw error;
  }
}

async function publishRules({ projectId, rules, hash }) {
  const status = await existingStatus(projectId, rules.id);
  assertRulesReplace(status, projectId);
  const stamp = [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }];
  if (!status) stamp.push({ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' });
  const writes = [
    {
      update: {
        name: ruleName(projectId, rules.id),
        fields: documentFields({
          version: rules.version,
          status: rules.status,
          schemaVersion: rules.schemaVersion,
          effectiveFrom: rules.effectiveFrom,
          retrievedAt: rules.retrievedAt,
          reviewDeadlineYears: rules.reviewDeadlineYears,
          reviews: rules.reviews,
          sourceIds: rules.sources.map((source) => source.id),
          contentHash: hash,
        }),
      },
      updateTransforms: stamp,
    },
  ];
  for (const source of rules.sources) {
    writes.push({
      update: {
        name: sourceName(projectId, source.id),
        fields: documentFields({
          title: source.title,
          url: source.url,
          retrievedAt: rules.retrievedAt,
          ruleVersionId: rules.id,
          schemaVersion: 1,
        }),
      },
      updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
    });
  }
  await api(
    projectId,
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
    { method: 'POST', body: { writes } },
  );
  return { projectId, id: rules.id, sources: rules.sources.length };
}

async function main(argv) {
  const projectFlag = argv.indexOf('--project');
  const fileFlag = argv.indexOf('--file');
  const project = projectFlag >= 0 ? argv[projectFlag + 1] : '';
  const file = fileFlag >= 0 ? argv[fileFlag + 1] : '';
  const projectId = assertPublishAllowed({
    project,
    confirmProd: argv.includes('--confirm-prod'),
  });
  if (!file) throw new Error('Pass --file and the VA rules JSON path.');
  const bytes = fs.readFileSync(file);
  const rules = validateRules(JSON.parse(bytes.toString('utf8')));
  const result = await publishRules({
    projectId,
    rules,
    hash: contentHash(bytes),
  });
  console.log(
    `Published ${result.id} (${result.sources} sources) to ${result.projectId}.`,
  );
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = {
  validateRules,
  assertRulesReplace,
  contentHash,
};
