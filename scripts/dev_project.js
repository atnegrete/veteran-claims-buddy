const DEV_PROJECT_ID = 'veteran-claims-buddy-dev';
const DEV_STORAGE_BUCKET = 'veteran-claims-buddy-dev.firebasestorage.app';

function assertDevResetAllowed({ env = process.env, confirmed = false } = {}) {
  if (!confirmed) {
    throw new Error(
      'Refusing to reset. Pass --confirm-dev-reset.',
    );
  }
  const fromEnv = env.GOOGLE_CLOUD_PROJECT || env.GCLOUD_PROJECT || '';
  if (fromEnv.toLowerCase().includes('prod') || DEV_PROJECT_ID.includes('prod')) {
    throw new Error(`Refusing to reset a production project (${fromEnv || DEV_PROJECT_ID}).`);
  }
  if (fromEnv && fromEnv !== DEV_PROJECT_ID) {
    throw new Error(
      `Refusing to reset project ${fromEnv}. Expected ${DEV_PROJECT_ID}.`,
    );
  }
  return DEV_PROJECT_ID;
}

function uidFromArgs(argv) {
  const index = argv.indexOf('--uid');
  const uid = index >= 0 ? argv[index + 1] : '';
  if (!uid || uid.startsWith('--')) {
    throw new Error('Pass --uid and the account id.');
  }
  return uid;
}

module.exports = {
  DEV_PROJECT_ID,
  DEV_STORAGE_BUCKET,
  assertDevResetAllowed,
  uidFromArgs,
};
