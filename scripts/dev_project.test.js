const test = require('node:test');
const assert = require('node:assert/strict');
const { assertDevResetAllowed, uidFromArgs } = require('./dev_project');

test('reset refuses without the confirmation flag', () => {
  assert.throws(
    () => assertDevResetAllowed({ confirmed: false }),
    /confirm-dev-reset/,
  );
});

test('reset refuses a production project id', () => {
  assert.throws(
    () =>
      assertDevResetAllowed({
        confirmed: true,
        env: { GOOGLE_CLOUD_PROJECT: 'veteran-claims-buddy-prod' },
      }),
    /production/,
  );
});

test('reset refuses a project id that is not the dev project', () => {
  assert.throws(
    () =>
      assertDevResetAllowed({
        confirmed: true,
        env: { GCLOUD_PROJECT: 'some-other-project' },
      }),
    /some-other-project/,
  );
});

test('reset allows the dev project when confirmed', () => {
  assert.equal(
    assertDevResetAllowed({
      confirmed: true,
      env: { GOOGLE_CLOUD_PROJECT: 'veteran-claims-buddy-dev' },
    }),
    'veteran-claims-buddy-dev',
  );
});

test('uid comes from --uid', () => {
  assert.equal(uidFromArgs(['--uid', 'user-1', '--confirm-dev-reset']), 'user-1');
  assert.throws(() => uidFromArgs(['--confirm-dev-reset']), /--uid/);
});
