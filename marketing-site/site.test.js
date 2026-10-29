const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;

test('the public pages keep the draft banner, the prices, and the disclaimer', () => {
  execFileSync(process.execPath, [path.join(root, 'build.js')], { cwd: path.join(root, '..') });
  const home = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const pricing = fs.readFileSync(path.join(root, 'pricing/index.html'), 'utf8');
  const privacy = fs.readFileSync(path.join(root, 'privacy/index.html'), 'utf8');
  const sitemap = fs.readFileSync(path.join(root, 'sitemap.xml'), 'utf8');
  assert.match(home, /Draft\. A lawyer has not reviewed this site\./);
  assert.match(home, /Organize the claim\. See the next step\./);
  assert.match(home, /assets\/hero\.jpg/);
  assert.match(home, /summary_large_image/);
  assert.match(home, /not affiliated with or endorsed by the U\.S\. Department of Veterans Affairs/);
  assert.match(home, /does not file it/);
  assert.match(fs.readFileSync(path.join(root, 'faq/index.html'), 'utf8'), /<details/);
  assert.match(pricing, /\$250/);
  assert.match(pricing, /\$29\.99/);
  assert.match(pricing, /\$234\.99/);
  assert.match(pricing, /\$9\.95/);
  assert.match(pricing, /Buying is not open in the app yet/);
  assert.match(privacy, /support@veteranclaimsbuddy\.com/);
  assert.match(privacy, /We do not sell your personal information/);
  assert.match(sitemap, /https:\/\/veteranclaimsbuddy\.com\/privacy\//);
  assert.equal(
    fs.readFileSync(path.join(root, 'assets/logo-mark.svg'), 'utf8'),
    fs.readFileSync(path.join(root, '../brand/logo-mark.svg'), 'utf8'),
  );
});
