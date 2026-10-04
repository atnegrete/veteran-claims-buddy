const { execFileSync } = require('child_process');

const { DEV_PROJECT_ID, assertDevResetAllowed, uidFromArgs } = require('./dev_project');
const { toValue } = require('./publish_questionnaire');
const { deleteDocumentTree } = require('./reset_user');
const { scenarioById } = require('./seed_scenarios');

function accessToken() {
  return execFileSync('gcloud', ['auth', 'print-access-token'], {
    encoding: 'utf8',
  }).trim();
}

function fieldsOf(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) fields[key] = toValue(value);
  return fields;
}

async function writeDocument(uid, path, data) {
  const suffix = path ? `/${path}` : '';
  const name = `projects/${DEV_PROJECT_ID}/databases/(default)/documents/users/${uid}${suffix}`;
  const url = new URL(`https://firestore.googleapis.com/v1/${name}`);
  for (const key of Object.keys(data)) url.searchParams.append('updateMask.fieldPaths', key);
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken()}`,
      'x-goog-user-project': DEV_PROJECT_ID,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: fieldsOf(data) }),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || response.statusText);
  }
}

async function seedUser({ uid, scenarioId, replace = false }) {
  const scenario = scenarioById(scenarioId);
  if (replace) {
    await deleteDocumentTree(
      `projects/${DEV_PROJECT_ID}/databases/(default)/documents/users/${uid}`,
    );
  }
  await writeDocument(uid, '', scenario.user);
  for (const document of scenario.documents) {
    await writeDocument(uid, document.path, document.data);
  }
  return scenario;
}

async function main(argv) {
  assertDevResetAllowed({ confirmed: argv.includes('--confirm-dev-reset') });
  const uid = uidFromArgs(argv);
  const scenarioFlag = argv.indexOf('--scenario');
  const scenarioId = scenarioFlag >= 0 ? argv[scenarioFlag + 1] : '';
  const scenario = await seedUser({
    uid,
    scenarioId,
    replace: argv.includes('--replace'),
  });
  console.log(`Seeded scenario ${scenario.id} (${scenario.label}) on ${uid} in ${DEV_PROJECT_ID}.`);
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message || error);
    process.exit(1);
  });
}

module.exports = { fieldsOf, seedUser };
