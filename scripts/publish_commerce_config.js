'use strict';

// Publishes commerceConfig/current: the business prices and feature flags the
// app and Cloud Functions read. Mirrors publish_questionnaire.js (Firestore
// REST + a gcloud access token) and reuses its project guard.

const { execFileSync } = require('child_process');
const fs = require('fs');
const {
  assertPublishAllowed,
  parseArgs,
  toValue,
} = require('./publish_questionnaire');

const INT_FIELDS = [
  'digitalClaimPackageBusinessPriceCents',
  'premiumMonthlyBusinessPriceCents',
  'premiumYearlyBusinessPriceCents',
  'caseUnlockPremiumDays',
];
const BOOL_FIELDS = ['premiumEnabled', 'caseUnlockEnabled'];

function validateConfig(config) {
  if (!config || typeof config !== 'object') {
    throw new Error('Commerce config file must be an object.');
  }
  if (typeof config.id !== 'string' || config.id.trim() === '') {
    throw new Error('Commerce config id is required.');
  }
  for (const field of INT_FIELDS) {
    if (!Number.isInteger(config[field]) || config[field] <= 0) {
      throw new Error(`Commerce config ${field} must be a positive integer.`);
    }
  }
  for (const field of BOOL_FIELDS) {
    if (typeof config[field] !== 'boolean') {
      throw new Error(`Commerce config ${field} must be a boolean.`);
    }
  }
  if (!Number.isInteger(config.schemaVersion)) {
    throw new Error('Commerce config schemaVersion must be an integer.');
  }
  return config;
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

function configName(projectId, id) {
  return `projects/${projectId}/databases/(default)/documents/commerceConfig/${id}`;
}

async function alreadyExists(projectId, id) {
  try {
    await api(projectId, `https://firestore.googleapis.com/v1/${configName(projectId, id)}`);
    return true;
  } catch (error) {
    if (error.status === 404) return false;
    throw error;
  }
}

async function publish({ projectId, config }) {
  const existed = await alreadyExists(projectId, config.id);
  const { id, ...data } = config;
  const stamp = [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }];
  if (!existed) {
    stamp.push({ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' });
  }
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  await api(projectId, url, {
    method: 'POST',
    body: {
      writes: [
        {
          update: {
            name: configName(projectId, id),
            fields: documentFields(data),
          },
          updateTransforms: stamp,
        },
      ],
    },
  });
  return { projectId, id };
}

async function main(argv) {
  const args = parseArgs(argv);
  const projectId = assertPublishAllowed(args);
  if (!args.file) throw new Error('Pass --file and the commerce config JSON path.');
  const config = validateConfig(JSON.parse(fs.readFileSync(args.file, 'utf8')));
  const result = await publish({ projectId, config });
  console.log(`Published commerceConfig/${result.id} to ${result.projectId}.`);
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { validateConfig, documentFields, publish };
