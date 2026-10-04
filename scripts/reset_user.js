const { execFileSync } = require('child_process');

const {
  DEV_PROJECT_ID,
  DEV_STORAGE_BUCKET,
  assertDevResetAllowed,
  uidFromArgs,
} = require('./dev_project');

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

async function deleteDocumentTree(name) {
  const listed = await api(`${documentUrl(name)}:listCollectionIds`, {
    method: 'POST',
    body: {},
  });
  for (const collectionId of listed.collectionIds || []) {
    let pageToken = '';
    do {
      const url = new URL(`${documentUrl(name)}/${collectionId}`);
      url.searchParams.set('pageSize', '100');
      if (pageToken) url.searchParams.set('pageToken', pageToken);
      const page = await api(url);
      for (const document of page.documents || []) {
        await deleteDocumentTree(document.name);
      }
      pageToken = page.nextPageToken || '';
    } while (pageToken);
  }
  try {
    await api(documentUrl(name), { method: 'DELETE' });
    return true;
  } catch (error) {
    if (error.status === 404) return false;
    throw error;
  }
}

async function deleteStorage(uid) {
  const prefix = `users/${uid}/`;
  const url = new URL(
    `https://storage.googleapis.com/storage/v1/b/${DEV_STORAGE_BUCKET}/o`,
  );
  url.searchParams.set('prefix', prefix);
  let pageToken = '';
  let count = 0;
  do {
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    let page;
    try {
      page = await api(url);
    } catch (error) {
      if (error.status === 404) return 0;
      throw error;
    }
    for (const item of page.items || []) {
      await api(
        `https://storage.googleapis.com/storage/v1/b/${DEV_STORAGE_BUCKET}/o/${encodeURIComponent(item.name)}`,
        { method: 'DELETE' },
      );
      count += 1;
    }
    pageToken = page.nextPageToken || '';
  } while (pageToken);
  return count;
}

async function deleteAuthUser(uid) {
  try {
    await api(
      `https://identitytoolkit.googleapis.com/v1/projects/${DEV_PROJECT_ID}/accounts:delete`,
      { method: 'POST', body: { localId: uid } },
    );
    return true;
  } catch (error) {
    if (error.status === 400 && /USER_NOT_FOUND|not found/i.test(error.message)) {
      return false;
    }
    throw error;
  }
}

async function main() {
  const confirmed = process.argv.includes('--confirm-dev-reset');
  assertDevResetAllowed({ confirmed });
  const uid = uidFromArgs(process.argv);
  const userPath = `projects/${DEV_PROJECT_ID}/databases/(default)/documents/users/${uid}`;
  const removedDoc = await deleteDocumentTree(userPath);
  const storageFiles = await deleteStorage(uid);
  const removedAuth = await deleteAuthUser(uid);
  console.log(
    `Reset ${uid} on ${DEV_PROJECT_ID}. Firestore user ${removedDoc ? 'removed' : 'was already gone'}. Storage files removed: ${storageFiles}. Auth account ${removedAuth ? 'removed' : 'was already gone'}. Reference data was kept.`,
  );
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exit(1);
  });
}

module.exports = { deleteDocumentTree, deleteStorage, deleteAuthUser };
