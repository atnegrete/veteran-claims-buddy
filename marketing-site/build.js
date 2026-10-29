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

const legalLinks = [
  ['/privacy/', 'Privacy'],
  ['/terms/', 'Terms'],
  ['/terms/subscription/', 'Subscription'],
  ['/terms/refunds/', 'Refunds'],
  ['/terms/print-and-mail/', 'Print and mail'],
  ['/ai-disclosure/', 'AI disclosure'],
  ['/account-deletion/', 'Account deletion'],
  ['/support/', 'Support'],
];

const steps = [
  'Say whether this is your first VA disability claim.',
  'Answer the symptom questions. A yes can save a possible condition.',
  'Add the conditions you want on this claim.',
  'Upload a PDF, JPEG, or PNG. You confirm, correct, or set aside each statement.',
  'Add an exam yourself if you have one. The reminder does not name the condition.',
  'A denied, deferred, or reduced issue can start a draft review. The official form is not filled here.',
  'Submit on VA.gov or by mail. Nothing in this product is filed for you.',
];

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function inline(value) {
  return escapeHtml(value)
    .replaceAll(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replaceAll(
      'support@veteranclaimsbuddy.com',
      '<a href="mailto:support@veteranclaimsbuddy.com">support@veteranclaimsbuddy.com</a>',
    );
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
    prose: true,
    main: markdownBody(markdown),
  };
}

function linkList(links, route) {
  return links
    .map(([href, label]) => {
      const current = href === route ? ' aria-current="page"' : '';
      return `<a href="${href}"${current}>${label}</a>`;
    })
    .join('\n            ');
}

function headAssets() {
  return `<link rel="preload" href="/assets/fonts/fraunces-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="preload" href="/assets/fonts/source-sans-3-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="stylesheet" href="/css/site.css">
  <meta name="theme-color" content="#10151C">`;
}

function page({ route, title, description, main, robots, heading, bodyClass, prose, card }) {
  const canonical = site + (route === '/' ? '/' : route);
  const textLinks = nav.filter(([, label]) => label !== 'Get started');
  const robotTag = robots ? `\n  <meta name="robots" content="${robots}">` : '';
  const bodyName = bodyClass ? ` class="${bodyClass}"` : '';
  const headingHtml =
    heading === false ? '' : `<h1 class="display">${escapeHtml(heading || title)}</h1>`;
  const articleClass = [prose ? 'prose' : '', card ? 'card contact-card' : '']
    .filter(Boolean)
    .join(' ');
  const body = prose ? `<article class="${articleClass}">\n${main}\n</article>` : main;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <link rel="canonical" href="${canonical}">${robotTag}
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${canonical}">
  <meta property="og:type" content="website">
  <meta property="og:image" content="${site}/assets/og.jpg">
  <meta property="og:image:width" content="1280">
  <meta property="og:image:height" content="720">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:image" content="${site}/assets/og.jpg">
  ${headAssets()}
</head>
<body${bodyName}>
  <a class="skip" href="#content">Skip to content</a>
  <p class="banner">Draft. A lawyer has not reviewed this site.</p>
  <header class="site-header">
    <div class="wrap header-bar">
      <a class="brand" href="/"><img src="/assets/logo-mark.svg" width="40" height="40" alt=""><span>Veteran Claims Buddy</span></a>
      <div class="header-actions">
        <nav class="desktop-nav" aria-label="Site">
            ${linkList(textLinks, route)}
        </nav>
        <a class="btn header-cta" href="/get-started/">Get started</a>
        <details class="mobile-nav">
          <summary>Menu</summary>
          <nav aria-label="Site">
            ${linkList(textLinks, route)}
          </nav>
        </details>
      </div>
    </div>
  </header>
  <main id="content">
    <div class="wrap page-wrap">
      ${headingHtml}
      ${body}
    </div>
  </main>
  <footer class="site-footer">
    <div class="wrap footer-grid">
      <div>
        <a class="brand" href="/"><img src="/assets/logo-mark.svg" width="40" height="40" alt=""><span>Veteran Claims Buddy</span></a>
        <p class="disclaimer">${disclaimer}</p>
      </div>
      <nav aria-label="Product">
        <p class="footer-label">Product</p>
        ${linkList(nav.filter(([, label]) => label !== 'Sign in' && label !== 'Get started'), route)}
      </nav>
      <nav aria-label="Legal">
        <p class="footer-label">Legal</p>
        ${linkList(legalLinks, route)}
      </nav>
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

const support = legalPage(
  'support.md',
  '/support/',
  'Email support@veteranclaimsbuddy.com. Veteran Claims Buddy LLC is not the VA.',
);
support.card = true;

const pages = [
  {
    route: '/',
    title: 'Veteran Claims Buddy',
    description:
      'An AI-powered guided workspace that helps Veterans organize a disability claim and see what to do next.',
    heading: false,
    bodyClass: 'home',
    main: `
      <section class="hero">
        <div class="hero-copy">
          <p class="eyebrow">Independent claim workspace</p>
          <h1 class="display">Organize the claim. See the next step.</h1>
          <p class="lede">Veteran Claims Buddy is an AI-powered guided workspace that helps Veterans understand disability claims, organize evidence, prepare VA forms, and know what to do next.</p>
          <p class="disclaimer">${disclaimer}</p>
          <p>You submit the claim yourself on VA.gov or by mail. This service does not file it.</p>
          <div class="actions">
            <a class="btn" href="/get-started/">Get started</a>
            <a class="btn-quiet" href="/how-it-works/">How it works</a>
          </div>
        </div>
        <img class="hero-art" src="/assets/hero.jpg" width="1152" height="864" alt="A lamp lighting a stack of papers and a checklist on a desk.">
      </section>
      <section class="feature-grid" aria-label="What the workspace does">
        <article class="card">
          <p class="eyebrow">01</p>
          <h2>One step at a time</h2>
          <p>The claim opens on the current step, then the next. You are not handed every form at once.</p>
        </article>
        <article class="card">
          <p class="eyebrow">02</p>
          <h2>You confirm the record</h2>
          <p>Upload a PDF, JPEG, or PNG. Each statement stays unreviewed until you confirm, correct, or set it aside.</p>
        </article>
        <article class="card">
          <p class="eyebrow">03</p>
          <h2>You submit it yourself</h2>
          <p>You send the claim on VA.gov or by mail. This service does not file it.</p>
        </article>
      </section>
      <section class="card price-strip">
        <div>
          <p class="eyebrow">Pricing</p>
          <h2>The workspace stays open</h2>
          <p>A $250 Case unlock and Premium from $29.99 a month are separate from organizing the claim. Buying is not open in the app yet.</p>
        </div>
        <a class="btn-quiet" href="/pricing/">See pricing</a>
      </section>
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
      <p class="lede">One claim, one step at a time. You review the record and submit it yourself.</p>
      <ol class="timeline">
        ${steps
          .map(
            (step, index) =>
              `<li><span class="step-num">${index + 1}</span><p>${step}</p></li>`,
          )
          .join('\n        ')}
      </ol>
      <p class="note">Vet Buddy can explain what is saved. It can be wrong, and it cannot file the claim or change it.</p>
    `,
  },
  {
    route: '/pricing/',
    title: 'Pricing',
    description: 'A $250 Case unlock, $29.99 a month or $234.99 a year Premium, and Print and Mail as a separate payment.',
    main: `
      <section class="card">
        <h2>The workspace</h2>
        <p>Organizing the claim, questions, documents, exams, and the rating calculator stay available without a purchase. Buying is not open in the app yet.</p>
      </section>
      <div class="price-grid">
        <section class="card price-focus">
          <p class="eyebrow">One Case</p>
          <h2>Digital Claim Package</h2>
          <p class="price" aria-hidden="true">$250</p>
          <p>A one-time purchase gives one Case a full year of Premium, limited to that single active case. The business target price is $250. The store may show the closest allowed price, such as $249.99.</p>
          <p>You keep one active case at a time. Complete it to unlock another, or switch to Premium for every case. Completed cases stay viewable and downloadable.</p>
        </section>
        <section class="card price-focus">
          <p class="eyebrow">Monthly or yearly</p>
          <h2>Premium</h2>
          <p class="price" aria-hidden="true">$29.99</p>
          <p>Premium is $29.99 a month, or $234.99 a year (save 34%). While it is active, it includes digital package generation for every Case, symptom tracking, and monthly symptom summaries.</p>
          <p>When Premium ends, generation stops on Cases that were never purchased. Files already generated stay downloadable. New symptom entries stop until Premium is active again.</p>
        </section>
      </div>
      <section class="card">
        <h2>Print and Mail</h2>
        <p>Print and Mail is optional and separate. You see one amount before you pay. That amount includes the provider's quote, a $9.95 service fee, and card processing. Those parts are not listed as separate charges. The charge is non-refundable once paid. It does not file the claim.</p>
      </section>
      <p class="note">We do not promise a rating, an approval, or any other VA outcome. Refunds for the Case unlock and Premium follow the store where you paid.</p>
    `,
  },
  {
    route: '/va-disability-calculator/',
    title: 'VA disability calculator',
    description: 'Estimate a combined disability rating and a monthly payment from the current VA rate table.',
    main: `
      <p class="lede">This estimates a combined rating and a monthly payment. It does not apply the bilateral factor. It does not change a claim. Actual compensation depends on VA rules and an official decision.</p>
      <p>Rates are the VA table effective December 1, 2025, retrieved October 4, 2026, from <a href="https://www.va.gov/disability/compensation-rates/veteran-rates/">VA compensation rates</a>.</p>
      <div class="calc-grid">
        <form class="card calc-form">
          <div class="add-row">
            <label>Rating
              <select id="rating-select">
                <option>10</option><option>20</option><option>30</option><option>40</option><option>50</option>
                <option>60</option><option>70</option><option>80</option><option>90</option><option>100</option>
              </select>
            </label>
            <button class="btn" id="add-rating" type="button">Add</button>
          </div>
          <div id="rating-list"></div>
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
        </form>
        <aside class="card result-panel" aria-live="polite">
          <p class="eyebrow">Estimate</p>
          <h2>Combined rating</h2>
          <p id="combined-value" class="result-line"></p>
          <p id="rounded-rating" class="result-line"></p>
          <p id="monthly" class="price"></p>
          <p id="dependent-note" hidden>A 10% or 20% rating does not increase for dependents.</p>
          <p class="hint">Add a rating to see a combined result. This does not change a claim.</p>
        </aside>
      </div>
      <script src="/js/calculator.js"></script>
      <script src="/js/calculator-page.js"></script>
    `,
  },
  {
    route: '/faq/',
    title: 'FAQ',
    description: 'What Veteran Claims Buddy does, and what it does not file.',
    main: `
      <p class="lede">What Veteran Claims Buddy does, and what it does not file.</p>
      <div class="faq">
        <details class="faq-item">
          <summary>Do you file the claim with the VA?</summary>
          <p>No. You submit it on VA.gov or by mail.</p>
        </details>
        <details class="faq-item">
          <summary>Can a spouse or survivor use this?</summary>
          <p>No. The account and the forms are for the Veteran whose disability claim this is. Someone filing for a Veteran is not supported.</p>
        </details>
        <details class="faq-item">
          <summary>Are you part of the VA?</summary>
          <p>${disclaimer}</p>
        </details>
        <details class="faq-item">
          <summary>What does the $250 purchase cover?</summary>
          <p>A full year of Premium for one active Case. The store may show $249.99. It does not include Print and Mail.</p>
        </details>
        <details class="faq-item">
          <summary>What does Premium cover?</summary>
          <p>While Premium is active ($29.99 a month or $234.99 a year), it covers package generation for every Case, symptom tracking, and monthly symptom summaries.</p>
        </details>
        <details class="faq-item">
          <summary>Is the calculator an official VA decision?</summary>
          <p>No. It is an estimate from the published rate table. It does not apply the bilateral factor.</p>
        </details>
      </div>
    `,
  },
  support,
  legalPage(
    'privacy.md',
    '/privacy/',
    'Draft privacy policy for Veteran Claims Buddy LLC.',
  ),
  legalPage('terms.md', '/terms/', 'Draft terms for Veteran Claims Buddy LLC.'),
  legalPage(
    'subscription.md',
    '/terms/subscription/',
    'Draft terms for the $250 Case unlock and Premium from $29.99 a month.',
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
  ${headAssets()}
</head>
<body class="redirect">
  <main class="redirect-main" id="content">
    <img src="/assets/logo-mark.svg" width="64" height="64" alt="">
    <h1 class="display">${title}</h1>
    <p><a class="btn" href="${target}">Continue</a></p>
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
