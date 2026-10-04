'use strict';

const { execFileSync } = require('child_process');

const { DEV_PROJECT_ID, assertDevResetAllowed } = require('./dev_project');

const CURRENT_DEFINITION = 'condition-discovery-v2';
const QUESTIONNAIRE_ID = 'condition-discovery';

function accessToken() {
  return execFileSync('gcloud', ['auth', 'print-access-token'], {
    encoding: 'utf8',
  }).trim();
}

async function api(url, { method = 'GET', body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken()}`,
      'x-goog-user-project': DEV_PROJECT_ID,
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

function documentUrl(name) {
  return `https://firestore.googleapis.com/v1/${name}`;
}

function stringField(document, key) {
  const value = document.fields?.[key];
  return value?.stringValue || '';
}

async function listDocuments(parent, collectionId) {
  const documents = [];
  let pageToken = '';
  do {
    const url = new URL(`${documentUrl(parent)}/${collectionId}`);
    url.searchParams.set('pageSize', '100');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const page = await api(url);
    documents.push(...(page.documents || []));
    pageToken = page.nextPageToken || '';
  } while (pageToken);
  return documents;
}

async function deleteDocumentTree(name) {
  const listed = await api(`${documentUrl(name)}:listCollectionIds`, {
    method: 'POST',
    body: {},
  });
  for (const collectionId of listed.collectionIds || []) {
    for (const document of await listDocuments(name, collectionId)) {
      await deleteDocumentTree(document.name);
    }
  }
  try {
    await api(documentUrl(name), { method: 'DELETE' });
    return true;
  } catch (error) {
    if (error.status === 404) return false;
    throw error;
  }
}

async function clearStaleQuestionnaires() {
  const parent = `projects/${DEV_PROJECT_ID}/databases/(default)/documents`;
  const users = await listDocuments(parent, 'users');
  let cleared = 0;
  for (const user of users) {
    const questionnaireName = `${user.name}/questionnaires/${QUESTIONNAIRE_ID}`;
    let questionnaire;
    try {
      questionnaire = await api(documentUrl(questionnaireName));
    } catch (error) {
      if (error.status === 404) continue;
      throw error;
    }
    const definitionId = stringField(questionnaire, 'definitionId');
    if (definitionId === CURRENT_DEFINITION) continue;
    const conditions = await listDocuments(user.name, 'conditions');
    const staleConditions = conditions.filter(
      (document) =>
        stringField(document, 'sourceQuestionnaireId') === QUESTIONNAIRE_ID,
    );
    const staleIds = new Set(
      staleConditions.map((document) => document.name.split('/').pop()),
    );
    for (const document of staleConditions) {
      await api(documentUrl(document.name), { method: 'DELETE' });
    }
    const issues = await listDocuments(user.name, 'claimIssues');
    for (const document of issues) {
      const conditionId =
        stringField(document, 'conditionId') || document.name.split('/').pop();
      if (!staleIds.has(conditionId)) continue;
      await api(documentUrl(document.name), { method: 'DELETE' });
    }
    await deleteDocumentTree(questionnaireName);
    cleared += 1;
    console.log(
      `Cleared ${definitionId || 'an empty'} questionnaire for ${user.name.split('/').pop()}.`,
    );
  }
  return cleared;
}

async function main() {
  assertDevResetAllowed({ confirmed: process.argv.includes('--confirm-dev-reset') });
  const cleared = await clearStaleQuestionnaires();
  console.log(`Cleared ${cleared} development questionnaire${cleared === 1 ? '' : 's'}.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { CURRENT_DEFINITION };
