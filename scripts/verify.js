const { DEV_PROJECT_ID, assertDevResetAllowed } = require('./dev_project');

const fromEnv = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || '';
let permitted = false;
try {
  assertDevResetAllowed({
    confirmed: true,
    env: fromEnv ? process.env : { GOOGLE_CLOUD_PROJECT: DEV_PROJECT_ID },
  });
  permitted = !fromEnv || fromEnv === DEV_PROJECT_ID;
} catch (error) {
  permitted = false;
  console.error(error.message);
}

console.log(`Resolved project: ${fromEnv || '(not set; scripts target the dev project)'}`);
console.log(`Expected dev project: ${DEV_PROJECT_ID}`);
console.log('Authenticated caller: available when Application Default Credentials are set');
console.log(`Destructive operations permitted: ${permitted ? 'yes' : 'no'}`);
if (!permitted) process.exit(1);
