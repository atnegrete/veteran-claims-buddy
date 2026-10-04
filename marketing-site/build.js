const fs = require('fs');
const path = require('path');

const root = __dirname;
const legalDir = path.join(root, '..', 'docs', 'legal');
// URLs are environment-aware. Defaults are the production domain, so the
// committed pages and the site test stay on production. A dev build passes
// SITE_URL and APP_URL (see docs/hosting.md and the build:marketing:dev script).
const site = process.env.SITE_URL || 'https://veteranclaimsbuddy.com';
const appBaseUrl = process.env.APP_URL || 'https://app.veteranclaimsbuddy.com';
const appSignIn = `${appBaseUrl}/sign-in`;
const appRegister = `${appBaseUrl}/register`;
const disclaimer =
  'Veteran Claims Buddy is an independent service and is not affiliated with or endorsed by the U.S. Department of Veterans Affairs.';

const nav = [
  ['/how-it-works/', 'How it works'],
  ['/pricing/', 'Pricing'],
  ['/va-disability-calculator/', 'Calculator'],
  ['/faq/', 'FAQ'],
  ['/support/', 'Support'],
  ['/sign-in/', 'Sign in'],
  ['/get-started/', 'Get started'],
];

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function inline(value) {
  return escapeHtml(value).replaceAll(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
}

function markdownBody(markdown) {
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const body = [];
  let list = [];
  function flushList() {
    if (list.length === 0) return;
    body.push('<ul>' + list.map((item) => `<li>${inline(item)}</li>`).join('') + '</ul>');
    list = [];
  }
  for (const line of lines) {
    if (line.startsWith('# ')) continue;
    if (line.startsWith('## ')) {
      flushList();
      body.push(`<h2>${inline(line.slice(3))}</h2>`);
    } else if (line.startsWith('- ')) {
      list.push(line.slice(2));
    } else if (line.trim() === '') {
      flushList();
    } else {
      flushList();
      body.push(`<p>${inline(line)}</p>`);
    }
  }
  flushList();
  return body.join('\n');
}

function legalPage(file, route, description) {
  const markdown = fs.readFileSync(path.join(legalDir, file), 'utf8');
  const title = markdown.match(/^# (.+)$/m)[1];
  return {
    route,
    title,
    description,
    main: markdownBody(markdown),
  };
}

function page({ route, title, description, main, robots }) {
  const canonical = site + (route === '/' ? '/' : route);
  const links = nav
    .map(([href, label]) => {
      const current = href === route ? ' aria-current="page"' : '';
      const className = label === 'Get started' ? ' class="button"' : '';
      return `<a href="${href}"${className}${current}>${label}</a>`;
    })
    .join('\n        ');
  const robotTag = robots ? `<meta name="robots" content="${robots}">` : '';
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <link rel="canonical" href="${canonical}">
  ${robotTag}
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${canonical}">
  <meta property="og:type" content="website">
  <meta name="twitter:card" content="summary">
  <link rel="stylesheet" href="/css/site.css">
  <meta name="theme-color" content="#10151C">
</head>
<body>
  <p class="banner">Draft. A lawyer has not reviewed this site.</p>
  <header>
    <div class="wrap">
      <a class="brand" href="/"><img src="/assets/logo-mark.svg" width="40" height="40" alt="">Veteran Claims Buddy</a>
      <nav aria-label="Site">${links}</nav>
    </div>
  </header>
  <main>
    <div class="wrap">
      <h1>${escapeHtml(title)}</h1>
      ${main}
    </div>
  </main>
  <footer>
    <div class="wrap">
      <nav class="links" aria-label="Legal">
        <a href="/privacy/">Privacy</a>
        <a href="/terms/">Terms</a>
        <a href="/terms/subscription/">Subscription</a>
        <a href="/terms/refunds/">Refunds</a>
        <a href="/terms/print-and-mail/">Print and mail</a>
        <a href="/ai-disclosure/">AI disclosure</a>
        <a href="/account-deletion/">Account deletion</a>
        <a href="/support/">Support</a>
      </nav>
      <p>${disclaimer}</p>
    </div>
  </footer>
</body>
</html>
`;
}

function writePage(spec) {
  const html = page(spec);
  const relative = spec.route === '/' ? 'index.html' : `${spec.route.slice(1)}index.html`;
  const file = path.join(root, relative);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, html);
}

const pages = [
  {
    route: '/',
    title: 'Veteran Claims Buddy',
    description:
      'An AI-powered guided workspace that helps Veterans organize a disability claim and see what to do next.',
    main: `
      <p>Veteran Claims Buddy is an AI-powered guided workspace that helps Veterans understand disability claims, organize evidence, prepare VA forms, and know what to do next.</p>
      <p>${disclaimer}</p>
      <p>You submit the claim yourself on VA.gov or by mail. This service does not file it.</p>
      <div class="actions">
        <a class="button" href="/get-started/">Get started</a>
        <a href="/how-it-works/">How it works</a>
      </div>
      <script type="application/ld+json">${JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'Organization',
        name: 'Veteran Claims Buddy LLC',
        url: site,
        email: 'support@veteranclaimsbuddy.com',
      })}</script>
    `,
  },
  {
    route: '/how-it-works/',
    title: 'How it works',
    description: 'One claim, one step at a time. You review the record and submit it yourself.',
    main: `
      <ol>
        <li>Say whether this is your first VA disability claim.</li>
        <li>Answer the symptom questions. A yes can save a possible condition.</li>
        <li>Add the conditions you want on this claim.</li>
        <li>Upload a PDF, JPEG, or PNG. You confirm, correct, or set aside each statement.</li>
        <li>Add an exam yourself if you have one. The reminder does not name the condition.</li>
        <li>A denied, deferred, or reduced issue can start a draft review. The official form is not filled here.</li>
        <li>Submit on VA.gov or by mail. Nothing in this product is filed for you.</li>
      </ol>
      <p>Vet Buddy can explain what is saved. It can be wrong, and it cannot file the claim or change it.</p>
    `,
  },
  {
    route: '/pricing/',
    title: 'Pricing',
    description: 'A $250 Case unlock, $30 a month Premium, and Print and Mail as a separate payment.',
    main: `
      <section class="card">
        <h2>The workspace</h2>
        <p>Organizing the claim, questions, documents, exams, and the rating calculator stay available without a purchase. Buying is not open in the app yet.</p>
      </section>
      <section class="card">
        <h2>Digital Claim Package</h2>
        <p>A one-time purchase unlocks digital package generation for one Case. The business target price is $250. The store may show the closest allowed price, such as $249.99.</p>
        <p>That purchase stays with that Case. A different Case needs its own purchase, or an active Premium subscription.</p>
      </section>
      <section class="card">
        <h2>Premium</h2>
        <p>Premium is $30 a month. While it is active, it includes digital package generation for eligible Cases, symptom tracking, and monthly symptom summaries.</p>
        <p>When Premium ends, generation stops on Cases that were never purchased. Files already generated stay downloadable. New symptom entries stop until Premium is active again.</p>
      </section>
      <section class="card">
        <h2>Print and Mail</h2>
        <p>Print and Mail is optional and separate. You see one amount before you pay. That amount includes the provider's quote, a $9.95 service fee, and card processing. Those parts are not listed as separate charges. The charge is non-refundable once paid. It does not file the claim.</p>
      </section>
      <p>We do not promise a rating, an approval, or any other VA outcome. Refunds for the Case unlock and Premium follow the store where you paid.</p>
    `,
  },
  {
    route: '/va-disability-calculator/',
    title: 'VA disability calculator',
    description: 'Estimate a combined disability rating and a monthly payment from the current VA rate table.',
    main: `
      <p>This estimates a combined rating and a monthly payment. It does not apply the bilateral factor. It does not change a claim. Actual compensation depends on VA rules and an official decision.</p>
      <p>Rates are the VA table effective December 1, 2025, retrieved October 4, 2026, from <a href="https://www.va.gov/disability/compensation-rates/veteran-rates/">VA compensation rates</a>.</p>
      <form class="card">
        <div class="add-row">
          <label>Rating
            <select id="rating-select">
              <option>10</option><option>20</option><option>30</option><option>40</option><option>50</option>
              <option>60</option><option>70</option><option>80</option><option>90</option><option>100</option>
            </select>
          </label>
          <button class="button" id="add-rating" type="button">Add</button>
        </div>
        <div id="rating-list"></div>
        <p id="combined-value"></p>
        <p id="rounded-rating"></p>
        <label class="check"><input id="spouse" type="checkbox"> Spouse</label>
        <label class="check"><input id="spouse-aid" type="checkbox"> Spouse receives Aid and Attendance</label>
        <label>Dependent parents
          <select id="parents"><option value="0">0</option><option value="1">1</option><option value="2">2</option></select>
        </label>
        <label>Children under 18
          <input id="children-under" inputmode="numeric" min="0" type="number" value="0">
        </label>
        <label>Children over 18 in a qualifying school program
          <input id="children-school" inputmode="numeric" min="0" type="number" value="0">
        </label>
        <p id="monthly"></p>
        <p id="dependent-note" hidden>A 10% or 20% rating does not increase for dependents.</p>
      </form>
      <script src="/js/calculator.js"></script>
      <script src="/js/calculator-page.js"></script>
    `,
  },
  {
    route: '/faq/',
    title: 'FAQ',
    description: 'What Veteran Claims Buddy does, and what it does not file.',
    main: `
      <h2>Do you file the claim with the VA?</h2>
      <p>No. You submit it on VA.gov or by mail.</p>
      <h2>Are you part of the VA?</h2>
      <p>${disclaimer}</p>
      <h2>What does the $250 purchase cover?</h2>
      <p>Digital package generation for one Case. The store may show $249.99. It does not include Print and Mail.</p>
      <h2>What does Premium cover?</h2>
      <p>While the $30 monthly subscription is active, it covers package generation for eligible Cases, symptom tracking, and monthly symptom summaries.</p>
      <h2>Is the calculator an official VA decision?</h2>
      <p>No. It is an estimate from the published rate table. It does not apply the bilateral factor.</p>
    `,
  },
  legalPage(
    'support.md',
    '/support/',
    'Email support@veteranclaimsbuddy.com. Veteran Claims Buddy LLC is not the VA.',
  ),
  legalPage(
    'privacy.md',
    '/privacy/',
    'Draft privacy policy for Veteran Claims Buddy LLC.',
  ),
  legalPage('terms.md', '/terms/', 'Draft terms for Veteran Claims Buddy LLC.'),
  legalPage(
    'subscription.md',
    '/terms/subscription/',
    'Draft terms for the $250 Case unlock and $30 monthly Premium.',
  ),
  legalPage(
    'refunds.md',
    '/terms/refunds/',
    'Draft refund and cancellation terms. Print and Mail is non-refundable once paid.',
  ),
  legalPage(
    'print-and-mail.md',
    '/terms/print-and-mail/',
    'Draft Print and Mail terms. One price, a $9.95 service fee, and card processing.',
  ),
  legalPage(
    'ai-disclosure.md',
    '/ai-disclosure/',
    'Draft disclosure for document reading and Vet Buddy.',
  ),
  legalPage(
    'account-deletion.md',
    '/account-deletion/',
    'Draft explanation of the 30-day account deletion wait.',
  ),
];

for (const spec of pages) writePage(spec);

function redirectPage(route, target, title) {
  const file = path.join(root, route.slice(1), 'index.html');
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(
    file,
    `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title}</title>
  <meta name="robots" content="noindex">
  <link rel="canonical" href="${site}${route}">
  <meta http-equiv="refresh" content="0; url=${target}">
  <link rel="stylesheet" href="/css/site.css">
</head>
<body>
  <main>
    <div class="wrap">
      <h1>${title}</h1>
      <p><a href="${target}">Continue</a></p>
    </div>
  </main>
</body>
</html>
`,
  );
}

redirectPage('/sign-in/', appSignIn, 'Sign in');
redirectPage('/get-started/', appRegister, 'Get started');

const urls = pages.map((spec) => site + (spec.route === '/' ? '/' : spec.route));
fs.writeFileSync(
  path.join(root, 'sitemap.xml'),
  `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((url) => `  <url><loc>${url}</loc></url>`).join('\n')}
</urlset>
`,
);
fs.writeFileSync(
  path.join(root, 'robots.txt'),
  `User-agent: *
Allow: /

Sitemap: ${site}/sitemap.xml
`,
);
