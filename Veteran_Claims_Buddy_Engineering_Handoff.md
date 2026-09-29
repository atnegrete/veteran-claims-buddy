# Veteran Claims Buddy — Engineering Handoff & Build Specification

**Document status:** Build-ready engineering handoff  
**Product:** Veteran Claims Buddy  
**Assistant:** Vet Buddy  
**Intended domain:** veteranclaimsbuddy.com  
**Last verified:** 2026-09-29  
**Primary client:** Flutter (iOS, Android, Web)  
**Primary backend:** Firebase + Google Cloud managed services  
**Primary structured database:** Cloud Firestore  
**File storage:** Cloud Storage for Firebase  
**Server-side logic:** Cloud Functions for Firebase (2nd gen, JavaScript)  
**AI orchestration:** Server-side, provider-abstracted. The first implementation calls Vertex AI Gemini from JavaScript. Genkit is optional later and is not required for domain logic.  
**Environment model:** `dev` and `prod` Firebase projects. Local development connects directly to `dev`. Do **not** introduce the Firebase Emulator Suite unless explicitly requested later.

---

# 0. Purpose of this document

This document is intended to be handed directly to one or more engineering/coding agents and used as the authoritative implementation plan for **Veteran Claims Buddy**, a cross-platform application that helps U.S. Veterans manage the VA disability-claims process from discovery through submission, C&P exams, decisions, and decision reviews.

The application is a **self-service Veteran claims assistant**. The Veteran remains the claimant. The application helps the Veteran understand the process, organize evidence, prepare information, complete guided workflows, monitor progress, and—when a supported VA API exists—submit information only after explicit user review and approval.

This is not a generic chatbot and not merely a form-filling application. The product should function as a **Veteran Claims Operating System** with a persistent, structured understanding of:

- the Veteran;
- military service history;
- deployments and potential exposures;
- symptoms and diagnoses;
- existing service-connected conditions;
- potential new conditions;
- claim issues;
- service-connection theories;
- evidence;
- C&P exams;
- submissions;
- VA decisions;
- deadlines;
- decision-review history;
- tasks;
- documents;
- extracted document facts;
- and all next actions.

The AI assistant is a conversational interface over this structured case state. It must **not** be the source of truth for case state.

---

# 1. Agent operating rules

Every engineering agent working from this document must follow these rules.

## 1.1 Do not redesign the selected backend stack

The selected stack is intentionally simple:

- Flutter;
- Firebase Authentication;
- Cloud Firestore;
- Cloud Storage for Firebase;
- Cloud Functions for Firebase;
- Firebase App Check;
- Firebase Cloud Messaging;
- Google Cloud Secret Manager through Firebase Functions secrets;
- Cloud Tasks only when a job is too long/expensive for the synchronous request path;
- Cloud Run/Cloud Run Jobs only when a workload demonstrably outgrows Cloud Functions/Cloud Tasks.

Do **not** introduce PostgreSQL, Firebase Data Connect, Supabase, a traditional ASP.NET Core API, Kubernetes, Redis, Elasticsearch, or another database without a documented measured requirement and owner approval.

## 1.2 Firestore is the canonical structured-data store

Files do not belong in Firestore. Firestore stores metadata and references to Storage objects.

Example:

```text
Firestore
users/{uid}/documents/{documentId}
    name
    contentType
    storagePath
    pageCount
    processingStatus

Storage
users/{uid}/documents/{documentId}/original.pdf
```

## 1.3 The application is document-oriented, but documents must stay small

Do not put the Veteran's entire case in one Firestore document.

Break data into logical documents and subcollections based on:

- independent lifecycle;
- independent update frequency;
- query requirements;
- access-control requirements;
- expected growth.

Do not create a Firestore document for every microscopic field merely because Firestore supports documents. Group related values when they are always loaded/updated together.

## 1.4 Do not normalize Firestore like SQL

Intentional denormalization is allowed and encouraged where it simplifies common reads.

Example task document:

```json
{
  "claimIssueId": "issue_123",
  "claimIssueDisplayName": "Lumbar spine condition",
  "priority": "high",
  "status": "open",
  "dueAt": "..."
}
```

`claimIssueDisplayName` is intentionally duplicated to avoid an extra lookup on the dashboard.

## 1.5 Query-first Firestore design

Before adding a collection, write down the reads/screens it must support.

Firestore Security Rules are not filters. Queries must be structured such that all returned documents satisfy the rules.

## 1.6 The LLM never owns deterministic facts

The LLM must not independently determine:

- legal deadlines;
- whether a submission succeeded;
- whether a form is current;
- whether an Intent to File is active;
- whether a C&P appointment exists;
- claim state;
- user identity;
- evidence upload status;
- API-response state.

Those come from deterministic application state/rules/API results.

The AI may **explain** those facts.

## 1.7 Provenance is mandatory

Every important fact derived from evidence must distinguish among:

- `veteranReported`;
- `documentExtracted`;
- `vaApiImported`;
- `systemCalculated`;
- `agentInference`;
- `medicalOpinion`;
- `legalAuthority`.

An AI inference is never silently converted into a Veteran-reported or documented fact.

## 1.8 Consequential actions require explicit confirmation

Never silently:

- submit a claim;
- establish an Intent to File;
- upload evidence to VA;
- request a review;
- withdraw an issue;
- alter a VA submission;
- transmit sensitive information to an external party.

The application must present a review step and require explicit confirmation immediately before the consequential action.

## 1.9 Local development uses the development Firebase project

There is no required local emulator environment.

- `flutter run --flavor dev` -> development Firebase project.
- `flutter run --flavor prod` -> production Firebase project.

Development reset/seed scripts are part of the repository.

Any reset script must refuse to run when the active project is production.

## 1.10 Owner-action gates are hard stops for engineering agents

This document contains steps labeled `OWNER ACTION GATE`. Those are not informational notes. They are explicit workflow boundaries.

When an agent reaches an owner-action gate:

1. stop implementation at that dependency;
2. tell the owner exactly what must be done manually;
3. provide the exact console path/command/value that the owner needs;
4. do not pretend the step was completed;
5. do not create substitute credentials, accounts, signing keys, billing configuration, test phone numbers, production approvals, or external-service settings on the owner's behalf unless a supported tool explicitly permits it and the owner asked for it;
6. wait for the owner to confirm completion or provide the required non-secret identifier/value;
7. verify the resulting configuration where possible before continuing.

An agent must not skip an owner-action gate just because later code can be scaffolded without it. It may prepare non-dependent code, but it must clearly mark the blocked work and may not claim the phase is complete.

The owner should never paste passwords, private keys, SMS verification codes for real users, Apple private keys, service-account JSON, VA API secrets, or other secrets into source control or this document. Use Firebase/Google Secret Manager or platform-native secret stores where applicable.

### CLI bootstrap stays with the owner

When a step creates or connects a project with an official CLI, the owner runs the command. The agent stops, prints the exact command, the directory, and what success looks like, then waits for confirmation. The agent does not hand-write the project those commands generate.

This includes:

- `flutter create`
- `flutterfire configure`
- `firebase init`
- `firebase login`
- global CLI installs such as `firebase-tools`

### Packages

Install the latest stable release of the current major version. Do not copy a pinned version out of this document. `flutter pub add <package>` and `npm install <package>` with no version argument do that.

Once `/app` exists, the agent may add a plain Dart package directly to `pubspec.yaml` when it needs no account, API key, store setup, or generator that rewrites native projects.

These stay owner gates. The agent may name the package and the command. The owner runs it:

- `flutter_launcher_icons` and `flutter_native_splash` generator commands, after the dev and prod icon assets exist
- `purchases_flutter`, after RevenueCat and the store products exist
- `flutter_stripe`, after Stripe keys exist
- Crashlytics native wiring and Firebase console enablement, if FlutterFire did not already complete it

`pdf-lib`, `sharp`, `stripe`, and `@google-cloud/vertexai` are added to Functions with `npm install` when that feature starts. The agent may add those JavaScript dependencies. Stripe secret keys stay in Secret Manager and are never written by the agent.

## 1.11 Current VA rules/forms are configuration, not application constants

Form revisions, APIs, presumptive conditions, DBQs, rules, and guidance can change. Store version metadata and version every supported artifact. Never scatter form revision dates or VA rule text throughout Flutter widgets.

**VA form activation is explicitly manual and release-controlled.** The application must never automatically make a newly discovered VA form revision available to end users. A newly published VA PDF may be discovered/imported into a staging state, but it is not supported until the owner deliberately qualifies it, approves it, and includes it in an immutable form catalog tied to a specific application release.

The controlling relationship is:

```text
App binary version/build
        -> App release manifest
        -> Approved form catalog version
        -> Exact VA form revision
        -> Exact form-mapping version
```

An older installed app must remain pinned to the catalog approved for that app release. It must not silently start using a later VA form revision because reference data changed in Firebase.

A server-side safety policy may still block finalization/submission of an older form revision if that revision is no longer safe or accepted. In that situation, the application must require an update rather than silently switching the Veteran to another form revision.

---

# 2. Product principles

The product should behave as if the Veteran has an intelligent case manager available at all times, while keeping the Veteran in control.

The central question of the application is:

> **What should I do next?**

Everything should lead toward answering that question accurately.

The Veteran should never have to know which obscure VA form is required before beginning a workflow. The product asks natural-language questions, determines which workflow is applicable, explains it, and then guides the Veteran through it.

There should be no intentional dead ends.

If the Veteran receives a VA letter they do not understand, the application should accept an upload.

If they remember a condition, they should be able to tell the assistant.

If a C&P exam is scheduled, the app should switch into preparation mode.

If a decision arrives, the app should parse it issue-by-issue and update the case graph.

For MVP, the normal completed-Case outcome is a generated Veteran-reviewed package plus guided self-submission instructions. The product should provide the best supported self-submission path:

1. generated form/package;
2. VA.gov handoff/deep link with clear upload instructions;
3. guided mail/manual instructions when applicable;
4. optional Print & Mail fulfillment to the Veteran.

Direct VA API submission is a future enhancement and must not be treated as an MVP dependency.

---

# 2A. Settled Owner Product Requirements — authoritative

This section records explicit owner decisions made after the initial architecture was drafted. It is **authoritative**. If another section of this document conflicts with this section, this section wins and the conflicting implementation must be updated rather than interpreted loosely.

Unless the owner explicitly changes a requirement later, agents must implement the following decisions as written.

## 2A.1 Product identity, domain, assistant name, and brand

The product name is:

```text
Veteran Claims Buddy
```

The intended production domain is:

```text
veteranclaimsbuddy.com
```

The conversational assistant inside the product is named:

```text
Vet Buddy
```

Do not use `VA` as if it were part of the official product identity. Veteran Claims Buddy is an independent product and must not imply affiliation with, endorsement by, or operation by the U.S. Department of Veterans Affairs.

Legal identity for drafts and store setup:

```text
Legal name:     Veteran Claims Buddy LLC
Formed in:      Iowa
Governing law:  Iowa, for the draft terms. Counsel still reviews dispute terms before launch.
Support:        support@veteranclaimsbuddy.com
Mailing address: not published yet. Email is the public contact. Provide a street address to Apple or Google if a store review requires it.
Age:            The service is offered to people 18 and older and is not directed to children under 13.
Content:        No violence, gambling, or contests. Store questionnaires must be answered honestly. Medical and disability-claim subject matter can still affect the store age rating.
```

Draft privacy, terms, subscription, refund, Print & Mail, AI, account-deletion, and support copy lives in `docs/legal/`. Those pages are scaffolds for the marketing routes. They are not a lawyer's final text. Do not remove the draft banner before counsel review.

Brand direction:

- modern;
- trustworthy;
- dark-theme-first;
- Veteran/military-aware without looking like government software;
- visually closer to modern financial/health software than to a dense government portal;
- avoid excessive flags, camouflage, rank insignia, tactical styling, or other visual clichés;
- use restrained Veteran/military cues in iconography, copy, and visual motifs;
- high contrast and accessibility are mandatory;
- theme values must be centralized so a future light theme is a theme/configuration change rather than a screen-by-screen rewrite.

### AGENT TASK — initial brand package

Before polishing the public marketing site and production application shell, create an initial brand package in the repo containing:

```text
/brand
    README.md
    logo.svg
    logo-mark.svg
    wordmark.svg
    app-icon-source.svg or equivalent source asset
    brand-tokens.md
```

The brand guide must define at minimum:

- logo usage;
- icon mark;
- wordmark;
- dark background treatment;
- primary/secondary/accent semantic theme tokens;
- typography choices using redistribution-safe/system/web-safe assets;
- spacing/radius conventions;
- positive/warning/error/information semantic tokens;
- examples of incorrect official-looking VA branding to avoid.

Do not block early engineering on a perfect logo. Create a professional initial vector identity, keep source assets version-controlled, and allow later replacement without changing product architecture.

## 2A.2 Public marketing site and authenticated application are separate surfaces

Use Firebase Hosting for the public website and Flutter Web for the authenticated application.

Recommended production URLs:

```text
https://veteranclaimsbuddy.com
    public static marketing/SEO site

https://app.veteranclaimsbuddy.com
    authenticated Flutter Web application
```

The public site should be ordinary static HTML/CSS/JavaScript committed in the same repository rather than being rendered by Flutter.

Recommended repo layout:

```text
/app                       # Flutter iOS/Android/Web app
/marketing-site            # static public HTML/CSS/JS
/functions                 # Firebase Functions
/scripts                   # admin/dev/form tooling
/brand                     # shared brand source assets/tokens
```

Use Firebase Hosting targets/sites so marketing and Flutter Web can deploy independently.

The static public site must be designed for SEO and crawlability. Implement at minimum:

- semantic HTML;
- unique page titles;
- meta descriptions;
- canonical URLs;
- Open Graph/Twitter metadata;
- sitemap.xml;
- robots.txt;
- schema.org structured data where appropriate;
- accessible headings/navigation;
- clean human-readable URLs;
- fast-loading static assets;
- no dependence on an authenticated Flutter shell for marketing content.

Initial public routes/pages:

```text
/
/how-it-works
/pricing
/va-disability-calculator
/faq
/privacy
/terms
/support
/sign-in              # redirects/links into app.veteranclaimsbuddy.com
/get-started          # redirects/links into app registration
```

The full page tree, including the app shell, Home, `/plans`, and admin, is `docs/page-navigation.md`. That file wins if this route list is narrower or older.

Marketing copy should prominently communicate the outcome and may explicitly use `AI-powered`, for example:

> Veteran Claims Buddy is an AI-powered guided workspace that helps Veterans understand disability claims, organize evidence, prepare VA forms, and know what to do next.

Also display an appropriate independent-product disclaimer in public/legal/account-creation surfaces, for example:

> Veteran Claims Buddy is an independent service and is not affiliated with or endorsed by the U.S. Department of Veterans Affairs.

Do not repeat that disclaimer on every app screen unless required by later legal review.

Official Firebase Hosting reference:

https://firebase.google.com/docs/hosting

### Implementation-order requirement — Hosting

After the `dev` and `prod` Firebase projects exist and the Firebase CLI is configured, initialize Hosting targets in each project:

```text
marketing    static site
app          Flutter web build
```

Dev Hosting uses the Firebase default domains for that project. Connect `veteranclaimsbuddy.com` and `app.veteranclaimsbuddy.com` only on the prod project's Hosting sites, and only when the owner is ready to expose them.

Deploy the web app after `flutter build web --flavor <dev|prod>`:

```bash
firebase deploy --only hosting:app --project dev
firebase deploy --only hosting:app --project prod
```

Use `hosting:marketing` the same way for the static site. This does not need to block claim-domain development if the production domain has not yet been purchased.

### OWNER ACTION GATE — domain purchase and custom-domain connection

When the owner has purchased `veteranclaimsbuddy.com`, stop and provide exact current Firebase Console instructions to connect:

```text
veteranclaimsbuddy.com
www.veteranclaimsbuddy.com     # redirect to canonical root unless owner chooses otherwise
app.veteranclaimsbuddy.com
```

The agent must not invent DNS records. Read the exact Firebase Hosting custom-domain verification records shown by Firebase at that time and tell the owner what to add at the registrar/DNS provider.

Do this first in production only when the owner is ready to expose the site publicly. Development may use Firebase Hosting preview/default domains.

## 2A.3 Platform and scope decisions

Launch targets:

- iOS;
- Android;
- Web;
- all three are first-class launch platforms;
- layouts must be responsive and reusable rather than separate screen implementations where avoidable.

Version 1 language:

```text
English only
```

Do not build localization infrastructure beyond normal clean separation of user-facing strings if it adds meaningful overhead. Avoid hard-wiring copy into business/domain models so localization can still be introduced later.

Account model:

- account is for the Veteran only;
- no spouse/caregiver/delegate access in MVP;
- no household/shared-account permission model;
- never recommend password sharing.

Benefit scope:

- remain focused on **VA disability compensation**;
- architecture may expand later to dependency/other VA benefits;
- do not dilute MVP with unrelated VA benefit programs.

Within disability compensation, support the full range of claim/review workflows needed by Veterans, including the relevant initial, increased, secondary, presumptive, Supplemental Claim, Higher-Level Review, Board-related guidance, TDIU-related disability compensation workflows, and other disability-compensation form paths as they are qualified.

For each supported workflow, agents must research current VA requirements and official sources before implementing the questionnaire, form, rule, or guidance. Do not assume every disability workflow is merely a different PDF with identical rules.

## 2A.4 MVP submission boundary — Veteran self-submission only

MVP ends with generation of a complete Veteran-reviewed submission package and simple self-submission instructions.

Do **not** make direct electronic submission to VA a launch blocker.

MVP supported final paths:

```text
Generate digital package
    -> show exactly what was generated
    -> Veteran reviews
    -> Veteran downloads
    -> app provides simple VA.gov/mail submission guidance

Optional Print & Mail
    -> physical package mailed to Veteran
    -> Veteran reviews/signs where required
    -> Veteran submits to VA
```

The app must make self-submission instructions extremely simple and contextual. Provide:

- the exact VA.gov destination when a supported online submission route exists;
- what documents to upload;
- whether signatures are required;
- what confirmation/receipt to save;
- mailing instructions only from current authoritative VA sources when mail submission is applicable;
- a checklist the Veteran can mark complete;
- access to Vet Buddy for explanation.

Direct VA APIs may be integrated later, but the domain model should preserve that future possibility.

## 2A.5 Free product policy

Free users can use the core Veteran Claims Buddy workflow extensively.

Do not artificially cripple the core case-preparation experience simply to create a paywall.

Free users may use, subject only to abuse/security controls:

- account/profile;
- onboarding;
- service history;
- condition discovery;
- guided questionnaires;
- potential-condition review;
- Claim Issues;
- Case organization;
- evidence upload;
- document classification/reclassification;
- document/evidence processing;
- decision-letter analysis;
- evidence-gap views;
- C&P exam tracking/preparation;
- basic/standard Vet Buddy assistance;
- VA disability rating/compensation calculator;
- other free utilities explicitly marked free.

The primary paywall is **official digital claim-package generation/download** for a Case, unless the user has active Premium access.

Symptom/health tracking described below is Premium-only.

There is no Free-vs-Premium file count/page/storage quota for MVP. There **are** global technical abuse ceilings that apply to everyone.

## 2A.6 Case is the commercial and workflow boundary

Introduce an explicit `Case` domain object. Do not use `submission` and `Case` interchangeably.

A Case represents one coherent Veteran claims effort and may contain multiple VA submissions and decision-review steps over time.

Examples within one Case:

```text
Case: Back / radiculopathy / knee claim

Initial 21-526EZ submission
    -> VA decision
    -> back granted
    -> knee denied
    -> radiculopathy deferred
    -> Supplemental Claim for knee
    -> later decision
    -> HLR for related decision if Veteran chooses
    -> final resolution
    -> Veteran marks Case complete
```

Appeals/reviews that continue issues originating from the Case remain **inside the same Case**.

A completely new claims effort later is a **new Case**.

### One current Working Case, not one technically-open Case

The user experience should emphasize only one `currentWorkingCaseId` at a time.

However, do **not** enforce a database rule that only one non-completed Case can exist. A Veteran may have an older Case waiting on VA/Board review while legitimately beginning a new Case.

Examples of background Case states:

```text
awaitingVA
reviewPending
boardPending
```

Only one Case should normally be the foreground `working` Case that receives the primary preparation UI.

Home may still surface critical deadlines/actions from background pending Cases.

### Case lifecycle

Recommended Case status model:

```text
draft
working
readyForPackage
packageGenerated
submittedByVeteran
awaitingVA
decisionReceived
reviewPreparing
reviewSubmitted
reviewPending
readyToComplete
completed
archived
```

A Case is not automatically completed just because one VA decision was uploaded. The Veteran decides whether to:

- accept the results and complete the Case;
- continue a denied/partially granted issue through a decision-review path;
- wait on a deferred issue;
- otherwise continue work related to that Case.

### Firestore model

Add:

```text
users/{uid}/cases/{caseId}
```

Recommended shape:

```json
{
  "displayName": "Back, Left Leg, and Knee Claim",
  "status": "working",
  "isCurrentWorkingCase": true,
  "initialClaimType": "disabilityClaim",
  "claimIssueIds": ["..."],
  "latestSubmissionId": "...|null",
  "latestDecisionId": "...|null",
  "openedAt": "Timestamp",
  "firstSubmittedAt": "Timestamp|null",
  "completedAt": "Timestamp|null",
  "completedByVeteran": false,
  "digitalAccessType": "none|oneTimeCasePurchase|premiumActive|historicalPremiumArtifact",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "schemaVersion": 1
}
```

Also add to the root user/profile projection:

```text
currentWorkingCaseId
```

Do not trust an `isCurrentWorkingCase` flag alone. A server-controlled function/transaction should update the user's `currentWorkingCaseId` and Case projections consistently.

## 2A.7 One-time $250 product is tied to a Case

The one-time digital purchase is:

```text
Digital Claim Package — $250 business target
```

It unlocks **digital package generation for one Case**, not one PDF and not merely one initial submission.

If that Case later needs related Supplemental Claim/HLR/other review forms because of the VA result, the one-time Case purchase remains valid for that Case.

The Veteran may:

- modify confirmed information;
- add/remove supporting evidence before submission;
- correct fields;
- regenerate package artifacts;
- redownload regenerated artifacts;
- continue related review package generation within that purchased Case;

without paying another $250 for that Case.

A new Case later requires a new $250 purchase unless the user has active Premium when generating the new Case's package.

Do not charge per PDF or per individual claimed condition.

## 2A.8 Premium — $30/month, monthly only at launch

Premium launch price target:

```text
$30/month
```

No annual subscription at MVP launch.

Premium provides digital Case-package generation while the subscription is active and unlocks Premium recurring features including symptom/health tracking.

Premium users may generate packages for any eligible Case while Premium is active.

The one-current-Working-Case UX applies to Premium and non-Premium users equally.

When Premium expires:

- previously generated/downloadable artifacts remain accessible;
- symptom history remains readable;
- the user does not lose their data;
- creating new Premium symptom entries is disabled until Premium resumes;
- generating a **new or materially regenerated digital package** requires either active Premium or a one-time $250 purchase for that Case;
- do not delete or hide historical generated packages because a subscription ended.

Do not promise truly unlimited compute/AI in public copy. Apply reasonable anti-abuse controls across all plans.

## 2A.9 Premium symptom and health tracking

Symptom/health tracking is Premium-only at MVP launch.

The purpose is to help the Veteran maintain an accurate longitudinal record that can later support:

- personal statement preparation;
- form answers;
- C&P preparation;
- condition history review;
- monthly summaries;
- recollection of frequency, severity, duration, functional impact, and treatment.

### Daily check-in UX

The standard daily check-in should normally take **one to two minutes or less**.

Prefer quick structured controls over required typing:

- severity sliders/scales;
- yes/no;
- single/multi-select chips;
- duration presets;
- frequency/count controls;
- quick functional-impact toggles;
- medication/treatment toggles;
- missed-work/activity-impact controls.

Free-text notes are always optional unless the Veteran explicitly chooses to add detail.

Questions should be tailored to the Veteran's tracked conditions. Do not show a giant universal health form every day.

### Event-based entries

Premium users may create manual symptom events at any time, independent of the daily check-in.

Examples:

```text
migraine episode
back flare-up
panic episode
GI flare
sleep disruption
knee instability event
```

Event entry supports:

- condition;
- date/time;
- severity;
- duration;
- symptoms;
- functional impact;
- work impact;
- activity limitations;
- treatment/medication used;
- optional free text;
- optional photos/images where appropriate.

Photos are optional and follow normal Storage security/upload limits.

### Monthly AI summaries

Vet Buddy may generate a monthly summary from confirmed symptom entries.

The summary must distinguish raw tracked facts from AI prose and should include measurable observations where available, for example:

```text
number of tracked migraine days
number of severe episodes
average reported severity
average/typical duration
number of entries affecting work
number requiring lying down/rest
common functional impacts
```

The Veteran can review/correct the summary before it is used as supporting context elsewhere.

Monthly summaries may feed:

- Case questionnaires;
- personal statement drafting;
- C&P preparation;
- longitudinal condition summaries.

Do not treat symptom tracking as a medical diagnosis tool.

No Apple Health / Google Health Connect integration in MVP.

## 2A.10 Free VA Disability Rating and Compensation Calculator

Build a standalone **free** VA Disability Rating & Compensation Calculator.

It does not need to write to the Veteran's Case/profile in MVP. A signed-in or public user should be able to experiment without modifying their actual case state.

Capabilities:

- add/remove individual disability percentages;
- calculate VA combined rating using the VA combined-ratings method rather than simple arithmetic addition;
- support bilateral-factor calculation for qualifying paired extremities/muscles;
- show the unrounded combined value where useful;
- show the final rounded combined rating;
- allow dependent configuration for estimating monthly compensation;
- support spouse;
- dependent parents;
- children under 18;
- children over 18 in a qualifying school program;
- spouse Aid & Attendance add-on where applicable;
- clearly note that 10% and 20% ratings do not receive dependent-based increases under the current VA rate structure;
- show estimated monthly compensation based on the selected effective rate table.

Authoritative logic/source references:

- VA combined-ratings explanation/table: https://www.va.gov/disability/about-disability-ratings/
- 38 CFR 4.25 combined ratings table: https://www.law.cornell.edu/cfr/text/38/4.25
- 38 CFR 4.26 bilateral factor: https://www.law.cornell.edu/cfr/text/38/4.26
- current VA compensation rate tables: https://www.va.gov/disability/compensation-rates/veteran-rates/

As of this specification update, VA's published 2026 compensation rates are effective December 1, 2025. Do **not** hard-code those dollar values permanently in Flutter. Store rate tables as versioned global reference data with effective dates and update them when VA publishes new rates.

Recommended global collections:

```text
vaCompensationRateTables/{rateTableId}
vaCompensationRateTables/{rateTableId}/rows/{rowId}
```

Each table records:

```text
effectiveFrom
effectiveTo
sourceUrl
retrievedAt
contentHash/status
```

The calculator is an **estimate**. User-facing copy should say that actual VA compensation can depend on additional factors and official VA determinations.

SMC and highly specialized compensation additions are out of the initial calculator unless explicitly implemented and validated later.

## 2A.11 File upload limits and abuse controls

Maximum individual uploaded file size for MVP:

```text
100 MB
```

This is a global technical/security limit, not a pricing-tier restriction.

Recommended initial maximum document page count:

```text
1,000 pages per PDF
```

If a legitimate document exceeds that page ceiling, the UX should explain that the user can split the document. A future server-side large-document workflow may raise this limit after cost/performance testing.

Initial supported user-upload file types:

- PDF;
- JPEG/JPG;
- PNG;
- HEIC/HEIF where supported safely by the chosen processing pipeline.

Never trust extension or client-declared MIME type alone. Server-side processing must validate actual content/type before expensive processing.

Implement configurable anti-abuse controls for **all** users, such as:

- uploads per rolling time period;
- bytes uploaded per rolling time period;
- concurrent document-processing jobs;
- AI/document-processing calls per rolling time period;
- maximum total queued processing workload;
- App Check enforcement where supported;
- rate limiting on expensive callable/HTTP functions.

Normal Veterans should not encounter these limits during normal use.

Users must be able to manually reclassify a document if classification is wrong.

## 2A.12 Vet Buddy behavior and safety UX

The assistant is named **Vet Buddy**.

Vet Buddy should proactively notice potentially relevant information, for example:

> Your records mention recurring numbness down your left leg. Would you like to review that as a possible condition related to your back symptoms?

But Vet Buddy must never silently make consequential decisions for the Veteran.

AI may:

- suggest a potential condition;
- suggest evidence to review;
- suggest questions;
- identify missing information;
- draft from confirmed facts;
- explain workflows;
- navigate the user to the correct UI.

Veteran confirmation is required before converting AI inference into confirmed Case/condition decisions or final submission content.

Never silently overwrite a Veteran-confirmed fact because AI inferred something different.

### Vet Buddy response footer

Vet Buddy responses must include a concise persistent safety/privacy footer at the end of the assistant response in the product UI. Keep it visually lightweight but explicit. Approved baseline wording:

> **Please verify important VA or medical information before acting. Do not share sensitive identifiers such as your Social Security number in chat.**

This applies to claims guidance and product-support conversations unless a later UX/legal decision replaces the exact wording.

Do not ask the Veteran to type an SSN, full bank account number, password, authentication code, or similar credential into Vet Buddy chat.

## 2A.13 C&P exam tracking — manual in MVP

MVP exam discovery is manual.

Do not depend on automatic VA/contractor C&P appointment discovery because there is no current public guarantee that one API provides every VA and contractor claim exam.

Provide a simple `Add Exam` form. No AI extraction is required for MVP.

Fields:

```text
exam date
time
time zone
exam type / relevant conditions
provider type: VA | contractor | unknown
contractor/provider name
location/address
phone
telehealth yes/no
notes
```

Users can edit exam details later.

Add a contextual link to the current VA appointment/claim-exam information page so a Veteran can check official information separately.

No device-calendar integration in MVP.

### Reminder

Send a push notification approximately:

```text
2 hours before the scheduled exam
```

Do not expose sensitive condition names in lock-screen notification text by default.

### Travel reimbursement guidance

The Exam detail screen must provide contextual reimbursement guidance based on `providerType`.

For a VA-facility exam, link to current VA travel-pay guidance.

For a contractor exam, explain that the contractor handles claim-exam travel reimbursement. Current VA guidance states that if contractor travel payment is not received within 14 days after the appointment, the Veteran should contact the contractor.

Authoritative reference:

https://www.va.gov/resources/va-claim-exam/

Do not hard-code contractor phone numbers indefinitely; keep any provider contact data in versioned/reference configuration or link to current VA guidance.

## 2A.14 Notifications

MVP notification channel:

```text
Firebase Cloud Messaging push notifications only
```

Do not add transactional email infrastructure in MVP.

Do not add SMS notifications beyond Firebase Authentication MFA.

Push notification copy must avoid unnecessary sensitive medical/claim details on the device lock screen.

Examples:

```text
Good: You have an upcoming Veteran Claims Buddy task.
Good: Your exam starts in about 2 hours.
Avoid: Your PTSD appeal deadline is tomorrow.
```

## 2A.15 Print & Mail fulfillment constraints

Print & Mail remains a third-party physical fulfillment service and is separate from the digital Case entitlement.

MVP constraints:

- ship to addresses in the United States and U.S. territories only;
- black-and-white printing only;
- single-sided printing only;
- **never duplex/double-sided** in MVP;
- allow available mail/service-level options only when the selected third-party provider supports them and our provider abstraction can quote them safely;
- add at most one generated cover/instruction page;
- keep cover sheet concise;
- mailing/shipping address is entered per order rather than relying on a persistent profile address;
- physical package is mailed to the Veteran, not directly to VA;
- Veteran is responsible for final review/signatures/submission.

Print & Mail is always its own checkout. It is a Stripe payment on iOS, Android, and web. It is never a RevenueCat product, never an App Store or Google Play product, and never combined into the digital Case purchase.

Customer-facing physical charge is a single `Print & Mail` amount. That amount includes:

- the live print/mail provider quote;
- a fixed service fee (`$9.95` at launch);
- a card-processing amount large enough that the Stripe fee is covered by the charge itself.

The service fee and the Stripe fee are not separate checkout lines. Terms and the checkout disclosure state that the price includes fulfillment, a service fee, and payment processing. Do not tell the Veteran that the app makes no money from Print & Mail.

Internally retain the provider quote, service fee, Stripe gross-up, estimated Stripe fee, and actual settled Stripe fee. The formula is in Section 38.14.

Print & Mail payments are **non-refundable once paid**. Display this clearly before the user confirms payment.

Recommended checkout acknowledgement:

> Print & Mail fulfillment fees are non-refundable once paid.

If the provider technically supports a pre-acceptance cancellation window, do not promise it as a consumer guarantee unless the owner later chooses to expose that behavior.

## 2A.16 Customer support and ticketing

MVP support includes:

1. a published support email address; and
2. an in-app customer-support ticket system.

Do not require an external helpdesk SaaS for MVP.

Suggested per-user collection:

```text
users/{uid}/supportTickets/{ticketId}
```

For efficient admin queries, also maintain/query a top-level admin-visible support projection if needed, for example:

```text
supportTickets/{ticketId}
```

Recommended ticket fields:

```json
{
  "uid": "...",
  "subject": "...",
  "category": "account|billing|technical|printMail|claimWorkflow|other",
  "status": "open|waitingOnUser|waitingOnSupport|resolved|closed",
  "priority": "normal|high|urgent",
  "lastMessageAt": "Timestamp",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Messages may be a subcollection.

Do not encourage users to put SSNs or other unnecessary PII in support tickets.

Vet Buddy may answer product-support questions from an approved product-help knowledge base, but its normal verification/privacy footer remains required.

## 2A.17 Web-only admin dashboard

Build an internal admin application as **web-only**.

The admin UI should prioritize efficient desktop/table layouts rather than reuse consumer mobile screens blindly.

Initial admin capabilities should include:

- support-ticket queue/detail/replies;
- user lookup using safe identifiers;
- billing/order lookup;
- Print & Mail order status diagnostics;
- form/revision qualification status;
- form catalog/release visibility;
- document-processing diagnostics;
- dev/QA information where appropriate;
- read-only visibility into relevant operational status without exposing unnecessary medical content.

Do not build an admin-role-management UI in MVP.

### Admin authorization

Use Firebase Authentication plus server-authoritative Firebase custom claims and server-side checks.

Recommended custom-claim model:

```json
{
  "roles": ["admin"]
}
```

or compact booleans if necessary to stay within custom-claim limits.

Initial roles may include:

```text
admin
support
formsAdmin
```

The owner may initially manage roles manually through an Admin SDK script.

Required scripts:

```bash
npm run admin:grant-role -- --uid <uid> --role admin
npm run admin:revoke-role -- --uid <uid> --role admin
npm run admin:list-roles -- --uid <uid>
```

Scripts must require privileged developer credentials and never run from Flutter.

After role change, document that Firebase ID tokens may need refresh/re-authentication before claims appear in a client session.

All privileged admin actions must be checked server-side. Hiding the admin route in Flutter/Web is not authorization.

## 2A.18 Account deletion grace period

MVP uses a **30-day deletion grace period**.

When the user requests account deletion:

```text
account status -> deletionScheduled
deletionRequestedAt -> now
purgeAfter -> now + 30 days
```

The UI must make the consequence extremely explicit before confirmation:

> Your account is scheduled for deletion. Unless you reactivate it within 30 days, your Veteran Claims Buddy case data, uploaded files, generated documents, symptom history, and other account content will be permanently removed, subject to records we must retain for completed financial/fulfillment transactions.

During the grace period:

- sign-in may be allowed only into a restricted reactivation/account-status flow;
- the user can cancel deletion/reactivate;
- normal claim processing should not continue silently while deletion is pending;
- do not immediately purge Storage/Firestore/Auth.

After grace expiration, a scheduled backend job must remove applicable user data across:

- Firestore user collections/subcollections;
- Cloud Storage user objects;
- Firebase Auth user;
- other user-scoped derived indexes/data.

Retain only the minimal billing/tax/fulfilled-order records required for legitimate accounting/legal purposes, with medical/claim content removed where not required.

A previously paid Print & Mail order remains non-refundable and, once fulfillment has been submitted, continues through the provider process even if account deletion is requested.

No `Download my data` feature is required for MVP.

## 2A.19 Security UX additions

Keep the previously selected email/password + verified email + required SMS MFA model.

Require fresh authentication/re-authentication for especially sensitive operations where practical, including:

- changing password/auth factors;
- revealing/editing a stored highly sensitive identifier;
- final digital package unlock/purchase confirmation where security warrants;
- account deletion;
- future direct VA submission if introduced.

Avoid storing SSN until a supported workflow actually requires it. If stored, use the dedicated encrypted sensitive-data design already required by this document and never render it broadly in UI/logs/analytics.

No delegated/sharing access in MVP.

## 2A.20 Development user reset semantics

Because local development uses the real development Firebase project, add a **user-scoped full reset** command as the primary developer workflow.

Required command shape:

```bash
npm run dev:reset-user -- --uid <uid> --confirm-dev-reset
```

It must remove that test user's:

- Firebase Auth account;
- all Firestore user-owned collections/subcollections/projections that are safe to delete;
- all Cloud Storage user objects;
- processing jobs;
- test billing/order projections that are explicitly marked development/test and safe to delete;
- other derived user-specific test data.

It must never delete global reference/form/rule configuration by default.

It must refuse to run unless the resolved Firebase/Google project ID exactly equals the configured development project ID.

Keep broader reset/seed scripts if useful, but user-scoped reset is the normal QA loop.

## 2A.21 Analytics and Crashlytics

Enable:

- Firebase Analytics;
- Firebase Crashlytics.

Analytics must be privacy-minimized.

Allowed product analytics examples:

- onboarding started/completed;
- screen/workflow completion;
- feature usage;
- paywall viewed;
- purchase funnel state;
- package generated;
- generic document upload success/failure;
- generic C&P-prep completion.

Do **not** put into analytics event names/parameters:

- condition names;
- diagnosis details;
- claim denial reasons;
- medical text;
- SSN;
- VA file numbers;
- document text;
- support-ticket content;
- Vet Buddy prompt/message contents.

No session replay product in MVP.

## 2A.22 Release rollout simplicity

Do not build a complex custom feature-cohort/release management system solely for preview users.

Use existing mechanisms such as:

- dev vs prod Firebase projects;
- app semantic/build versions;
- TestFlight/internal/beta distribution;
- Google Play internal/closed testing;
- controlled web deployment;
- the explicit VA form catalog/app-version pinning system already specified in this document.

The form safety/version rules remain required because they protect old app versions from silently receiving incompatible VA form revisions.

A remotely controlled minimum-supported-version mechanism may be used for critical safety/compatibility situations, but do not turn it into a general feature-flag platform unless needed.

## 2A.23 Theme and responsive UI

MVP has one supported theme:

```text
dark
```

Do not build a light/dark user toggle in MVP.

All visual colors/styles must still come from centralized Flutter Theme/theme-extension tokens so a future light theme can be introduced without rewriting widgets.

Create responsive reusable components for:

- cards;
- tables/lists;
- two/three-column desktop layouts;
- mobile stacked layouts;
- dashboard sections;
- forms;
- dialogs/sheets;
- status chips;
- timelines;
- evidence rows;
- admin tables.

Do not create separate duplicated business screens for mobile and web when responsive composition is sufficient.

## 2A.24 Accessibility

Accessibility is an acceptance requirement, not post-launch polish.

At minimum:

- screen-reader semantics;
- keyboard access on web;
- meaningful focus order;
- sufficient contrast;
- scalable text;
- touch target sizing;
- no color-only status communication;
- accessible validation/error messages;
- semantic labels for custom controls/sliders;
- accessible PDF/download actions;
- responsive layouts at large text sizes.

Dark theme must still meet contrast requirements.

## 2A.25 Legal/static pages required before production launch

The public static site must include production-ready versions of these pages. Paths match `docs/page-navigation.md`:

- Privacy Policy — `/privacy`
- Terms of Service — `/terms`
- subscription terms — `/terms/subscription`
- cancellation/refund explanation — `/terms/refunds`
- Print & Mail fulfillment, service fee, card fee, and non-refund terms — `/terms/print-and-mail`
- AI/data-use disclosure — `/ai-disclosure`
- independent/non-VA-affiliation disclaimer — marketing home, `/terms`, and app registration
- account deletion explanation — `/account-deletion`
- support/contact information — `/support`

Do not invent final legal assurances. Engineering may scaffold the pages and required sections, but owner/legal review is required before public release. Current draft copy is in `docs/legal/`. Use Veteran Claims Buddy LLC, Iowa, and `support@veteranclaimsbuddy.com`. Do not invent a mailing address.

## 2A.26 Refund/cancellation behavior

Digital one-time purchases and subscriptions follow the applicable Apple/Google/Stripe platform mechanisms and policies.

The product must never promise a guaranteed VA outcome as grounds for the digital charge.

Subscription cancellation stops future renewal; it does not delete historical Case/artifact/symptom data.

Print & Mail physical fulfillment is explicitly non-refundable once the order is submitted/paid for fulfillment, as described above.

## 2A.27 Current implementation priority summary

Agents should treat the following as the current product shape:

```text
Veteran Claims Buddy
    |
    +-- public static Firebase-hosted marketing/SEO site
    |
    +-- Flutter iOS / Android / Web app
            |
            +-- email/password + verified email + SMS MFA
            +-- free guided disability-claims workspace
            +-- Vet Buddy AI assistant
            +-- one primary Working Case UX
            +-- full evidence/document workflow
            +-- manual C&P tracking + 2-hour push reminder
            +-- free VA rating/compensation calculator
            +-- $250 one-time Case digital-package unlock
            +-- $30/month Premium
            |       +-- active package generation
            |       +-- symptom/health tracking
            |       +-- monthly AI symptom summaries
            +-- third-party Print & Mail
            +-- support tickets
            +-- web-only admin dashboard
            +-- self-submission guidance; no direct VA filing required for MVP
```


---

# 3. High-level architecture

```text
                      Flutter
             iOS / Android / Web
                         |
             +-----------+-----------+
             |                       |
      Firebase Auth             App Check
             |                       |
             +-----------+-----------+
                         |
                    Firestore
                structured case data
                         |
             +-----------+-----------+
             |                       |
      Firebase Storage          Cloud Functions
      user file bytes           JavaScript / Gen2
             |                       |
             |             +---------+----------+
             |             |         |          |
             |       Vertex Gemini   VA APIs    Tasks
             |             |                    |
             +-------------+--------------------+
                           |
                    derived case facts
                           |
                       Firestore

Firebase Cloud Messaging -> push notifications
Secret Manager            -> external API/model secrets
Cloud Tasks               -> asynchronous/retriable processing
Cloud Run Jobs            -> only for very large processing workloads
```

---

# 4. Environments

Create exactly two Firebase projects initially:

- `<PRODUCT>-dev`
- `<PRODUCT>-prod`

Firebase recommends separate Firebase projects for separate lifecycle environments.

Official reference:  
https://firebase.google.com/docs/projects/dev-workflows/overview-environments

## 4.1 Development policy

Development builds use the real development Firebase project.

This includes:

- Auth;
- Firestore;
- Storage;
- Functions;
- FCM;
- App Check in a development-compatible configuration.

Development data is disposable.

The repo must contain scripts that can:

- wipe Veteran/user application data from the dev project;
- wipe dev Storage objects belonging to test users;
- seed global reference data;
- seed fake Veterans/cases;
- optionally recreate known QA scenarios.

## 4.2 Production policy

Production data must never be reset by repository scripts.

Any destructive script must perform both checks:

1. active/explicit project ID must exactly match the configured development Firebase project ID;
2. the caller must pass an explicit destructive confirmation such as `--confirm-dev-reset`.

If either check fails, exit nonzero before making any API call.

## 4.3 Flutter flavors

Use two Flutter flavors:

- `dev`
- `prod`

Use distinct application IDs/bundle IDs so both can be installed on one device.

Recommended application ids, matching gate 0E unless the owner replaces them there:

```text
Android dev:  com.veteranclaimsbuddy.app.dev
Android prod: com.veteranclaimsbuddy.app

iOS dev:      com.veteranclaimsbuddy.app.dev
iOS prod:     com.veteranclaimsbuddy.app
```

Web has no bundle id. It still must be launched with `--flavor dev` or `--flavor prod` so `appFlavor` is set. A web production build must fail if the flavor is missing.

Use visibly different application display names:

```text
Veteran Claims Buddy Dev
Veteran Claims Buddy
```

A distinct dev icon/badge is recommended so a tester cannot accidentally confuse production with development.

One codebase. The flavor chooses the Firebase options file. There is no second `main.dart`.

## 4.4 Flutter launch commands

Run these from `/app` after flavors exist. List devices with `flutter devices` and add `-d <device-id>` when more than one is connected.

```bash
flutter run --flavor dev
flutter run --flavor prod

flutter run --flavor dev -d chrome
flutter run --flavor prod -d chrome
```

The first pair is iOS or Android, whichever device is selected. Pass `-d` with an iOS or Android id to force the platform. Web always needs `-d chrome` (or another browser id) plus `--flavor`.

Release builds:

```bash
flutter build apk --flavor dev
flutter build apk --flavor prod
flutter build appbundle --flavor prod

flutter build ipa --flavor dev
flutter build ipa --flavor prod

flutter build web --flavor dev
flutter build web --flavor prod
```

`flutter build ipa` needs the matching Xcode scheme (`dev` or `prod`) and a signing setup the owner has completed. Do not infer the flavor from debug or release mode. A release build of the dev flavor is still the dev app.

Official Flutter Android flavor guide:  
https://docs.flutter.dev/deployment/flavors

Official Flutter iOS flavor guide:  
https://docs.flutter.dev/deployment/flavors-ios

---

# 5. Repository layout

Use a monorepo.

```text
/
  README.md
  AGENTS.md
  firebase.json
  .firebaserc
  firestore.rules
  firestore.indexes.json
  storage.rules
  package.json                    # optional root orchestration scripts

  /app                            # Flutter application
    pubspec.yaml
    /lib
      main.dart
      firebase_options_dev.dart
      firebase_options_prod.dart

      /app
        app.dart
        app_bootstrap.dart
        app_environment.dart
        router.dart
        theme.dart

      /core
        /auth
        /errors
        /logging
        /firebase
        /navigation
        /security
        /widgets
        /utils

      /features
        # Code modules. Routes and tabs come from docs/page-navigation.md.
        # These folders are not extra navigation destinations.
        /auth
        /home
        /onboarding
        /cases
        /buddy
        /plans
        /calculator
        /symptoms
        /support
        /billing
        /settings
        /admin
        /profile
        /service_history
        /conditions
        /claims
        /evidence
        /documents
        /questionnaires
        /exams
        /decisions
        /decision_reviews
        /tasks

      /data
        /models
        /repositories
        /converters
        /queries

    /test
    /integration_test

  /functions                       # Cloud Functions JavaScript, 2nd gen
    package.json
    /src
      index.js
      /config
      /auth
      /claims
      /documents
      /evidence
      /questionnaires
      /workflow
      /deadlines
      /notifications
      /ai
        /flows
        /tools
        /prompts
        /providers
      /va
        /clients
        /claims
        /forms
        /intake
        /decision-reviews
      /knowledge
      /admin
      /shared

  /scripts                         # repository/admin scripts
    package.json
    /src
      reset-dev.js
      seed-dev.js
      seed-reference-data.js
      create-test-user.js
      verify-environment.js

  /docs
    page-navigation.md          # source of truth for pages, routes, and nesting
    /legal                      # draft privacy, terms, and related pages. Not final legal text.
    architecture.md
    firestore-schema.md
    security-model.md
    va-integrations.md
    ai-agent-contract.md
    questionnaires.md
    workflows.md
```

`docs/page-navigation.md` is the source of truth for which screens exist and how they nest. If this handoff or a later plan disagrees with that file, stop and raise the conflict before implementation. Update `docs/page-navigation.md` in the same change when the map itself changes.

`AGENTS.md` should summarize the non-negotiable decisions in Sections 1-4 so coding agents receive them automatically when supported.

---

# 6. Build sequence overview

Build in this order:

1. Workstation + Flutter repo.
2. Firebase dev/prod projects.
3. Flutter flavors and FlutterFire configuration.
4. Firebase infrastructure initialization.
5. Email/password auth + verified email + mandatory SMS MFA + App Check + security rules foundation.
6. Application shell/navigation.
7. Firestore domain model/repositories.
8. Dev reset/seed tooling.
9. Veteran onboarding/service history.
10. Universal condition discovery/questionnaires.
11. Claim Issue model and evidence matrices.
12. File/document management.
13. Document AI extraction and provenance.
14. Assistant/agent tool framework.
15. Deterministic next-action/workflow engine.
16. C&P exam workflows.
17. Decision-letter analysis.
18. Decision-review workflows.
19. VA knowledge synchronization.
20. VA API integrations.
21. Notifications.
22. Security hardening and data lifecycle.
23. CI/CD, release, TestFlight/Play testing.
24. Production launch readiness.

The following sections describe each phase and explicitly identify owner/manual gates.

---

# 7. Phase 0 — Owner workstation prerequisites

## OWNER ACTION GATE 0A — Install/verify Flutter

Follow the current Flutter installation guide:

https://docs.flutter.dev/install

Verify:

```bash
flutter --version
flutter doctor -v
```

Resolve all issues for the platforms you intend to run locally.

For iOS development, Xcode and a macOS machine are required.

For Android, install Android Studio or the Android SDK/toolchain required by Flutter.

The project should use the current stable Flutter channel unless a documented plugin incompatibility requires otherwise.

## OWNER ACTION GATE 0B — Install Node.js

Cloud Functions and repository scripts use JavaScript, not TypeScript.

Install a Cloud Functions-supported Node version. At the time of this document Firebase supports Node.js 20 and 22 for modern Functions runtimes; verify current support before initializing.

Official Functions guide:

https://firebase.google.com/docs/functions/get-started

Verify:

```bash
node --version
npm --version
```

## OWNER ACTION GATE 0C — Install Firebase CLI

Official guide:

https://firebase.google.com/docs/cli

Typical npm installation:

```bash
npm install -g firebase-tools
firebase --version
firebase login
```

Use the Google account that will own/administer the development Firebase project.

## OWNER ACTION GATE 0D — Install FlutterFire CLI

Official Flutter/Firebase setup guide:

https://firebase.google.com/docs/flutter/setup

Install:

```bash
dart pub global activate flutterfire_cli
```

Verify:

```bash
flutterfire --version
```

Make sure the Dart global binary directory is on PATH if the command is not found.

## OWNER ACTION GATE 0E — Choose identifiers

Confirm these before `flutter create` in gate 1A. Creating the Firebase project in Phase 2 does not need them. Registering the iOS and Android apps with FlutterFire does. `flutter create` bakes the org prefix into the project, so changing it later means changing the native application ids.

Proposed values, using the `veteranclaimsbuddy` placeholder:

```text
PRODUCT_DISPLAY_NAME=Veteran Claims Buddy
DART_PACKAGE_NAME=veteran_claims_buddy
ANDROID_PROD_APPLICATION_ID=com.veteranclaimsbuddy.app
ANDROID_DEV_APPLICATION_ID=com.veteranclaimsbuddy.app.dev
IOS_PROD_BUNDLE_ID=com.veteranclaimsbuddy.app
IOS_DEV_BUNDLE_ID=com.veteranclaimsbuddy.app.dev
```

The owner confirms or replaces this list at this gate. Do not use `com.example`. The `flutter create` org prefix that matches the ids above is `com.veteranclaimsbuddy`, with the created project directory named `app`.

Firebase project ids are separate, for example `veteran-claims-buddy-dev` and `veteran-claims-buddy-prod`. They do not have to equal the bundle id.

---

# 8. Phase 1 — Scaffold the Flutter repository

## OWNER ACTION GATE 1A — Create the Flutter app

The owner runs this. The agent does not create the Flutter project by writing `android/`, `ios/`, `web/`, or `pubspec.yaml` by hand.

From the repository root, after the identifiers in gate 0E are chosen:

```bash
flutter create --org <reverse-domain-company-prefix> --platforms=android,ios,web app
```

Official Flutter app creation reference:

https://docs.flutter.dev/reference/create-new-app

Success looks like an `/app` directory that `flutter analyze` can see. Confirm that before flavor or feature work starts.

If desktop platforms are desired later, add them deliberately; do not make them MVP requirements.

## AGENT TASK 1B — Add baseline packages

Do this only after gate 1A is confirmed and `/app/pubspec.yaml` exists.

Use `flutter pub add` with no version pin so each package is the latest stable major. The agent may add the plain packages below directly to `pubspec.yaml`.

Phase 1 plain packages:

```text
firebase_core
firebase_auth
cloud_firestore
firebase_storage
cloud_functions
firebase_app_check
firebase_messaging
flutter_riverpod
go_router
flutter_adaptive_scaffold
flutter_svg
intl
uuid
collection
package_info_plus
```

Riverpod is the screen-state and repository layer. Firestore access goes through repositories Riverpod provides. Do not add an ORM, `freezed`, `json_serializable`, or `riverpod_generator`.

UI is Material 3 with centralized theme extensions. `flutter_adaptive_scaffold` is for the phone and wide layouts. `flutter_svg` is for brand assets. Do not add `google_fonts`, `flutter_form_builder`, or `hooks_riverpod`.

Add these when the feature that needs them starts. They are still plain packages, so the agent may add them to `pubspec.yaml` at the latest stable version:

```text
file_picker
image_picker
url_launcher
share_plus
pdfrx
webview_flutter
```

`pdfrx` reviews a generated PDF inside the app. It does not fill VA forms. `webview_flutter` loads the marketing calculator. `image_picker` is for symptom photos and camera uploads. When `image_picker` is added, also add the platform photo and camera permission strings in the native projects.

Do not add these until their owner gates are done:

```text
purchases_flutter
flutter_stripe
```

`flutter_launcher_icons` and `flutter_native_splash` may be added to `pubspec.yaml` by the agent. Running their generators is an owner gate after the dev and prod assets exist.

## AGENT TASK 1C — Configure flavors

Create `dev` and `prod` Android product flavors and iOS schemes/configurations. Web uses the same flavor names through `--flavor`. It does not get a second application id.

Requirements:

- dev has `.dev` identifier suffix;
- prod has the final production identifier;
- dev app display name includes `Dev`;
- environment is readable through `appFlavor`;
- production build must fail if environment cannot be determined;
- dev should be the convenient local default where Flutter tooling allows it.

Create:

```text
lib/app/app_environment.dart
```

Concept:

```dart
enum AppEnvironment { dev, prod }
```

Expose:

```dart
AppEnvironment currentEnvironment
bool get isDevelopment
bool get isProduction
```

Never infer production/dev from `kDebugMode`; release builds can target dev.

## Definition of done — Phase 1

The agent must demonstrate:

```bash
flutter analyze
flutter test
flutter run --flavor dev
```

with a simple non-Firebase placeholder screen before proceeding.

---

# 9. Phase 2 — Create Firebase projects

## OWNER ACTION GATE 2A — Create development Firebase project

Open:

https://console.firebase.google.com/

Create a project whose ID clearly indicates development, for example:

```text
<product>-dev
```

Record the immutable Firebase project ID in `/docs/environment-values.md` **without secrets**.

Do not put credentials in that document.

Google Analytics is optional initially. For this health/benefits-oriented application, minimize analytics collection and do not enable advertising-oriented analytics simply because the wizard offers it.

## OWNER ACTION GATE 2B — Upgrade development project to Blaze

Cloud Functions production deployment requires Blaze, and Cloud Storage for Firebase currently requires Blaze for access to new/default buckets.

Cloud Storage requirement reference:

https://firebase.google.com/docs/storage/gcp-integration

Cloud Functions reference:

https://firebase.google.com/docs/functions

Upgrade the dev project to Blaze.

This does **not** imply that all usage is billed immediately; many Google Cloud/Firebase services retain free usage allowances. It does mean a billing account is attached and overages can incur cost.

## OWNER ACTION GATE 2C — Create a development billing budget

In Google Cloud Billing for the Firebase project's underlying Google Cloud project, create conservative budget alerts.

Official budget docs:

https://cloud.google.com/billing/docs/how-to/budgets

Recommended initial alert thresholds:

```text
50%
80%
100%
```

Also configure an absolute monthly budget appropriate to current development tolerance.

Important: budget alerts generally alert; they do not automatically hard-stop every service. Do not treat a budget as a guaranteed spending cap.

## OWNER ACTION GATE 2D — Create production Firebase project

Create a separate project:

```text
<product>-prod
```

Do not seed real users yet.

Production can be connected/configured now, while production deployment occurs later.

## OWNER ACTION GATE 2E — Production billing

Upgrade production to Blaze before Storage/Functions are required.

Create separate production budget alerts.

Never share dev and prod Storage buckets, Auth tenants/users, or Firestore databases.

---

# 10. Phase 3 — Connect Flutter to Firebase with FlutterFire

The official FlutterFire setup flow is:

https://firebase.google.com/docs/flutter/setup

FlutterFire CLI registers selected platform apps and generates Firebase configuration code.

## OWNER ACTION GATE 3A — Configure dev Firebase apps

The owner runs FlutterFire. The agent does not invent `firebase_options_dev.dart` or the native Google config files.

From `/app`, authenticate with Firebase CLI if needed:

```bash
firebase login
```

Run FlutterFire configuration for the **development** project and select Android, iOS, and Web.

Use the real dev application IDs created by the flavor setup.

Generate a clearly dev-specific options file:

```text
lib/firebase_options_dev.dart
```

If the current FlutterFire CLI supports explicit output/project parameters, use those. Otherwise run the guided workflow and rename/organize the generated output carefully.

After configuration, verify Firebase Console -> Project settings -> Your apps contains the expected dev Android/iOS/Web registrations.

Tell the agent when this gate is done before Firebase bootstrap code is written.

## OWNER ACTION GATE 3B — Configure prod Firebase apps

Repeat for the production Firebase project, generating:

```text
lib/firebase_options_prod.dart
```

Verify the production Firebase project contains the prod platform apps.

## AGENT TASK 3C — Bootstrap Firebase by flavor

Create `app_bootstrap.dart` such that:

```text
dev flavor  -> DefaultFirebaseOptionsDev.currentPlatform
prod flavor -> DefaultFirebaseOptionsProd.currentPlatform
```

Initialization shape:

```dart
WidgetsFlutterBinding.ensureInitialized();

await Firebase.initializeApp(
  options: environment.firebaseOptions,
);

runApp(...);
```

Do not ship runtime logic that can dynamically point a production binary at the development project.

## AGENT TASK 3D — Add environment banner

For dev only, show a subtle but unmistakable `DEV` marker in the app shell or debug settings.

## Definition of done — Phase 3

The dev app must connect to `<product>-dev` and the prod app to `<product>-prod`.

Create a temporary diagnostic screen that displays:

- Firebase project ID;
- flavor;
- app identifier;

and verify both builds manually.

Remove or hide sensitive diagnostic information before production release.

---

# 11. Phase 4 — Initialize Firebase backend resources

From repository root, initialize Firebase configuration against the dev project.

The repo should contain `.firebaserc` aliases such as:

```json
{
  "projects": {
    "dev": "<product>-dev",
    "prod": "<product>-prod"
  }
}
```

Then developers can deliberately run:

```bash
firebase use dev
firebase deploy --project dev
```

or:

```bash
firebase deploy --project prod
```

Do not rely only on whichever project happens to be active in a developer shell for CI/CD.

The same Functions source is deployed to both projects. There is not a second functions entry file. Each Firebase project has its own Secret Manager. Set a key on the project that will run it, for example:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY --project dev
firebase functions:secrets:set STRIPE_SECRET_KEY --project prod
```

Do not copy dev secret values into prod. Vertex and other provider keys follow the same per-project rule.

## OWNER ACTION GATE 4A — Create Firestore database

Firebase Console -> Databases & Storage -> Firestore Database -> Create database.

Select a region deliberately.

The region is difficult/expensive to change later, so select a U.S. region appropriate for expected users and adjacent services.

Start in locked/production mode rather than permissive test rules.

Firestore rules docs:

https://firebase.google.com/docs/firestore/security/get-started

## OWNER ACTION GATE 4B — Create Storage bucket

Firebase Console -> Databases & Storage -> Storage -> Get started.

Choose a location that aligns sensibly with the app's Google Cloud region and cost objectives.

Cloud Storage for Firebase requires Blaze.

Do not configure public read access.

## OWNER ACTION GATE 4C — Initialize config files

The owner runs `firebase init`. The agent does not hand-write the Firebase project skeleton.

Initialize:

- Firestore;
- Functions, and choose JavaScript;
- Storage.

Use 2nd-gen Functions APIs and Node 22.

Create/retain:

```text
firebase.json
firestore.rules
firestore.indexes.json
storage.rules
functions/
```

Functions setup docs:

https://firebase.google.com/docs/functions/get-started

Confirm the generated Functions entry file is JavaScript before any function code is added.

## AGENT TASK 4D — Functions runtime

Use a currently supported Node runtime. Prefer Node 22 unless a dependency requires Node 20.

Set the Functions region explicitly in shared config so functions are not accidentally scattered across regions.

Use a shared constant:

```js
exports.PRIMARY_REGION = "<chosen-region>";
```

---

# 12. Phase 5 — Authentication + required SMS MFA

Authentication for this product is:

```text
First factor:  Email + password
Requirement:   Verified email
Second factor: SMS MFA
Policy:        MFA required before the Veteran can enter or access sensitive case/onboarding data
Provider:      Firebase Authentication upgraded to Authentication with Identity Platform
```

Do not implement phone-number-only sign-in. The phone number exists as a second factor, not the primary account identity.

Firebase's current Flutter MFA documentation requires Firebase Authentication with Identity Platform, verified email, and platform-specific phone-verification configuration.

Official references:

- Firebase Authentication overview / Identity Platform upgrade:
  https://firebase.google.com/docs/auth
- Flutter email/password authentication:
  https://firebase.google.com/docs/auth/flutter/password-auth
- Flutter SMS multi-factor authentication:
  https://firebase.google.com/docs/auth/flutter/multi-factor
- Flutter phone authentication/testing:
  https://firebase.google.com/docs/auth/flutter/phone-auth
- Firebase security checklist:
  https://firebase.google.com/support/guides/security-checklist

Firebase currently warns that SMS is a weaker second factor than authenticator-based methods. SMS MFA is still the selected MVP implementation for this product because it minimizes Veteran setup friction. Keep the authentication abstraction capable of supporting additional second-factor methods later; do not hard-code the domain model to `sms` as the only possible factor type.

## Required registration/sign-in sequence

The application must enforce this sequence:

```text
Create email/password account
        ↓
Send verification email
        ↓
User verifies email
        ↓
Require SMS MFA enrollment
        ↓
Verify MFA enrollment
        ↓
Create/activate sensitive Veteran workspace
        ↓
Begin onboarding
```

Future sign-in:

```text
Email + password
        ↓
Firebase reports MFA challenge required
        ↓
Send SMS to enrolled factor
        ↓
User enters code
        ↓
Resolve MFA sign-in
        ↓
App access
```

A user must not be allowed to skip MFA and proceed into the Veteran onboarding/claims workspace.

---

## OWNER ACTION GATE 5A — Upgrade DEV Authentication to Identity Platform

**AGENT MUST STOP HERE before implementing MFA-dependent flows.**

Owner steps:

1. Open the **development** Firebase project in Firebase Console:
   https://console.firebase.google.com/
2. Open **Security -> Authentication**.
3. Open Authentication **Settings** if Firebase presents an upgrade banner/action there.
4. Upgrade the project to **Firebase Authentication with Identity Platform**.
5. Read/accept any pricing/terms shown by Google.
6. Confirm the project still points at the already-connected Blaze billing account.
7. Return to Authentication and confirm the project exposes the advanced MFA configuration.

Official Firebase documentation states that upgrading does not require migrating existing Firebase Auth client/Admin SDK code; it enables features including MFA.

**Owner confirmation required:**

```text
DEV Identity Platform enabled: YES
```

The agent must not continue MFA implementation until this is confirmed.

---

## OWNER ACTION GATE 5B — Upgrade PROD Authentication to Identity Platform

Repeat the same Identity Platform upgrade in the **production** Firebase project.

This may be completed during the same session as 5A even though production users do not exist yet. Doing it now prevents the production authentication architecture from diverging from development.

**Owner confirmation required:**

```text
PROD Identity Platform enabled: YES
```

Do not create production test users yet.

---

## OWNER ACTION GATE 5C — Enable Email/Password first factor in DEV and PROD

For **each** Firebase project:

1. Firebase Console -> **Security -> Authentication -> Sign-in method**.
2. Enable **Email/Password**.
3. Do not enable anonymous authentication.
4. Do not enable Phone as a primary sign-in provider merely because SMS is used for MFA.
5. Save.

The selected MVP first factor is email/password only.

**Owner confirmation required:**

```text
DEV Email/Password enabled: YES
PROD Email/Password enabled: YES
```

---

## OWNER ACTION GATE 5D — Enable SMS multi-factor authentication

For **each** Firebase project:

1. Firebase Console -> **Security -> Authentication -> Sign-in method**.
2. Locate the **Advanced** / multi-factor authentication section.
3. Enable **SMS Multi-factor Authentication**.
4. Save.

If Firebase redirects to the corresponding Google Cloud Identity Platform MFA page, that is expected; use the same underlying project.

Do not make MFA optional in product behavior merely because Firebase supports optional enrollment patterns.

Our product policy is:

```text
Verified email + at least one enrolled SMS second factor
is required before sensitive onboarding/case access.
```

**Owner confirmation required:**

```text
DEV SMS MFA enabled: YES
PROD SMS MFA enabled: YES
```

---

## OWNER ACTION GATE 5E — Configure DEV fictional/test phone numbers

This step is mandatory for development because local builds connect to the real development Firebase project and we do not use the Authentication Emulator.

Firebase supports fictional test phone numbers that:

- send no actual SMS;
- consume no SMS quota for those tests;
- avoid throttling during repeated development;
- use a developer-selected fixed 6-digit verification code;
- can be used from simulator/emulator environments.

Owner steps in the **DEV Firebase project only**:

1. Firebase Console -> **Security -> Authentication -> Sign-in method**.
2. Open the SMS MFA / Phone configuration area.
3. Expand **Phone numbers for testing**.
4. Add at least two fictional phone numbers in valid E.164 format.
5. Use numbers that are definitely fictional and not owned by a real person. For U.S. test data, use an appropriate fictional `555`-style number where Firebase accepts it.
6. Assign a 6-digit test verification code to each number.
7. Use non-obvious codes rather than `123456` in shared development environments.
8. Do **not** place the configured test phone numbers/codes in committed source files, screenshots in public docs, or production configuration.
9. Record the test values in the team's private development secret/password manager if multiple developers need them.

Firebase currently permits up to 10 fictional phone numbers for development.

Recommended pattern:

```text
Developer A test identity -> fictional number A -> fixed test code A
Integration test identity -> fictional number B -> fixed test code B
```

Do not configure normal development test numbers in production. If an App Store/Play review later requires a production review account using a fictional MFA number, create a temporary review-specific production test number during the release process and delete/rotate it afterward.

Official reference:
https://firebase.google.com/docs/auth/flutter/phone-auth

**Owner confirmation required:**

```text
DEV Firebase test phone numbers configured: YES
```

The agent may ask the owner to manually test with one configured number/code, but the owner does not need to paste the code into this handoff.

---

## OWNER ACTION GATE 5F — Configure SMS region policy

Identity Platform/Firebase uses an SMS region policy. New projects may begin with a restrictive policy, and real SMS MFA will fail if the destination region is blocked.

For DEV and PROD:

1. Firebase Console -> **Security -> Authentication -> Settings**.
2. Find **SMS region policy**.
3. Configure the allowed regions appropriate for the product's supported users.
4. At minimum, ensure U.S. phone numbers can receive MFA because the product serves U.S. Veterans.
5. Do not unnecessarily enable every country if the product is not ready to support them; expand deliberately for Veterans living abroad as product requirements demand.
6. Save.

Test/fictitious numbers should remain the normal development path. Real-number testing should be limited to targeted platform verification.

**Owner confirmation required:**

```text
DEV SMS region policy reviewed/configured: YES
PROD SMS region policy reviewed/configured: YES
```

---

## AGENT TASK 5G — Add Firebase Auth dependency and base email/password flow

From `/app`:

```bash
flutter pub add firebase_auth
```

Implement:

```text
Welcome
Create account
Sign in
Forgot password
Verify email
MFA enrollment
MFA challenge
Sign out
Security / MFA settings
```

Account creation must:

1. create the Firebase email/password user;
2. send email verification;
3. route to `VerifyEmailScreen`;
4. prevent sensitive onboarding until verification is complete;
5. after verified email is observed/refreshed, route to mandatory MFA enrollment;
6. only after MFA enrollment succeeds, create/activate the Veteran's sensitive workspace and continue to onboarding.

Do not ask for SSN, VA identifiers, medical records, claim history, or similarly sensitive claim information before MFA enrollment is complete.

---

## AGENT TASK 5H — Prepare Android fingerprint values, then STOP

Firebase phone verification/MFA on Android requires app verification configuration.

The agent must generate the development Android signing certificate fingerprint(s) and present them to the owner.

Use the Android/Gradle signing report appropriate to the generated Flutter project, for example from the Android directory:

```bash
./gradlew signingReport
```

On Windows use the Gradle wrapper equivalent:

```text
gradlew signingReport
```

Capture the **SHA-256** fingerprint for the development/debug app signing configuration. Also capture SHA-1 if the output is available, because other Firebase/Google integrations may use it later.

The agent must not invent fingerprints.

### OWNER ACTION GATE 5H.1 — Register Android DEV fingerprint

Owner steps:

1. Firebase Console -> DEV project -> **Project settings -> General**.
2. Scroll to **Your apps**.
3. Select the **development Android app** registered during FlutterFire setup.
4. Under **SHA certificate fingerprints**, add the SHA-256 supplied by the agent.
5. Add SHA-1 as well if supplied.
6. Save.
7. If Firebase instructs you to download an updated `google-services.json`, tell the agent; the agent should regenerate/re-run FlutterFire configuration or replace the platform config through the supported FlutterFire workflow rather than manually creating config values.

Official Flutter MFA reference:
https://firebase.google.com/docs/auth/flutter/multi-factor

**Owner confirmation required:**

```text
DEV Android SHA-256 registered: YES
```

The agent must not declare Android MFA complete before this gate is confirmed.

### Production Android fingerprints

Do not use the debug fingerprint for production.

When the production signing/upload key exists during release preparation, the agent must pause again and provide its release SHA-256 to the owner. The owner must add it to the **production Android Firebase app** before production MFA testing/release.

This is a separate release-time owner gate; do not fabricate a release certificate early simply to satisfy this document.

---

## AGENT TASK 5I — Prepare iOS phone-verification capabilities, then STOP for APNs owner action

For the iOS Runner target, the agent must configure the project capabilities required by current Firebase phone/MFA documentation:

- Push Notifications;
- Background Modes -> Remote notifications.

Do not embed APNs private keys in the repository.

### OWNER ACTION GATE 5I.1 — Configure Apple APNs authentication for DEV Firebase

This requires the owner's Apple Developer access.

Owner steps:

1. In the Apple Developer portal, create or select an APNs authentication key appropriate for this application/team.
2. Download the `.p8` key **once** and store it securely; Apple does not allow re-downloading the same private key later.
3. Record the Apple Key ID and Team ID securely.
4. Open Firebase Console -> DEV project -> **Project settings -> Cloud Messaging**.
5. Locate the Apple app/APNs authentication key configuration.
6. Upload the APNs `.p8` key and provide the required Key ID and Team ID.
7. Save.
8. Never commit the `.p8` file to Git or place it in `/docs`.

Official Flutter MFA docs require iOS push-notification capability, APNs configuration with FCM, and remote-notification background mode for phone verification.

Reference:
https://firebase.google.com/docs/auth/flutter/multi-factor

**Owner confirmation required:**

```text
DEV iOS APNs auth configured in Firebase: YES
```

### Production iOS APNs configuration

Before production iOS MFA testing/release, repeat the Firebase-side APNs configuration for the production Firebase project/app. The same Apple APNs auth key may support multiple apps for the Apple team depending on Apple key configuration, but the owner must explicitly configure the production Firebase project; do not assume DEV configuration carries over.

---

## OWNER ACTION GATE 5J — Configure a DEV web domain for SMS MFA testing

Phone/SMS verification on web relies on an authorized web origin and anti-abuse verification. Do not assume Flutter Web MFA will behave correctly from arbitrary localhost origins.

For predictable development testing, use a deployed development web origin such as the project's Firebase Hosting domain or another HTTPS development domain.

Owner/agent sequence:

1. Agent initializes Firebase Hosting for the dev project when the web build is ready.
2. Agent deploys a dev web build to the DEV Firebase Hosting site.
3. Owner opens Firebase Console -> **Security -> Authentication -> Settings**.
4. Under **Authorized domains**, confirm the deployed Firebase Hosting domain is present; add the approved development domain if needed.
5. Do not add broad wildcard domains.

If the team does not actively develop/test Flutter Web during the first mobile milestone, this gate may be deferred, but the agent must mark Web MFA as **not yet verified**, not as complete.

Reference:
https://firebase.google.com/docs/auth/flutter/multi-factor

---

## AGENT TASK 5K — Implement mandatory SMS MFA enrollment

After email verification, enroll the user's phone as a second factor using FlutterFire's multi-factor APIs.

Required flow:

```text
verified Firebase user
        ↓
MFAEnrollmentScreen
        ↓
explain that a phone number will be stored/used by Firebase for authentication
        ↓
user enters phone number
        ↓
user.multiFactor.getSession()
        ↓
FirebaseAuth.verifyPhoneNumber(multiFactorSession: ...)
        ↓
code sent / test code expected
        ↓
PhoneAuthProvider.credential(...)
        ↓
PhoneMultiFactorGenerator.getAssertion(...)
        ↓
user.multiFactor.enroll(...)
        ↓
refresh auth state/token
        ↓
mark app-level security state as MFA-enrolled using trusted server verification
        ↓
continue to onboarding
```

The UI must obtain appropriate user consent before sending/storing the phone number for Firebase authentication. Firebase documentation notes that Google stores/uses phone numbers for spam and abuse prevention.

The app must display the phone number in masked form after enrollment.

Do not store the raw MFA phone number in normal Firestore profile documents merely for convenience. Firebase Authentication owns the enrolled factor. If a masked display value is needed in app UI, derive it from Firebase Auth's enrolled factor information or store only a deliberately masked representation.

---

## AGENT TASK 5L — Implement MFA challenge during sign-in

`signInWithEmailAndPassword()` for an MFA-enrolled user will require second-factor resolution.

The agent must catch FlutterFire's multi-factor-required authentication exception and use its resolver/session rather than treating it as a failed password login.

Required flow:

```text
email/password submitted
        ↓
Firebase first factor succeeds
        ↓
FirebaseAuthMultiFactorException
        ↓
read resolver + enrolled factor hints
        ↓
show masked enrolled factor
        ↓
verifyPhoneNumber(
  multiFactorSession: resolver.session,
  multiFactorInfo: selected hint
)
        ↓
user enters SMS code
        ↓
create PhoneAuthCredential
        ↓
resolver.resolveSignIn(...)
        ↓
authentication complete
```

Support multiple enrolled factors in the data/control flow even if the initial UI only enrolls one. Firebase/Identity Platform supports multiple second-factor enrollments; do not write code that assumes array index zero is permanently the only possible factor.

---

## AGENT TASK 5M — Centralized authentication/access state machine

Do not scatter authentication checks through screens.

Create one centralized auth/access state provider with states conceptually equivalent to:

```text
signedOut
emailVerificationRequired
mfaEnrollmentRequired
mfaChallengeInProgress
authenticatedReady
accountRecoveryRequired
deletionScheduled
```

Screen names and nesting for these gates are in `docs/page-navigation.md`. This section only defines the access rules.

Routing policy:

```text
signed out
    -> auth routes

signed in + email unverified
    -> verify email

verified + no enrolled second factor
    -> mandatory MFA enrollment

MFA challenge unresolved
    -> MFA challenge

deletion scheduled
    -> reactivate only

verified + MFA enrolled/authenticated + onboarding incomplete
    -> onboarding

verified + MFA enrolled/authenticated + onboarding complete
    -> home
```

Do not permit route deep-linking to bypass these gates.

---

## AGENT TASK 5N — Server-authoritative MFA enrollment marker for pre-onboarding gating

Create a minimal server-authoritative security state for each user, for example:

```text
users/{uid}/security/authState
```

or an equivalent server-controlled field/document containing:

```json
{
  "emailVerified": true,
  "mfaEnrollmentConfirmed": true,
  "mfaEnrollmentConfirmedAt": "server timestamp"
}
```

This is **not** the source of truth for Firebase Authentication factors. Firebase Auth remains authoritative.

Its purpose is to make application/security-rule gating deterministic before any sensitive Veteran workspace data exists.

A trusted callable/server function must:

1. verify the caller's Firebase user;
2. retrieve/inspect the user's Firebase Auth record via Admin SDK;
3. confirm verified email;
4. confirm at least one MFA factor is currently enrolled;
5. write the server-authoritative app security marker;
6. return success.

The client must not be able to set `mfaEnrollmentConfirmed = true` directly.

If the product later exposes MFA factor removal, the removal workflow must update/clear this marker and force the user through the required security state before continued sensitive access.

---

## AGENT TASK 5O — Firestore/Storage gating before sensitive onboarding data

Security Rules for Veteran-private collections should require at minimum:

```text
authenticated user
+ request.auth.token.email_verified == true
+ path uid == request.auth.uid
+ trusted app-level MFA enrollment marker == true
```

The exact rule implementation must avoid circular access patterns and must be tested against the actual collection layout.

The initial bootstrap/security document itself needs narrowly scoped rules so a newly verified user can complete MFA enrollment confirmation without already having access to all private collections.

Cloud Functions/Admin SDK operations bypass Firestore rules, so every sensitive callable function must independently enforce:

- authenticated caller;
- expected owner uid;
- verified email;
- confirmed MFA enrollment/security state;
- App Check when enforcement is enabled;
- any operation-specific authorization.

---

## AGENT TASK 5P — MFA recovery and factor-management UX

Identity Platform does not magically solve user recovery if a person permanently loses access to their only second factor. The initial application must at least provide:

- Security screen showing enrolled factor(s) in masked form;
- add/replace factor flow requiring recent re-authentication;
- clear warning before removing the only factor;
- no self-service path that leaves the account with zero factors while retaining sensitive app access;
- support-contact/recovery placeholder with an audited administrative recovery process to be designed before public production launch.

Password reset does not bypass MFA; do not describe it to users as MFA recovery.

For MVP development, one enrolled SMS factor is sufficient to test the complete application flow. Before broad production release, define the operational account-recovery procedure and consider offering/encouraging a backup factor.

---

## OWNER ACTION GATE 5Q — DEV end-to-end auth acceptance test

After agent implementation, the owner performs the following against the real DEV Firebase project using a configured fictional test number:

1. Create a new account with email/password.
2. Confirm the app prevents onboarding before email verification.
3. Verify the email.
4. Confirm the app routes to MFA enrollment, not onboarding.
5. Enter the configured fictional test phone number.
6. Enter its configured test verification code.
7. Confirm MFA enrollment succeeds.
8. Confirm onboarding now becomes available.
9. Sign out.
10. Sign back in with email/password.
11. Confirm the second-factor challenge occurs.
12. Enter the test MFA code.
13. Confirm sign-in completes and the Veteran workspace loads.
14. Attempt to bypass MFA using deep links/navigation and confirm access is denied.
15. Confirm no real SMS was sent for the fictional number.

**Owner confirmation required:**

```text
DEV mandatory email verification + SMS MFA acceptance test: PASS
```

The agent must not mark Phase 5 complete until this test passes.

---

## Production authentication release gate

Before the first real production release, repeat platform verification against production:

- production Email/Password enabled;
- production Identity Platform enabled;
- production SMS MFA enabled;
- production SMS region policy reviewed;
- production Android **release** SHA-256 registered;
- production iOS APNs authentication configured;
- production web domain authorized if web is released;
- at least one real-number MFA test performed on each released native platform;
- any temporary production fictional/reviewer phone numbers documented and removed/rotated after review if no longer needed;
- account-recovery/support procedure documented.

Do not test production authentication using actual Veteran claim data.

## Definition of done — Phase 5

Phase 5 is complete only when:

- email/password authentication works against DEV;
- email verification is mandatory;
- SMS MFA is enabled in Firebase Identity Platform;
- DEV fictional test numbers are configured manually by the owner;
- platform verification configuration is complete for every platform being claimed as supported in the milestone;
- MFA enrollment works;
- MFA sign-in challenge works;
- route guards prevent bypass;
- sensitive case/onboarding data is gated until MFA enrollment is confirmed;
- owner acceptance test passes.

# 13. Phase 6 — App Check

Use Firebase App Check before exposing expensive/sensitive production operations.

Official Flutter guide:

https://firebase.google.com/docs/app-check/flutter/default-providers

Default providers currently include:

- Android -> Play Integrity;
- Apple -> DeviceCheck or App Attest;
- Web -> reCAPTCHA provider.

## Development behavior

Because local builds use the real dev project, configure development builds in a way that developers can use without disabling App Check globally.

Use App Check debug tokens/providers for development where required by the platform.

Do **not** use debug providers in production builds.

## Rollout approach

1. integrate App Check SDK;
2. register apps/providers in Firebase Console;
3. run dev and production test builds;
4. monitor App Check metrics;
5. enable enforcement only after valid app traffic is confirmed.

Do not turn on enforcement before supported clients are deployed.

---

# 14. Firestore security model

Use `rules_version = '2';` because collection-group queries may be used.

All Veteran-specific data lives beneath:

```text
/users/{uid}/...
```

The primary rule concept is:

```text
request.auth != null
&& request.auth.uid == uid
```

However, do not expose every server-controlled field to client writes.

## 14.1 Client-owned vs server-owned fields

Client may generally write user-entered data such as:

- profile fields;
- questionnaire responses;
- notes;
- user preferences;
- manual tasks;
- Veteran-reported symptoms/events.

Server-only or server-authoritative fields include:

- VA submission receipts;
- verified VA API statuses;
- document processing results;
- system-calculated deadlines;
- AI extraction provenance metadata;
- processing job state;
- admin/audit fields;
- rule-sync metadata.

Use callable functions for operations that mutate server-authoritative state.

## 14.2 Server SDK warning

Firebase Admin/server SDKs bypass Firestore Security Rules and use IAM. Therefore, Functions code must enforce authorization itself at the function boundary.

Never assume Firestore Rules protect Admin SDK writes.

Firestore security overview:

https://firebase.google.com/docs/firestore/security/overview

## 14.3 Storage rules

All user files must use a user-owned path:

```text
/users/{uid}/documents/{documentId}/...
```

Storage rules must verify:

- authenticated user;
- path uid == auth uid;
- allowed content types;
- maximum upload size appropriate to the endpoint;
- object metadata where useful.

Storage rules reference:

https://firebase.google.com/docs/storage/security/rules-conditions

Do not make medical files publicly readable and do not persist public download URLs in Firestore.

Prefer authenticated SDK retrieval/signed short-lived server URLs where a backend process needs access.

---

# 15. Core Firestore hierarchy

This hierarchy is the initial contract. Agents should not casually rename these collections once production data exists.

```text
/users/{uid}
    /settings/{id}
    /servicePeriods/{servicePeriodId}
    /deployments/{deploymentId}
    /exposures/{exposureId}
    /conditions/{conditionId}
    /claimIssues/{claimIssueId}
    /intentsToFile/{intentId}
    /submissions/{submissionId}
    /submissionIssues/{submissionIssueId}
    /decisions/{decisionId}
    /decisionIssues/{decisionIssueId}
    /questionnaires/{questionnaireId}
        /responses/{responseId}
    /documents/{documentId}
        /facts/{factId}
        /chunks/{chunkId}
    /evidenceLinks/{evidenceLinkId}
    /exams/{examId}
    /tasks/{taskId}
    /timelineEvents/{eventId}
    /chats/{chatId}
        /messages/{messageId}
    /processingJobs/{jobId}
    /notifications/{notificationId}
    /nexusPackets/{packetId}
    /auditEvents/{eventId}
```

Global/reference collections:

```text
/appConfig/{id}
/questionnaireDefinitions/{definitionId}
/questionDefinitions/{questionId}
/vaForms/{formId}
/vaConditions/{conditionId}
/vaDbqs/{dbqId}
/vaExposureRules/{ruleId}
/vaPresumptions/{ruleId}
/vaKnowledgeSources/{sourceId}
/vaRuleVersions/{ruleVersionId}
/vaFormRevisions/{formRevisionId}
/vaFormMappings/{mappingId}
/vaFormCatalogs/{catalogId}
/appReleases/{releaseId}
/vaFormSafetyPolicies/{formRevisionId}
```

Global/reference collections are normally read-only from the client and written by trusted administrative tooling or backend functions. VA form templates, mappings, catalogs, release manifests, and safety policies follow the stricter manual release process defined in Section 37; do not treat them as automatically synchronized runtime configuration.

---

# 16. Common Firestore conventions

Every mutable domain document should generally include:

```text
id
createdAt
updatedAt
schemaVersion
```

When relevant:

```text
createdBy
updatedBy
sourceType
sourceId
```

Use server timestamps for authoritative create/update timestamps.

## 16.1 IDs

Prefer Firestore-generated IDs for mutable user data unless an externally stable natural identifier is required.

Reference data can use deterministic IDs, for example:

```text
vaForms/21-526EZ
questionnaireDefinitions/lumbar-spine-v1
```

## 16.2 Soft deletion

For legally/audit-relevant case entities, prefer:

```text
status = archived
archivedAt
```

over silent hard deletion from normal UI operations.

User privacy/deletion workflows are a separate controlled process and may perform true deletion.

## 16.3 Dates

Use Firestore timestamps for actual moments.

For date-only values where time is semantically meaningless (for example a service start date), store a canonical ISO date string:

```text
YYYY-MM-DD
```

Do not convert a date-only value into local midnight and then risk timezone drift.

---

# 17. `users/{uid}` schema

Purpose: minimal account-level profile and onboarding state.

Recommended fields:

```json
{
  "displayName": "...",
  "email": "...",
  "emailVerified": true,
  "onboardingStatus": "notStarted|inProgress|complete",
  "onboardingStep": "serviceHistory",
  "timezone": "America/Chicago",
  "preferredLanguage": "en",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "schemaVersion": 1
}
```

Do not use the root user document as a dumping ground for case data.

Avoid storing full SSNs unless/until a concrete VA integration absolutely requires them. If highly sensitive identifiers become required, put them in a dedicated restricted document/collection and encrypt them at the application layer before persistence.

---

# 18. Service-history model

## `users/{uid}/servicePeriods/{id}`

```json
{
  "branch": "marineCorps",
  "component": "active|reserve|guard",
  "startDate": "YYYY-MM-DD",
  "endDate": "YYYY-MM-DD|null",
  "characterOfService": "...|unknown",
  "mosCodes": ["..."],
  "primaryOccupationText": "...",
  "notes": "...",
  "sourceType": "veteranReported|documentExtracted|vaApiImported",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "schemaVersion": 1
}
```

## `deployments/{id}`

```json
{
  "servicePeriodId": "...",
  "country": "Afghanistan",
  "locationText": "...",
  "installation": "...",
  "startDate": "YYYY-MM-DD",
  "endDate": "YYYY-MM-DD",
  "combatRelated": true,
  "sourceType": "veteranReported",
  "sourceDocumentId": null,
  "notes": "..."
}
```

## `exposures/{id}`

```json
{
  "type": "burnPit|herbicide|noise|radiation|solvent|asbestos|other",
  "ruleId": "optional-global-rule-reference",
  "deploymentId": "optional",
  "servicePeriodId": "optional",
  "status": "reported|systemSuggested|confirmed|dismissed",
  "description": "...",
  "firstExposureDate": "YYYY-MM-DD|null",
  "lastExposureDate": "YYYY-MM-DD|null",
  "sourceType": "veteranReported|systemCalculated|documentExtracted",
  "confidence": 0.0,
  "needsUserConfirmation": true
}
```

A `systemSuggested` exposure never becomes `confirmed` simply because the AI suggested it. Confirmation requires a deterministic rule match and/or user/document evidence according to product logic.

---

# 19. Conditions vs Claim Issues

These are separate concepts.

## Condition

A health condition/symptom cluster known to the application.

Examples:

- chronic sinusitis;
- lumbar condition;
- migraines;
- left lower-extremity neurological symptoms;
- tinnitus.

A condition can exist without ever being claimed.

## Claim Issue

A condition being evaluated or pursued within the VA disability-claims process.

A Claim Issue persists across multiple submissions and decision-review events.

Example:

```text
Lumbar condition
 -> original claim
 -> denial
 -> supplemental claim
 -> denial
 -> HLR
 -> grant
 -> later increased-rating claim
```

This remains one conceptual Claim Issue history.

---

# 20. `conditions/{conditionId}`

```json
{
  "displayName": "Lumbar spine condition",
  "normalizedConditionId": "optional-va-condition-reference",
  "bodySystem": "musculoskeletal",
  "status": "potential|reported|diagnosed|resolved|dismissed",
  "diagnosisText": "Lumbar degenerative disc disease",
  "diagnosed": true,
  "diagnosisDate": "YYYY-MM-DD|null",
  "firstSymptomDate": "YYYY-MM-DD|null",
  "current": true,
  "discoverySource": "questionnaire|document|assistant|manual|vaImport",
  "sourceQuestionnaireId": "...|null",
  "notes": "...",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "schemaVersion": 1
}
```

Do not store hundreds of symptom events directly as an array here. Those belong in questionnaire responses, evidence facts, or timeline events.

---

# 21. `claimIssues/{claimIssueId}`

Core fields:

```json
{
  "conditionId": "...",
  "displayName": "Lumbar spine condition",
  "caseIds": ["case_123"],
  "activeCaseId": "case_123|null",
  "status": "potential|evaluating|preparing|readyToFile|submitted|vaDevelopment|examPending|rating|decided|reviewPreparing|reviewPending|closed|archived",
  "claimPurpose": "initial|secondary|increase|reopenSupplemental|other",
  "activeTheoryTypes": ["direct"],
  "serviceConnectionStatus": "unknown|serviceConnected|notServiceConnected|mixed",
  "currentRatingPercent": 20,
  "effectiveDate": "YYYY-MM-DD|null",
  "readinessPercent": 72,
  "questionnaireCompletionPercent": 90,
  "evidenceStatus": "insufficient|partial|ready|needsReview",
  "nextActionSummary": "Upload private orthopedic records",
  "priority": "critical|high|normal|low",
  "latestDecisionId": "...|null",
  "latestSubmissionId": "...|null",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "schemaVersion": 1
}
```

## Service-connection theories

Initially store compact theory summaries on the Claim Issue or use a nested array of small theory objects if only a handful exist.

If theory data becomes independently complex, promote to a subcollection later.

Suggested theory shape:

```json
{
  "id": "theory_direct_1",
  "type": "direct|secondary|aggravation|presumptive|increase",
  "status": "candidate|active|dismissed",
  "relatedClaimIssueId": null,
  "presumptionRuleId": null,
  "summary": "Possible direct relationship to documented 2011 injury",
  "sourceType": "systemCalculated",
  "needsUserConfirmation": false
}
```

Do not state medical causation as fact merely because a secondary relationship is plausible.

---

# 22. Intents to File

## `intentsToFile/{intentId}`

```json
{
  "benefitType": "compensation",
  "status": "draft|submitted|active|used|expired|cancelled",
  "preparedAt": "Timestamp|null",
  "submittedAt": "Timestamp|null",
  "expirationAt": "Timestamp|null",
  "submissionMethod": "vaApi|vaGov|phone|paper|manualImported",
  "vaConfirmationId": "...|null",
  "sourceType": "veteranReported|vaApiImported|systemCalculated",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

The application may calculate expiration from an authoritative submitted date and current rule configuration, but must preserve the exact underlying dates/rule version used to derive the deadline.

---

# 23. Submissions

## `submissions/{submissionId}`

Represents a VA-facing transaction/package, not a lifelong condition.

```json
{
  "caseId": "case_123",
  "type": "disabilityClaim|supplementalClaim|higherLevelReview|boardAppeal|evidenceOnly|other",
  "status": "draft|readyForReview|awaitingConfirmation|submitting|submitted|submissionFailed|accepted|closed",
  "formIds": ["21-526EZ"],
  "submissionMethod": "vaApi|vaGovHandoff|generatedPackage|mail|manualImported",
  "preparedAt": "Timestamp|null",
  "submittedAt": "Timestamp|null",
  "vaClaimId": "...|null",
  "confirmationNumber": "...|null",
  "payloadSnapshotDocumentId": "...|null",
  "ruleVersionIds": ["..."],
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## `submissionIssues/{id}`

```json
{
  "submissionId": "...",
  "claimIssueId": "...",
  "claimIssueDisplayName": "Lumbar spine condition",
  "requestedAction": "serviceConnection|increase|review",
  "status": "included|submitted|withdrawn|resolved",
  "createdAt": "Timestamp"
}
```

This top-level per-user subcollection is intentionally query-friendly.

---

# 24. Decisions

## `decisions/{decisionId}`

```json
{
  "caseId": "case_123",
  "decisionDate": "YYYY-MM-DD",
  "receivedDate": "YYYY-MM-DD|null",
  "sourceDocumentId": "...",
  "sourceType": "documentExtracted|manual|vaApiImported",
  "status": "draftExtraction|needsReview|confirmed",
  "benefitType": "compensation",
  "overallSummary": "...",
  "reviewDeadline": "Timestamp|null",
  "deadlineRuleVersionId": "...|null",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## `decisionIssues/{decisionIssueId}`

```json
{
  "decisionId": "...",
  "claimIssueId": "...|null",
  "displayName": "Lumbar spine condition",
  "outcome": "granted|denied|deferred|increased|continued|reduced|other",
  "ratingPercent": 20,
  "effectiveDate": "YYYY-MM-DD|null",
  "favorableFindings": [
    {
      "text": "...",
      "sourceDocumentId": "...",
      "page": 4,
      "sourceSpan": "optional location metadata"
    }
  ],
  "reasons": [
    {
      "text": "...",
      "category": "nexus|diagnosis|inServiceEvent|severity|other",
      "sourceDocumentId": "...",
      "page": 5
    }
  ],
  "evidenceConsidered": ["..."],
  "extractionConfidence": 0.94,
  "userConfirmed": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Never treat an AI-parsed decision as final until the extraction has passed validation and/or user confirmation for consequential workflows.

---

# 25. Questionnaires

Questionnaire definitions are global/versioned. Questionnaire instances and responses are user-specific.

## `questionnaireDefinitions/{definitionId}`

```json
{
  "name": "Lumbar Spine Detailed Intake",
  "type": "conditionDetail",
  "version": 3,
  "status": "active|retired|draft",
  "conditionTags": ["lumbar", "musculoskeletal"],
  "entryQuestionId": "lumbar_onset",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## `questionDefinitions/{questionId}`

Keep questions separately addressable so branching references remain stable.

```json
{
  "definitionId": "lumbar-spine-v3",
  "key": "flare_frequency",
  "prompt": "How often do significant flare-ups occur?",
  "helpText": "...",
  "answerType": "singleChoice|multiChoice|text|longText|date|number|boolean|bodyLocation|severityScale",
  "options": [
    {"value":"never","label":"Never"},
    {"value":"yearly","label":"About once a year"}
  ],
  "required": false,
  "order": 120,
  "section": "flareUps",
  "branchRules": [],
  "tags": ["functionalImpact"]
}
```

## `users/{uid}/questionnaires/{questionnaireId}`

```json
{
  "definitionId": "lumbar-spine-v3",
  "definitionVersion": 3,
  "claimIssueId": "...",
  "conditionId": "...",
  "status": "notStarted|inProgress|complete|abandoned",
  "progressPercent": 72,
  "currentQuestionId": "...",
  "startedAt": "Timestamp",
  "completedAt": "Timestamp|null",
  "updatedAt": "Timestamp"
}
```

## `questionnaires/{questionnaireId}/responses/{responseId}`

```json
{
  "questionId": "flare_frequency",
  "value": "once_or_twice_yearly",
  "displayValue": "Once or twice a year",
  "sourceType": "veteranReported",
  "answeredVia": "ui|assistant",
  "answeredAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

The UI questionnaire and conversational agent must write the same response model.

---

# 26. Universal condition discovery questionnaire

The first major guided workflow after service history is a comprehensive but progressive symptom/condition discovery process.

It must be **symptom-oriented**, not diagnostic-code-oriented.

Top-level sections should include at minimum:

- head/neurological;
- eyes/vision;
- hearing/ears/tinnitus/vestibular;
- nose/sinus/ENT;
- respiratory;
- sleep;
- cardiovascular;
- gastrointestinal;
- genitourinary;
- endocrine/metabolic;
- skin/scars;
- musculoskeletal by body region;
- peripheral nerves/numbness/tingling;
- mental health;
- dental/oral where relevant;
- reproductive conditions where relevant;
- residuals of surgeries/injuries;
- scars/disfigurement;
- other symptoms not captured above.

The questionnaire should begin broad and branch deeper only when the user answers positively.

Example:

```text
Do you have recurring back pain/stiffness/limited movement?
    No -> continue
    Yes -> create/update potential condition -> detailed back questions

Does pain travel down either leg?
    No -> continue
    Yes -> ask left/right/both, numbness, tingling, weakness
           -> create potential neurological condition for review
```

Do not automatically submit every discovered condition as a claim.

Discovery creates `conditions` with status `potential` and optionally `claimIssues` with status `potential/evaluating` only after user review.

---

# 27. Evidence/document model

## `documents/{documentId}`

```json
{
  "name": "2025 Orthopedic Records.pdf",
  "originalFileName": "ortho.pdf",
  "documentType": "serviceTreatmentRecord|privateMedicalRecord|vaMedicalRecord|decisionLetter|dbq|cpExam|personalStatement|buddyStatement|dd214|personnelRecord|imaging|lab|nexusOpinion|vaCorrespondence|other",
  "contentType": "application/pdf",
  "sizeBytes": 1234567,
  "storagePath": "users/<uid>/documents/<documentId>/original.pdf",
  "uploadStatus": "uploading|uploaded|failed",
  "processingStatus": "notStarted|queued|processing|needsReview|complete|failed",
  "pageCount": 14,
  "documentDate": "YYYY-MM-DD|null",
  "providerName": "...|null",
  "facilityName": "...|null",
  "tags": ["back", "orthopedics"],
  "sha256": "...|null",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## Storage object layout

```text
users/{uid}/documents/{documentId}/original.<ext>
users/{uid}/documents/{documentId}/derived/text.json
users/{uid}/documents/{documentId}/derived/...   # only if needed
```

Do not create publicly accessible download links for user medical documents.

---

# 28. Document facts

## `documents/{documentId}/facts/{factId}`

A fact is a structured statement extracted from a document.

```json
{
  "factType": "diagnosis|symptom|serviceEvent|treatment|medication|imagingFinding|functionalImpact|medicalOpinion|decisionFinding|other",
  "normalizedConditionId": "...|null",
  "conditionText": "Lumbar degenerative disc disease",
  "claimIssueIds": ["..."],
  "factText": "Patient reports low-back pain after lifting injury",
  "eventDate": "YYYY-MM-DD|null",
  "page": 7,
  "sourceStart": 1200,
  "sourceEnd": 1330,
  "confidence": 0.96,
  "sourceType": "documentExtracted",
  "reviewStatus": "unreviewed|confirmed|corrected|rejected",
  "createdAt": "Timestamp"
}
```

User correction must preserve the original extraction rather than silently overwrite it. Store correction metadata or a corrected fact with linkage.

---

# 29. Evidence links

`evidenceLinks` associates an evidence source/fact with a Claim Issue and a claim element.

## `evidenceLinks/{id}`

```json
{
  "claimIssueId": "...",
  "documentId": "...|null",
  "factId": "...|null",
  "questionnaireId": "...|null",
  "responseId": "...|null",
  "evidenceType": "currentDiagnosis|inServiceEvent|nexus|severity|functionalImpact|continuity|qualifyingService|presumption|newAndRelevant|other",
  "relationship": "supports|conflicts|neutral",
  "summary": "2011 STR documents lifting injury",
  "sourceType": "documentExtracted|veteranReported|systemCalculated|medicalOpinion",
  "confidence": 0.98,
  "userConfirmed": true,
  "createdAt": "Timestamp"
}
```

This collection drives the Evidence Matrix.

---

# 30. Evidence Matrix

Each Claim Issue should expose a deterministic evidence-readiness view.

Example direct-service matrix:

```text
Current disability       -> supporting evidence
In-service event         -> supporting evidence
Relationship/nexus       -> supporting evidence
Current severity         -> supporting evidence
Functional impact        -> supporting evidence
```

Example presumptive matrix:

```text
Current diagnosis        -> supporting evidence
Qualifying service       -> service/deployment evidence
Applicable presumption   -> versioned VA rule
Current severity         -> supporting evidence
```

Readiness is not a predicted chance of winning.

Do **not** display:

```text
87% chance of approval
```

A readiness percentage, if used, must mean workflow/evidence completeness only and be explainable by deterministic requirements.

---

# 31. Exams

## `exams/{examId}`

```json
{
  "caseId": "case_123|null",
  "type": "cpExam|aceReview|other",
  "status": "anticipated|scheduled|completed|cancelled|missed|unknown",
  "scheduledAt": "Timestamp|null",
  "timezone": "America/Chicago",
  "locationName": "...|null",
  "address": "...|null",
  "providerOrContractor": "...|null",
  "claimIssueIds": ["..."],
  "dbqIds": ["..."],
  "appointmentSource": "manual",
  "prepQuestionnaireId": "...|null",
  "prepCompletionPercent": 65,
  "postExamNotesCompleted": false,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

C&P preparation must reuse existing Veteran responses rather than repeatedly asking the same questions. MVP exam creation is manual; future import/source values may be added only after a reliable integration is implemented.

---

# 32. Tasks and next actions

## `tasks/{taskId}`

```json
{
  "type": "uploadEvidence|completeQuestionnaire|prepareExam|reviewDecision|submitClaim|reviewSubmission|followUp|other",
  "title": "Upload private orthopedic records",
  "description": "...",
  "status": "open|inProgress|complete|dismissed",
  "priority": "critical|high|normal|low",
  "dueAt": "Timestamp|null",
  "caseId": "...|null",
  "claimIssueId": "...|null",
  "claimIssueDisplayName": "...|null",
  "submissionId": "...|null",
  "examId": "...|null",
  "decisionId": "...|null",
  "sourceType": "systemCalculated|userCreated|agentCreated|vaImported",
  "ruleVersionId": "...|null",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Home queries primarily open tasks ordered by priority/due date.

The deterministic Next Action Engine creates/updates system tasks based on case state.

---

# 33. Timeline events

## `timelineEvents/{eventId}`

```json
{
  "eventType": "serviceStart|deployment|injury|diagnosis|treatment|claimSubmitted|examScheduled|examCompleted|decisionReceived|reviewSubmitted|other",
  "occurredAt": "Timestamp|null",
  "occurredDate": "YYYY-MM-DD|null",
  "title": "Back injury documented",
  "description": "...",
  "caseId": "...|null",
  "claimIssueIds": ["..."],
  "conditionIds": ["..."],
  "sourceType": "documentExtracted|veteranReported|vaApiImported|systemCalculated",
  "sourceDocumentId": "...|null",
  "sourceFactId": "...|null",
  "confidence": 1.0,
  "createdAt": "Timestamp"
}
```

The global Veteran timeline is a projection of these events.

---

# 34. Chats/messages

## `chats/{chatId}`

```json
{
  "title": "Back claim",
  "status": "active|archived",
  "contextType": "general|claimIssue|decision|document|exam",
  "contextId": "...|null",
  "lastMessageAt": "Timestamp",
  "createdAt": "Timestamp"
}
```

## `chats/{chatId}/messages/{messageId}`

```json
{
  "role": "user|assistant|systemEvent",
  "content": "...",
  "status": "streaming|complete|failed",
  "toolEventIds": ["..."],
  "createdAt": "Timestamp"
}
```

Do not treat the chat transcript as the primary long-term memory of the Veteran.

Important facts from conversation must be explicitly written through structured tools after confirmation.

---

# 35. Processing jobs

## `processingJobs/{jobId}`

```json
{
  "type": "documentClassification|decisionAnalysis|medicalRecordExtraction|embedding|knowledgeSync|vaSync",
  "status": "queued|processing|needsReview|complete|failed|cancelled",
  "progress": 0.63,
  "documentId": "...|null",
  "startedAt": "Timestamp|null",
  "completedAt": "Timestamp|null",
  "errorCode": "...|null",
  "safeErrorMessage": "...|null",
  "attempt": 1,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Flutter may listen to these documents in real time for upload/processing UX.

---

# 36. Development reset and seed tooling

This project intentionally uses the live dev Firebase project rather than the local Emulator Suite.

Therefore reliable reset tooling is mandatory.

## Required scripts

```bash
npm run dev:verify
npm run dev:reset-user -- --uid <uid> --confirm-dev-reset
npm run dev:reset
npm run dev:seed
npm run dev:reset-and-seed
```

Scripts live in `/scripts` and use the Firebase Admin SDK/Google Cloud APIs with developer credentials.

Recommended local authentication is Application Default Credentials rather than committed service-account JSON files.

If Google Cloud CLI is used:

```bash
gcloud auth application-default login
```

No credential JSON file should be committed to the repo.

## `dev:verify`

Must print:

- resolved Google/Firebase project ID;
- expected dev project ID;
- authenticated caller if available;
- whether destructive operations are permitted.

## `dev:reset`

Must:

1. check project ID exactly equals configured dev project ID;
2. require explicit argument/environment confirmation;
3. refuse to execute against prod even if caller requests it;
4. recursively delete user application collections;
5. delete dev user Storage objects;
6. optionally delete test Auth users only when requested;
7. preserve global config/reference collections unless `--include-reference-data` is explicitly passed;
8. emit a final summary.

Example usage:

```bash
npm run dev:reset -- --confirm-dev-reset
```

If project ID contains `prod`, or does not exactly equal the known dev project ID, abort.

## `dev:seed`

Create deterministic fake test scenarios. At minimum:

### Scenario A — brand new Veteran

- service history only;
- no claims;
- onboarding incomplete.

### Scenario B — active initial claim

- several conditions;
- evidence matrix partly complete;
- upcoming C&P.

### Scenario C — denied issue

- decision letter extraction;
- favorable finding;
- nexus-related denial;
- review deadline.

### Scenario D — mixed decision

One submission with:

- grant;
- denial;
- deferred issue.

Seed identifiers should be predictable so automated integration tests can reference them.

---

---

# 37. VA Form Template, Autofill, Qualification, and Release Management

This section is **normative**. Engineering agents must not simplify this into “always fetch the latest PDF from VA.” The app must deliberately preserve compatibility between an app release and the exact VA PDF/form mapping that was tested with that release.

## 37.0 PDF runtime and library

Official VA PDFs are filled in JavaScript Cloud Functions with `pdf-lib`. Flutter downloads and displays the finished file. It does not fill the official template.

`pdf-lib` is used to:

- list AcroForm fields;
- set text and checkbox values;
- flatten;
- merge the package;
- count pages on an uploaded PDF.

Install it with `npm install pdf-lib` and no version pin when form work starts. That selects the latest stable major.

If inspection finds an XFA PDF, that revision stays unqualified. Do not add an XFA library in this pass.

Uploaded medical files are processed once. `pdf-lib` supplies page count and structure. Text and facts come from Gemini on Vertex through `@google-cloud/vertexai`. A PDF with no text layer is sent to Gemini as a file. Google Document AI is not a day-one dependency. `sharp` normalizes HEIC and JPEG on that worker. Jobs that exceed a normal function use Cloud Run with the same libraries.

`pdfrx` in the Flutter app is only for review. Filling stays in Functions.

## 37.1 Goals

The form subsystem must accomplish all of the following:

1. obtain official VA PDF forms from an authoritative VA source;
2. retain immutable copies of every VA form revision that the product has evaluated or supported;
3. prevent clients from modifying authoritative templates;
4. inspect the actual fillable PDF fields before supporting a revision;
5. map canonical application data to the PDF fields for that exact revision;
6. generate user-specific completed PDFs server-side;
7. validate generated PDFs programmatically and through golden tests;
8. require explicit owner approval before a revision becomes supported;
9. bind supported form revisions to an immutable **form catalog version**;
10. bind each production application release/build to one approved form catalog;
11. guarantee that older app releases do not silently see newer forms;
12. allow production testing of a new app/form catalog without changing behavior for existing users;
13. block submission and require an application update if an older form revision later becomes unsafe, invalid, or no longer accepted;
14. preserve enough provenance to reproduce exactly what form and mapping generated any submitted package.

## 37.2 Non-goal: “latest form automatically wins”

Do **not** implement any runtime behavior equivalent to:

```text
VA publishes form revision
        ↓
background sync notices revision
        ↓
current revision pointer changes
        ↓
all existing clients begin using new PDF
```

That is explicitly prohibited.

The VA may publish a PDF that appears visually similar but changes internal field names, field types, checkbox export values, JavaScript, page layout, field limits, signature behavior, or required information. A newly published revision is unknown/unqualified until explicitly tested.

## 37.3 Authoritative discovery source

Use the official VA Forms API / official VA form repository as the authoritative discovery source for supported forms. Do not scrape random third-party copies.

VA form discovery is **owner-triggered**, not an automatic production sync.

Required administrative command:

```bash
npm run va:forms:discover
```

This command:

1. calls the authoritative VA forms source;
2. fetches metadata for the configured forms of interest;
3. compares the VA-reported revision/checksum/URL/status to the revisions already known to the application;
4. prints a deterministic report;
5. performs **no activation**;
6. must not change any app release or form catalog;
7. must not overwrite any existing template.

Example output:

```text
VA FORM DISCOVERY

21-526EZ
Known production revision: 2026-01
VA source revision:         2026-10
Status: NEW REVISION DETECTED
Action: owner may run va:forms:import --form 21-526EZ --revision 2026-10

20-0995
Known production revision: 2025-XX
VA source revision:         2025-XX
Status: unchanged
```

The owner decides whether and when to proceed.

## 37.4 Controlled form import

Required command:

```bash
npm run va:forms:import -- --form 21-526EZ --revision <revision>
```

Import must:

1. resolve the exact PDF from the official VA source;
2. download the official PDF;
3. calculate SHA-256 locally;
4. compare against any authoritative checksum supplied by VA when available;
5. reject the import if checksum verification fails;
6. inspect basic PDF properties;
7. store the original PDF in the controlled reference bucket/path;
8. create immutable revision metadata in Firestore;
9. set status to `imported` or `needsInspection`;
10. never mark the form production-ready;
11. never modify an existing imported revision in place.

Recommended Storage layout:

```text
reference/va-forms/
    21-526EZ/
        2026-01/
            original.pdf
            field-inventory.json
            inspection-report.json
        2026-10/
            original.pdf
            field-inventory.json
            inspection-report.json
```

If VA publishes different binaries under the same nominal revision, do not overwrite the old file. Treat the checksum as part of the artifact identity and require owner review.

## 37.5 Reference-template Storage security

The authoritative PDF template area is backend-only.

Client Storage rules must deny direct client writes to:

```text
/reference/va-forms/**
```

Prefer denying direct client reads as well unless a concrete UI use case requires them. Cloud Functions / administrative tooling access the templates through privileged service credentials.

A Veteran-specific generated form is stored separately, for example:

```text
/users/{uid}/generatedForms/{generatedFormId}/filled.pdf
/users/{uid}/generatedForms/{generatedFormId}/filled-flattened.pdf
```

Those generated artifacts may be made readable by the owning Veteran under normal Storage authorization rules.

## 37.6 Form revision metadata

Use a dedicated immutable document per imported revision rather than mutating `vaForms/{formNumber}` into whatever is newest.

Recommended ID:

```text
vaFormRevisions/21-526EZ__2026-01__<shortSha>
```

Example:

```json
{
  "formNumber": "21-526EZ",
  "title": "Application for Disability Compensation and Related Compensation Benefits",
  "revision": "2026-01",
  "templateSha256": "...",
  "sourceUrl": "...",
  "storagePath": "reference/va-forms/21-526EZ/2026-01/original.pdf",
  "source": "vaFormsApi",
  "isFillable": true,
  "pdfTechnology": "acroForm|xfa|static|unknown",
  "pageCount": 0,
  "status": "imported|needsInspection|needsMapping|qualified|cataloged|retired|rejected",
  "discoveredAt": "Timestamp",
  "importedAt": "Timestamp",
  "qualifiedAt": "Timestamp|null",
  "qualifiedBy": "uid|null",
  "notes": "...|null"
}
```

Do not use `status=qualified` merely because the PDF is fillable.

## 37.7 Qualification means exact compatibility testing

A VA form revision is **qualified** only after the product has proven that it can safely populate the exact PDF and that the app collects the information required by that revision.

Qualification includes at minimum:

1. enumerate every fillable field;
2. detect the PDF form technology;
3. compare fields against the previously supported revision;
4. identify added/removed/renamed fields;
5. identify changed field types;
6. identify text limits and multiline behavior;
7. identify checkbox/radio export values;
8. identify signature fields/behavior;
9. identify calculated fields or embedded PDF JavaScript that matters;
10. determine whether the app currently collects all required data;
11. update app questionnaires/domain fields when needed;
12. create/update a mapping for this exact revision;
13. generate a fully populated golden test PDF;
14. reopen the generated PDF and verify round-trip field values where technically possible;
15. visually inspect the output for clipping, overflow, missing values, incorrect checkboxes, page/layout problems, and signature problems;
16. run automated regression tests;
17. record explicit owner approval.

A form revision may remain imported indefinitely without becoming qualified.

## 37.8 Form inspection tooling

Required command:

```bash
npm run va:forms:inspect -- --form 21-526EZ --revision <revision>
```

The command should emit a machine-readable inventory and a human-readable diff against the selected prior supported revision.

Example:

```text
21-526EZ 2026-10

Previous fillable fields: 184
New fillable fields:      187

Added:
+ ToxicExposureQuestion
+ ExposureLocation
+ ExposureStartDate

Removed:
none

Changed:
ClaimCondition3: Text -> MultilineText

Existing mapping coverage:
181 / 187

RESULT: NOT QUALIFIED
Reason: 6 mapping actions required
```

Persist inspection artifacts next to the reference PDF or in the repository test fixtures as appropriate.

## 37.9 Form mappings are revision-specific

Never define a mapping merely as:

```text
21-526EZ -> mapping
```

Define:

```text
21-526EZ + exact revision/checksum -> mapping version
```

A mapping version may change even if the VA PDF does not.

Example mapping identity:

```text
vaFormMappings/21-526EZ__2026-01__mapping-v4
```

Recommended metadata:

```json
{
  "formRevisionId": "21-526EZ__2026-01__abc123",
  "mappingVersion": 4,
  "mappingCodeVersion": "git:<commit>",
  "status": "draft|tested|approved|superseded",
  "createdAt": "Timestamp",
  "approvedAt": "Timestamp|null",
  "approvedBy": "uid|null"
}
```

Keep executable mapping logic in version-controlled JavaScript or version-controlled declarative JSON checked into the repository. Do not allow arbitrary executable expressions to be edited from Firestore.

Example conceptual mapping:

```text
profile.legalFirstName       -> PDF field Veteran_First_Name
profile.legalLastName        -> PDF field Veteran_Last_Name
profile.dateOfBirth          -> PDF field Veteran_DOB
servicePeriods[0].startDate  -> PDF field Service_Start_Date_1
submissionIssues[0].name     -> PDF field Claimed_Condition_1
```

## 37.10 Canonical data flows into forms; PDFs do not become the database

The application must collect structured data in Firestore first.

Correct:

```text
Veteran profile
+ service history
+ claim issues
+ questionnaire responses
+ submission data
        ↓
server-side mapping
        ↓
filled VA PDF
```

Incorrect:

```text
Veteran types into PDF
        ↓
app tries to parse PDF back into canonical case state
```

A generated PDF is an output artifact, never the canonical case record.

If a required field is missing, the user should be sent back to a normal app workflow/questionnaire to collect the missing structured information, then the PDF is regenerated.

## 37.11 Generated form documents

Add user collection:

```text
/users/{uid}/generatedForms/{generatedFormId}
```

Recommended schema:

```json
{
  "formNumber": "21-526EZ",
  "formRevisionId": "21-526EZ__2026-01__abc123",
  "formRevision": "2026-01",
  "templateSha256": "...",
  "mappingVersion": 4,
  "mappingId": "21-526EZ__2026-01__mapping-v4",
  "formCatalogId": "forms-2026.09.1",
  "appReleaseId": "ios-1.4.0+112|android-1.4.0+112|web-1.4.0+112",
  "submissionId": "...",
  "status": "draft|generationFailed|readyForReview|reviewed|approved|submitted|superseded",
  "generatedStoragePath": "users/<uid>/generatedForms/<id>/filled.pdf",
  "flattenedStoragePath": "users/<uid>/generatedForms/<id>/filled-flattened.pdf|null",
  "generatedAt": "Timestamp",
  "reviewedAt": "Timestamp|null",
  "approvedAt": "Timestamp|null",
  "validationErrors": [],
  "validationWarnings": []
}
```

Generated artifacts must record enough information to recreate precisely how the document was produced.

## 37.12 PDF output modes

Per revision, explicitly configure one of:

```text
preserveFields
flatten
both
```

Do not globally flatten all VA PDFs. Qualification must determine what output behavior is safe for the specific form/workflow.

Where both are produced:

```text
filled.pdf             # fillable field structure retained
filled-flattened.pdf   # values rendered into page content
```

The submission adapter chooses the approved artifact for the target submission method.

## 37.13 Signatures are workflow-specific

Do not invent one universal digital-signature mechanism.

For each supported form/workflow, qualification must record the accepted signature/attestation paths, for example:

```text
vaApiAttestation
vaGovAttestation
pdfSignature
wetSignature
notRequired
```

The application must use only an explicitly supported path for that workflow.

If the selected submission method delegates signature/attestation to VA.gov or an official VA API, do not attempt to duplicate it in the PDF unless the workflow requires it.

## 37.14 Golden tests are required

Every qualified autofill form revision requires a golden test fixture containing deliberately populated values for all supported fields, including edge cases.

Recommended repository layout:

```text
test/fixtures/va-forms/
    21-526EZ/
        2026-01/
            full-case.json
            expected-field-values.json
            README.md
```

Required test command:

```bash
npm run va:forms:test -- --form 21-526EZ --revision 2026-01
```

Tests should verify as much as the PDF technology permits:

- correct template checksum;
- expected fields exist;
- expected mapping version is used;
- required source data resolves;
- text values round-trip correctly;
- checkboxes/radios use valid export values;
- required/conditional fields are populated;
- no unexpected field is written;
- output file opens successfully;
- expected page count remains sane;
- no generation warnings remain unresolved.

Qualification also requires at least one manual visual review of the generated PDF.

## 37.15 Owner approval command

Qualification must end with an explicit owner-triggered approval action, for example:

```bash
npm run va:forms:approve -- \
  --form 21-526EZ \
  --revision 2026-01 \
  --mapping-version 4
```

The approval command must refuse to proceed unless:

- checksum verification passed;
- field inspection completed;
- mapping exists;
- automated form tests pass;
- no blocking validation issue remains;
- the exact source artifact/mapping versions are specified.

Approval changes the form revision/mapping into `qualified`; it **does not** expose it to users yet.

## 37.16 Immutable form catalogs

User-visible support is controlled through immutable form catalogs.

Collection:

```text
/vaFormCatalogs/{catalogId}
```

Example catalog ID:

```text
forms-2026.09.1
```

Example:

```json
{
  "catalogVersion": "2026.09.1",
  "status": "draft|approved|published|superseded",
  "forms": {
    "21-526EZ": {
      "formRevisionId": "21-526EZ__2026-01__abc123",
      "mappingId": "21-526EZ__2026-01__mapping-v4"
    },
    "20-0995": {
      "formRevisionId": "20-0995__<revision>__def456",
      "mappingId": "20-0995__<revision>__mapping-v2"
    }
  },
  "createdAt": "Timestamp",
  "approvedAt": "Timestamp|null",
  "approvedBy": "uid|null"
}
```

A published catalog is immutable. Never edit a published catalog to point to a new form revision. Create a new catalog.

## 37.17 Application releases pin a catalog

Each shipping Flutter binary/build is mapped to exactly one approved form catalog.

Collection:

```text
/appReleases/{releaseId}
```

Recommended release ID:

```text
ios__1.4.0__112
android__1.4.0__112
web__1.4.0__112
```

Example:

```json
{
  "platform": "ios",
  "version": "1.4.0",
  "buildNumber": 112,
  "releaseChannel": "preview|stable",
  "formCatalogId": "forms-2026.09.1",
  "status": "testing|published|deprecated|blocked",
  "minimumBackendContractVersion": 6,
  "createdAt": "Timestamp",
  "publishedAt": "Timestamp|null"
}
```

The app build sends/uses its release identity when resolving form capability.

A user on `1.3.0+98` must continue resolving the catalog assigned to `1.3.0+98`, even if `1.4.0+112` has been published with newer forms.

Do not expose a mutable global `currentFormRevision` pointer to old clients.

## 37.18 Release identity in Flutter

Use Flutter's application version/build number plus an explicit backend contract/release constant generated at build time.

Conceptually:

```dart
class AppReleaseIdentity {
  final String platform;
  final String version;
  final String buildNumber;
  final int backendContractVersion;
}
```

The exact mechanism may use `package_info_plus`, generated environment configuration, or both.

The backend must validate requested form/catalog operations rather than trusting arbitrary form revision IDs supplied by the client.

## 37.19 Production preview testing without changing existing users

The release system must support testing a new app build against **production Firebase** while existing production users remain on the prior stable form catalog.

Recommended approach:

```text
Existing stable app 1.3.0
        -> stable release manifest
        -> forms-2026.08.2

Candidate app 1.4.0
        -> preview release manifest
        -> forms-2026.09.1
```

The candidate build is distributed only to owner/test users through the platform's normal preview/testing distribution mechanism.

Optionally, the backend may enforce preview access through an allowlist/custom claim. This is recommended if preview builds can otherwise be obtained broadly.

At no point does publishing `forms-2026.09.1` mutate `forms-2026.08.2` or the `1.3.0` release mapping.

## 37.20 Publishing a new app/form release is manual

Required owner flow:

```text
1. Owner runs VA form discovery
2. Owner chooses a form revision to import
3. Import official PDF into staging/reference storage
4. Inspect exact PDF fields
5. Update canonical data/questionnaires if the revision requires new information
6. Create/update revision-specific mapping
7. Run automated PDF tests
8. Manually inspect golden generated PDF
9. Explicitly approve form revision + mapping
10. Create a new immutable form catalog
11. Build a new app version that targets the intended backend contract
12. Create app release manifest mapping that build to the new catalog
13. Deploy candidate build to preview testers
14. Test against production backend/data paths using dedicated test users
15. Fix any form/mapping/app issues by creating new mapping/catalog/release metadata as needed
16. Publish the application release to stable users
```

There is no automatic transition from step 1 to step 16.

## 37.21 Release tooling

At minimum provide these scripts:

```bash
npm run va:forms:discover
npm run va:forms:import -- --form <form> --revision <revision>
npm run va:forms:inspect -- --form <form> --revision <revision>
npm run va:forms:test -- --form <form> --revision <revision>
npm run va:forms:approve -- --form <form> --revision <revision> --mapping-version <n>
npm run va:catalog:create -- --version <catalogVersion>
npm run va:catalog:validate -- --version <catalogVersion>
npm run va:catalog:publish -- --version <catalogVersion>
npm run app-release:create -- --platform <platform> --version <version> --build <build> --catalog <catalogVersion> --channel <preview|stable>
```

Destructive/mutating production commands must require explicit confirmation and authenticated owner/admin privileges.

## 37.22 Server-side form resolution

Never allow the client to say merely:

```text
Generate latest 21-526EZ
```

Instead generation must resolve through the app release:

```text
Authenticated user
+ App release identity
+ Requested workflow/form number
        ↓
AppReleaseResolver
        ↓
Pinned formCatalogId
        ↓
Catalog entry for 21-526EZ
        ↓
Exact formRevisionId
+ exact mappingId
        ↓
Form generation
```

The server must reject attempts to generate a revision/mapping not authorized by the caller's release catalog.

## 37.23 Form safety policy can override old catalogs

Catalog pinning protects compatibility, but the system also needs an emergency/reality check if VA stops accepting an older form.

Collection:

```text
/vaFormSafetyPolicies/{formRevisionId}
```

Example:

```json
{
  "formRevisionId": "21-526EZ__2026-01__abc123",
  "generationAllowed": true,
  "submissionAllowed": false,
  "blockReason": "VA no longer accepts this revision for this submission path.",
  "requiresAppUpdate": true,
  "updatedAt": "Timestamp",
  "updatedBy": "uid"
}
```

This policy is intentionally mutable because it is a safety/compatibility kill switch, not a visibility catalog.

Rules:

- it may block generation or submission;
- it may not redirect the old client to a newer form revision;
- it may not mutate the old catalog;
- when `requiresAppUpdate=true`, the UI must tell the Veteran that the application must be updated before the submission can continue;
- partially prepared structured case data remains intact so the newer app can regenerate the submission with the newly approved revision.

## 37.24 Final submission validation must re-check form safety

Immediately before any consequential submission/export intended for filing, server-side validation must verify:

```text
app release is recognized
form catalog is recognized
catalog is valid for the release
form revision is in that catalog
mapping is approved
reference template hash matches
form safety policy allows generation/submission
submission method supports this form/signature mode
all required structured data is present
generated artifact was produced from the expected template/mapping/catalog
```

Do not rely on a validation result produced hours/days earlier.

If validation fails because the revision has been blocked:

```text
Submission blocked
        ↓
Preserve Veteran case/submission draft
        ↓
Require app update
        ↓
New app resolves new catalog
        ↓
Regenerate forms from canonical Firestore data
        ↓
Veteran reviews again
        ↓
Explicit approval
        ↓
Submit
```

The system must never silently swap the generated document after the Veteran has reviewed it.

## 37.25 Review invalidation on regeneration

Any action that changes the generated PDF after user review must invalidate prior approval.

Examples:

- form revision changes;
- mapping version changes;
- claim issue changes;
- Veteran identity/contact information changes in a form-relevant way;
- included evidence/package changes where relevant;
- signature/attestation method changes.

Set:

```text
status = readyForReview
reviewedAt = null
approvedAt = null
```

The Veteran must review the regenerated document again.

## 37.26 Submission snapshots and auditability

When a Veteran approves a generated form/package, create an immutable logical snapshot containing:

```text
appReleaseId
formCatalogId
formNumber
formRevisionId
templateSha256
mappingId
mappingVersion
generatedArtifactHash
submission payload snapshot
included issue IDs
included evidence IDs
approval timestamp
submission method
```

The actual PDF/package bytes remain in Storage with immutable/versioned paths.

This permits later reconstruction of exactly what the Veteran reviewed and what was submitted.

## 37.27 Submission packages

For workflows that require PDFs/manual upload/mail, generate a package from canonical data and approved artifacts.

Potential layout:

```text
users/{uid}/submissions/{submissionId}/package/
    manifest.json
    21-526EZ-filled.pdf
    21-4138-personal-statement.pdf
    buddy-statement-<id>.pdf
    evidence-index.pdf
    submission-package.pdf
```

Whether a single merged PDF or separate files are actually sent depends on the approved VA submission method and its requirements.

## 37.28 Evidence index

The form/package subsystem should be able to generate a human-readable evidence index from `evidenceLinks`, for example:

| # | Evidence | Related issue | Relevant pages |
|---|---|---|---|
| 1 | Service Treatment Records | Lumbar spine | 417-419 |
| 2 | Lumbar MRI | Lumbar spine | 1-2 |
| 3 | Neurology visit | Migraines | 3-6 |
| 4 | Veteran statement | Lumbar spine | Entire document |

This index is a derived artifact. It does not replace underlying evidence metadata.

## 37.29 Supported-form scope is deliberate

Do not attempt to qualify every VA form at once.

The VA Forms API can be used to discover a large catalog, but the product should maintain an explicit supported-form allowlist tied to actual workflows.

Initial priority should follow implemented product workflows, for example:

```text
21-526EZ   Disability compensation
21-0966    Intent to File
21-4138    Statement in Support of Claim
21-10210   Lay/Witness Statement
21-4142    Authorization for private medical records
21-4142a   General Release for provider information
21-0781    Mental-health traumatic event information
21-8940    Individual Unemployability
21-4192    Employer information for IU
20-0995    Supplemental Claim
20-0996    Higher-Level Review
10182      Board Appeal / Notice of Disagreement
20-10206   Privacy Act / records request
```

Exact form availability/revision must always come from the authoritative VA source at qualification time.

## 37.30 Admin privileges

Form import/approval/catalog/release actions are administrative operations.

Use one or more of:

- Firebase Auth custom admin claims;
- Google IAM for CLI/service tooling;
- restricted administrative callable functions;
- CI/CD identity with tightly scoped permissions.

Do not authorize these actions merely because a user owns normal Veteran data.

## 37.31 Required Firestore Security Rules behavior

At minimum:

- normal users may read only published form capability metadata required by their resolved release;
- normal users may not create/update/delete `vaFormRevisions`;
- normal users may not create/update/delete `vaFormMappings`;
- normal users may not create/update/delete `vaFormCatalogs`;
- normal users may not create/update/delete `appReleases`;
- normal users may not update `vaFormSafetyPolicies`;
- generated user forms remain private to their owner;
- backend service code performs generation and authoritative validation.

## 37.32 Required test scenarios

Automated integration tests must cover at least:

### A. Old app remains pinned

```text
App 1.3 -> catalog A -> 21-526EZ revision X
App 1.4 -> catalog B -> 21-526EZ revision Y
```

Assert App 1.3 cannot resolve/generate revision Y.

### B. New form discovered but not approved

Assert imported `needsMapping` revision never appears in any published catalog.

### C. Approved form but no released catalog

Assert qualified revision is still invisible to stable clients.

### D. Preview production release

Assert preview app resolves preview catalog while stable app continues resolving stable catalog.

### E. Old revision emergency blocked

Set `submissionAllowed=false` for revision X. Assert old app is prevented from submission and receives update-required state; assert it is not silently redirected to revision Y.

### F. Regeneration invalidates approval

Approve generated form, change a form-relevant canonical field, regenerate, and assert prior approval is cleared.

### G. Wrong mapping/revision combination

Assert backend rejects a mapping created for another PDF checksum/revision.

### H. Template tamper detection

Change template bytes and assert generation fails because SHA-256 no longer matches revision metadata.

## 37.33 Owner-facing release checklist

Before publishing any app version with a new or changed VA form catalog, the owner should be able to work through this exact checklist:

```text
[ ] I deliberately ran VA form discovery.
[ ] I reviewed which forms changed.
[ ] I deliberately imported each form revision I want to evaluate.
[ ] The official template checksum is recorded/verified.
[ ] Field inspection completed.
[ ] Differences from the prior revision are understood.
[ ] Any new required app questions/data fields were implemented.
[ ] Revision-specific mappings are complete.
[ ] Automated PDF tests pass.
[ ] I manually opened and visually inspected representative generated PDFs.
[ ] Signature/attestation behavior is verified for each submission method.
[ ] I explicitly approved the form revision/mapping.
[ ] I created a new immutable form catalog.
[ ] Catalog validation passes.
[ ] I created a new app release manifest pinned to that catalog.
[ ] I tested the candidate build against production using test users.
[ ] Existing stable app versions still resolve their previous catalogs.
[ ] Server-side submission safety checks behave correctly.
[ ] I am ready to publish the candidate app release.
```

This checklist is the release gate. A coding agent must not bypass it by changing “current form” pointers automatically.


# 38. Commerce, Billing, Entitlements, and Physical Print/Mail Fulfillment

This section is authoritative for product monetization unless the owner explicitly changes pricing or store-policy strategy later.

The product intentionally supports **three different commercial products** because digital app entitlements and physical fulfillment are governed by different store/payment rules and have different lifecycle semantics:

1. a one-time Digital Claim Package unlock;
2. a recurring Premium subscription;
3. an optional physical Print & Mail fulfillment order.

Do not collapse these into one ambiguous SKU.

## 38.1 Commercial model

### Free tier

The free experience must provide enough value for the Veteran to organize and understand their case before payment is required.

Free access may include, subject to later product tuning:

- account creation and secure profile;
- service-history onboarding;
- condition discovery;
- guided questionnaires;
- claim/issue organization;
- basic document upload and evidence organization;
- basic decision-letter explanation;
- basic workflow guidance;
- basic C&P preparation;
- basic AI assistant usage subject to reasonable limits;
- viewing identified evidence gaps;
- preparation progress.

The paywall should occur when the user wants to unlock a completed, submission-ready digital claim package or premium ongoing features.

Do not make the free product intentionally unusable merely to force an early purchase.

### One-time Digital Claim Package

**Business target price:** USD $250 for one claim-package unlock.

Mobile storefront price points may be represented by the closest approved store price point, for example $249.99, if the platform does not expose an exact $250.00 consumer price point. Web may use exactly $250.00 if desired.

A Digital Claim Package unlock applies to **one Case**, not to one PDF, one individual submission, or the user's entire account forever. Related review/appeal package generation for issues that remain within that Case is covered by the Case unlock.

A package may include multiple documents, for example:

- supported VA application/review forms;
- required supplemental VA forms;
- Veteran personal statements;
- generated evidence index;
- generated submission checklist;
- generated cover/instruction material;
- other supported forms required by the selected workflow.

Once the Case is legitimately unlocked by the one-time purchase, the Veteran may regenerate and re-download digital packages for that Case without paying another $250 merely because data was corrected, evidence changed, or a related review workflow within that Case requires new supported forms.

If regeneration changes material content after user approval, normal review/approval invalidation rules still apply. Payment unlock and submission approval are separate concepts.

### Premium subscription

**Business target price:** USD $30/month.

Mobile storefronts may use the closest approved platform price point if necessary. Do not silently change the business target price without owner approval.

Premium is an auto-renewing subscription that provides ongoing product value. Planned Premium benefits include:

- digital claim-package generation while the subscription is active;
- digital claim-package downloads while the subscription is active;
- symptom tracking;
- flare-up tracking;
- functional-impact tracking;
- work-impact tracking;
- health/condition journaling;
- longitudinal symptom summaries;
- advanced C&P preparation;
- advanced AI assistance;
- advanced evidence organization;
- other recurring features specifically marked Premium.

A future product section will define the symptom-tracking system in detail. Billing code must not hard-code specific symptom-tracking features; it should rely on feature entitlements.

### Physical Print & Mail fulfillment

Physical Print & Mail is an **optional physical fulfillment service**.

Version 1 scope:

- we print the Veteran's finalized package through an approved third-party print/mail provider;
- the provider mails the physical package to the Veteran;
- the Veteran remains responsible for reviewing, signing where required, and submitting the package to VA;
- direct provider-to-VA submission is out of scope unless explicitly added later.

Physical fulfillment is not itself a digital entitlement.

## 38.2 Payment-channel strategy

Digital purchases and physical purchases must remain technically and commercially separate.

### Digital products

For digital features/content used inside the mobile applications:

- iOS uses Apple's In-App Purchase / StoreKit mechanisms;
- Android uses Google Play Billing by default;
- Web uses Stripe;
- RevenueCat is the preferred cross-platform subscription/purchase abstraction for Apple/Google and cross-platform entitlement normalization.

Do not describe Apple Pay as the iOS mechanism for purchasing digital claim-package access or Premium. Apple Pay is a wallet/payment method; App Store digital goods use Apple's applicable in-app commerce mechanisms unless a separately approved current policy/program explicitly changes that implementation.

Store rules change. Before production release, re-check the then-current Apple App Store Review Guidelines and Google Play Payments policy. Do not design the domain model around a temporary litigation-driven exception.

Current references as of 2026-09-29:

- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Google Play Payments policy/service fees: https://support.google.com/googleplay/android-developer/answer/112622
- RevenueCat documentation: https://www.revenuecat.com/docs/

### Physical products/services

Physical Print & Mail checkout is its own workflow and always uses Stripe, on iOS, Android, and web. RevenueCat does not sell Print & Mail. The price is computed per order from a live provider quote, so it cannot be a fixed store product.

On supported devices Stripe may expose:

- Apple Pay;
- Google Pay;
- credit/debit card;
- other approved Stripe payment methods.

This physical checkout must not secretly unlock digital product functionality that the user has not otherwise purchased or received through Premium.

## 38.3 Never create a mixed digital/physical mobile SKU

Do not create a mobile-store product like:

```text
Ultimate Claim Package - $275
Includes digital forms + app unlock + printed package
```

That unnecessarily mixes digital entitlement and physical fulfillment.

Instead model the flow as:

```text
Digital Claim Package unlock
    $250 digital transaction

THEN, optionally

Print & Mail fulfillment
    physical Stripe transaction
```

If the user already has digital-package access through Premium or a prior one-time purchase, skip the $250 digital transaction and offer only the physical fulfillment transaction.

This makes the rules simple:

```text
Does user have digital access to this package?
    YES -> may generate/download; may optionally buy Print & Mail
    NO  -> must first obtain digital package access
```

For web, a future checkout may display or even collect both line items in a coordinated experience, but the backend must still record them as separate economic components and separate entitlements/orders.

## 38.4 User-facing package copy

Agents must use consistent consumer copy. Do not invent claims of guaranteed approval, increased rating, expedited VA treatment, or legal/medical outcomes.

### Digital Claim Package — recommended product name

**Product name:** `Digital Claim Package`

**Short description:**

> Unlock digital claim-package generation for one Veteran Claims Buddy Case using the confirmed information and evidence in that Case.

**Expanded description:**

> Includes supported VA forms completed from your confirmed information, applicable supporting documents created in the app, a submission checklist, and downloadable package files for this Case. The one-time purchase stays with the Case, including supported related review/appeal packages for issues that continue within that Case. You can regenerate and re-download the Case package as your confirmed information changes. A new Case requires a new purchase unless Premium is active. VA approval or a particular disability rating is not guaranteed.

### Premium — recommended product name

**Product name:** `Premium`

**Price:** `$30/month` business target.

**Short description:**

> Ongoing claim tools, symptom tracking, advanced guidance, and digital claim-package access while Premium is active.

**Expanded description:**

> Premium includes digital claim-package generation while your subscription is active, plus ongoing tools such as symptom and flare-up tracking, functional-impact history, advanced C&P preparation, longitudinal summaries, and additional premium assistant features. Your VA outcomes are never guaranteed, and you remain in control of every submission.

Do not advertise Premium solely as “pay monthly to download PDFs.” The subscription must provide real ongoing value.

### Print & Mail — recommended product name

**Product name:** `Print & Mail`

**Short description:**

> Have your finalized claim package professionally printed and mailed to you.

**Expanded description:**

> We securely send your finalized package to an approved third-party print-and-mail provider. Your forms and selected package documents are printed, assembled, and mailed to the address you confirm. You review and submit the package to VA yourself. The Print & Mail price is one amount that includes fulfillment, a service fee, and payment processing.

Do not imply that purchasing Print & Mail means the package has been submitted to VA.

## 38.5 Entitlement semantics

Entitlements must be server-authoritative.

The client may cache entitlement state for UX, but it must not create its own permanent package unlock merely because a purchase UI returned success.

### Premium entitlement

Canonical semantic entitlement:

```text
premium
```

Possible state:

```json
{
  "isActive": true,
  "provider": "apple|google|stripe",
  "currentPeriodEndsAt": "...",
  "willRenew": true,
  "lastVerifiedAt": "..."
}
```

RevenueCat may be the upstream normalized source, but important product access should be projected into server-controlled application state for deterministic authorization and auditability.

### Case digital unlock

Permanent one-time digital access is not represented solely by a general RevenueCat entitlement because a Veteran may purchase multiple Case unlocks over time.

Use a Case-scoped ledger.

Suggested Firestore path:

```text
users/{uid}/caseUnlocks/{caseId}
```

Example:

```json
{
  "caseId": "case_123",
  "unlocked": true,
  "unlockSource": "oneTimePurchase",
  "billingProvider": "apple",
  "providerTransactionId": "...",
  "purchaseIntentId": "...",
  "unlockedAt": "...",
  "createdByFunction": true
}
```

Other valid `unlockSource` values may include:

```text
premiumGeneration
ownerGranted
promotionalGrant
migration
```

Any manual grant must be auditable.

### What happens when Premium expires

A package artifact that was successfully generated while Premium was active should remain accessible as a historical artifact. Premium itself does not permanently unlock future regeneration for the entire Case after the subscription expires unless the Case also has a one-time Case purchase.

The user should not lose already-generated claim artifacts merely because they cancel Premium.

After Premium expires:

- existing unlocked/generated packages remain available;
- new package generation requiring Premium is blocked unless separately purchased;
- Premium-only tracking/advanced features revert to the applicable free behavior;
- never delete health/symptom history solely because a subscription expired.

## 38.6 One-time mobile purchase semantics

The one-time mobile product must support repeated purchases over the lifetime of one account because the same Veteran may need multiple claim packages.

Do not create a unique Apple/Google SKU for each Veteran or package.

Use one generic store product per platform, conceptually:

```text
claim_package_unlock
```

On mobile this should be configured as the appropriate repeat-purchasable/consumable one-time product type supported by the platform.

Our backend binds a verified purchase transaction to a specific `submissionPackageId`.

The flow is:

```text
1. User opens package paywall.
2. Backend creates purchaseIntent tied to packageId and userId.
3. Client starts generic store purchase.
4. Store/RevenueCat verifies transaction.
5. Server receives/validates purchase result/webhook.
6. Server binds unused verified transaction to purchaseIntent.
7. Server creates packageUnlock.
8. Client refreshes entitlement/package state.
```

Never trust only client-supplied `packageId + purchaseSucceeded=true`.

## 38.7 Purchase intents and transaction ledger

Suggested collections:

```text
users/{uid}/purchaseIntents/{purchaseIntentId}
users/{uid}/billingTransactions/{transactionId}
users/{uid}/packageUnlocks/{submissionPackageId}
```

### Purchase intent example

```json
{
  "type": "digitalClaimPackage",
  "submissionPackageId": "pkg_123",
  "expectedBusinessPriceUsd": 250.00,
  "status": "created",
  "createdAt": "...",
  "expiresAt": "..."
}
```

### Billing transaction example

```json
{
  "transactionType": "oneTimeDigitalPackage",
  "provider": "apple",
  "providerProductId": "claim_package_unlock_ios",
  "providerTransactionId": "...",
  "purchaseIntentId": "...",
  "submissionPackageId": "pkg_123",
  "grossAmount": 249.99,
  "currency": "USD",
  "status": "verified",
  "verifiedAt": "...",
  "refundStatus": "none"
}
```

Provider transaction IDs must be globally deduplicated server-side.

A transaction may never unlock two package IDs.

## 38.8 Refunds, reversals, chargebacks, and revocation

Billing logic must handle more than successful purchases.

Support events such as:

- refund;
- chargeback;
- subscription cancellation;
- billing retry/grace period;
- subscription expiration;
- store revocation;
- Stripe payment failure;
- webhook replay.

Every provider webhook handler must be idempotent.

Do not delete already-submitted VA records because of a refund.

For a refunded package that has not been submitted, product-access behavior should be controlled by a server policy field so the owner can choose the appropriate customer-service policy without rewriting billing integrations.

## 38.9 RevenueCat role

RevenueCat is the preferred cross-platform purchase/subscription abstraction for digital mobile commerce.

Use the Firebase UID as the RevenueCat app user ID after Firebase authentication succeeds.

Conceptually:

```text
Firebase UID
    == RevenueCat appUserId
```

Do not use an anonymous RevenueCat identity as the durable identity for a Veteran with claim data.

RevenueCat responsibilities:

- normalize Apple/Google subscription state;
- normalize applicable one-time mobile purchase events;
- expose customer entitlement state;
- simplify restore-purchase flows;
- relay purchase/subscription lifecycle events;
- optionally integrate web subscription state where selected.

Application responsibilities remain:

- package-specific unlock ledger;
- authorization;
- purchaseIntent binding;
- physical-order state;
- VA package state;
- refund/access policy;
- audit history.

Current RevenueCat pricing at document verification time is free for up to $2,500 monthly tracked revenue, then 1% of tracked revenue on the Pro plan. Treat this as current external pricing, not a permanent constant. Re-check before launch.

Reference: https://www.revenuecat.com/pricing

## 38.10 Stripe role

Stripe is used for:

- web one-time Digital Claim Package purchases;
- web Premium subscriptions if RevenueCat/Stripe is selected for unified web entitlement handling;
- all physical Print & Mail payments across iOS, Android, and web;
- Apple Pay/Google Pay/card presentation for physical fulfillment where supported.

Stripe secret keys live only in Google Secret Manager / Cloud Functions secret configuration.

Never ship Stripe secret keys to Flutter.

At document verification time, Stripe's published standard U.S. online-card price is 2.9% + $0.30 per successful domestic-card transaction. Store that rate in `commerceConfig`, not in Flutter. Print & Mail uses it to gross up the charge, as specified in Section 38.14. Update the config when Stripe's rate changes. Do not treat the rate in this paragraph as permanent.

Reference: https://stripe.com/pricing

## 38.11 Store commission awareness

The owner must understand that the $250/$30 consumer price is **gross retail price**, not net revenue.

Apple/Google store commissions and program eligibility materially affect net receipts and may change over time.

Do not calculate business profitability assuming the company receives 100% of mobile gross sales.

At release planning time, the owner should explicitly review:

- Apple Small Business Program eligibility;
- current Apple in-app purchase commission structure;
- Google Play current U.S. digital-goods fee structure;
- RevenueCat fee tier;
- web Stripe processing cost.

Current references:

- Apple programs: https://developer.apple.com/help/account/membership/programs-overview
- Google Play fees: https://support.google.com/googleplay/android-developer/answer/112622
- RevenueCat pricing: https://www.revenuecat.com/pricing
- Stripe pricing: https://stripe.com/pricing

The application pricing architecture must tolerate different net receipts per platform.

## 38.12 Recommended physical fulfillment provider strategy

Use a provider abstraction. Do not make the application domain depend directly on one vendor.

Interface shape, conceptually:

```ts
interface PrintMailProvider {
  getQuote(input: PrintMailQuoteInput): Promise<PrintMailQuote>;
  createOrder(input: PrintMailOrderInput): Promise<PrintMailOrderResult>;
  getOrder(providerOrderId: string): Promise<PrintMailOrderStatus>;
  cancelOrder?(providerOrderId: string): Promise<CancelResult>;
}
```

Provider-specific adapters may include:

```text
LetterStreamPrintMailProvider
DocuPostPrintMailProvider
LobPrintMailProvider
```

### Preferred initial vendor candidate: LetterStream

LetterStream is the recommended first provider to evaluate because its current offering aligns unusually well with this product:

- API-based mail submission;
- API price checks;
- PDF proofs;
- mailing status;
- tracking for premium services;
- no minimum quantity for ordinary service;
- HIPAA-oriented privacy/security claims;
- a specific **Monetization Mode** where we control customer pricing/billing while LetterStream remains the fulfillment engine behind the scenes.

Current official API page:

https://www.letterstream.com/api/

Current pricing page:

https://www.letterstream.com/pricing/

Current public pricing as of 2026-09-29 includes:

- First-Class Letter starting around $1.27 including print/envelope/postage;
- additional black-and-white pages around $0.12 each;
- First-Class Flat starting around $2.73;
- Certified First-Class starting around $8.63;
- Certified with electronic return receipt around $11.54;
- FedEx 2Day starting around $16.35;
- published 75-page First-Class Flat example around $15.38;
- published 75-page Certified Flat example around $25.82.

Rates can change with USPS pricing and vendor policy. Never hard-code these published numbers as the quote engine.

LetterStream's API explicitly supports a price-check operation; production checkout should use the provider's current quote rather than our historical pricing table.

### Alternative candidate: DocuPost

DocuPost currently provides:

- Send Letter API;
- PDF-based mailing;
- first-class, certified, priority, and priority express options;
- black-and-white/color;
- double-sided options;
- HIPAA-compliant service claims and a signed BAA option described by the vendor;
- public pay-as-you-go pricing.

Current public pricing as of 2026-09-29 advertises letters starting around $0.95 plus page charges, with black-and-white pages around $0.30/page, color around $0.40/page, First-Class upgrade around $0.23, Certified upgrade around $10.25, and Priority Mail upgrade around $19.

References:

https://docupost.com/pricing/
https://help.docupost.com/developer-documentation/send-letter-api

### Alternative candidate: Lob

Lob provides a mature REST Print & Mail API, webhooks, address verification, tracking, healthcare/HIPAA support, and vetted print infrastructure.

It is a strong enterprise candidate but current compliance/pricing arrangements may require a higher plan or direct commercial agreement.

Lob currently documents domestic letter PDF limits of 60 pages single-sided or 120 pages double-sided for its standard letter endpoint, with large letters moved to flat envelopes based on page count.

References:

https://docs.lob.com/
https://www.lob.com/pricing
https://www.lob.com/industries/healthcare

### Other pricing reference: PostalMethods

PostalMethods publishes transparent page-banded pricing and additional-postage tiers and may be useful as a cost comparison. Current published pricing varies by prepaid tier.

Reference:

https://www.postalmethods.com/pricing/

### Other pricing reference: Click2Mail

Click2Mail currently advertises domestic First-Class full-color letters at approximately $1.45 for the first sheet/two pages and approximately $0.75 for each additional two-page sheet in its Easy Letter Sender product.

Reference:

https://easylettersender.click2mail.com/pricing

## 38.13 Production vendor privacy gate

The physical provider will receive highly sensitive Veteran information and potentially medical/claims information.

Before any real Veteran package is transmitted to a print/mail provider, the owner must complete a production vendor review.

Minimum owner checklist:

```text
[ ] Vendor account created
[ ] API/automation mode approved
[ ] Commercial terms reviewed
[ ] Privacy/security documentation reviewed
[ ] BAA or equivalent healthcare-data agreement obtained when available/appropriate
[ ] Data retention/deletion behavior understood
[ ] Production credentials created
[ ] Credentials stored only in Secret Manager
[ ] Test mail successfully received
[ ] Proof/preview workflow tested
[ ] Cancellation window understood
[ ] Failed-mail behavior understood
[ ] Tracking/webhook behavior tested
[ ] Support/escalation contact recorded
```

An agent must STOP at this OWNER ACTION GATE before enabling production print/mail.

For LetterStream specifically, current vendor instructions say API access is manually enabled after the customer contacts support, explains the business/use case, chooses an API mode, and confirms development resources. If selected, request **Monetization Mode** unless later commercial/legal review chooses another mode.

## 38.14 Physical package pricing formula

Print & Mail is a separate Stripe checkout. The Veteran pays one amount. That amount is built so the money left after Stripe's fee covers the provider's quote and the service fee. The company does not absorb the Stripe fee.

Do not encode a static `$19.99 Print & Mail` price. Page count, postage class, vendor rates, delivery option, and taxes change the quote.

`providerFulfillmentCents` is the selected provider's live quote, including whatever that provider charges for the order:

- printing;
- paper/page count;
- assembly/insertion;
- envelopes or flats;
- postage/shipping;
- tracking or certified-mail services when selected;
- provider fulfillment fees;
- taxes or other provider-imposed charges when applicable.

Canonical pricing rule, in integer cents. Round the final charge up to the next cent.

```text
netTargetCents = providerFulfillmentCents + printMailServiceFeeCents

customerChargeCents = ceil(
  (netTargetCents + stripeFixedFeeCents) / (1 - stripePercent)
)

estimatedStripeFeeCents = customerChargeCents - netTargetCents
```

Launch config values:

```text
printMailServiceFeeCents = 995     // $9.95, always added
stripePercent            = 0.029   // from commerceConfig, not from Flutter
stripeFixedFeeCents      = 30      // from commerceConfig, not from Flutter
```

`customerChargeCents` is the only number the Veteran sees, labeled `Print & Mail`. Checkout does not split out the provider quote, the $9.95 service fee, or the Stripe gross-up. Terms disclose that the price includes fulfillment, a service fee, and payment processing.

Worked example using a `$15.38` provider quote:

```text
providerFulfillmentCents = 1538
netTargetCents           = 1538 + 995 = 2533
customerChargeCents      = ceil((2533 + 30) / 0.971) = 2640
Veteran sees             = $26.40
estimatedStripeFeeCents  = 107
```

After Stripe settles, store the actual fee from the balance transaction. A one-cent difference from the estimate is acceptable. The quote stored on the order is the quote used to compute `customerChargeCents`. If the provider quote is refreshed because it expired, recompute the whole charge and show the new total before payment.

All of these stay on the order record:

- provider quote;
- service fee;
- Stripe rate used;
- customer charge;
- estimated Stripe fee;
- actual Stripe fee after settlement.

The $250 Digital Claim Package and the $30/month Premium subscription remain the digital products sold through RevenueCat. Print & Mail stays this Stripe workflow.

## 38.15 Total price scenarios

### User has not purchased package and does not have Premium

Digital access must be purchased first.

```text
Digital Claim Package:            $250 business target
Print & Mail fulfillment:         dynamic
Total economic cost:              $250 + dynamic fulfillment
```

On mobile these may be two payment events:

1. platform-compliant digital purchase;
2. Stripe physical-fulfillment purchase.

Do not try to hide this by charging the whole total through Stripe on mobile.

### User already purchased this Digital Claim Package

```text
Digital Claim Package:            already paid
Print & Mail fulfillment:         dynamic only
```

### User has active Premium

```text
Digital package generation:       included while Premium active
Print & Mail fulfillment:         dynamic only
```

Do not charge an active Premium subscriber another $250 for the same package just because they select physical delivery.

### User previously generated/unlocked package under Premium but Premium later expired

Existing package remains accessible.

If the existing package is eligible for print fulfillment:

```text
Digital Claim Package:            already unlocked
Print & Mail fulfillment:         dynamic only
```

## 38.16 Illustrative physical-cost examples

These are examples only. Checkout must use a live provider quote.

Using LetterStream's published pricing as a sanity-check reference at the time this specification was written:

- a small standard First-Class package may cost only a few dollars;
- a published 75-page First-Class Flat example is approximately `$15.38`;
- a published 75-page Certified Flat example is approximately `$25.82`;
- FedEx/tracked options should use the provider's exact current quote.

If the provider returns `$15.38`, the Veteran does not pay `$15.38`. Section 38.14 adds the $9.95 service fee and grosses up for Stripe. At the launch rates that charge is `$26.40`.

```text
Digital Claim Package             $250.00
Print & Mail                       $26.40
```

If Premium already provides digital-package access, the Veteran sees only the Print & Mail amount. That amount is still the computed charge, not the raw provider quote.

Do not promise these ranges in marketing copy because page counts, delivery choices, taxes, and vendor rates vary.

## 38.17 Page-count and provider-limit handling

Print/mail quoting must calculate the final physical package after PDF generation, not from an estimated questionnaire page count.

Input to quote should include at least:

```text
final page count
paper size
single/double sided mode
black-and-white/color mode
recipient ZIP/address
mail/service class
number of physical mailpieces if split
provider-specific packaging requirements
```

If a provider cannot handle the package in one mailpiece:

1. do not truncate the package;
2. split only according to a tested provider/package policy;
3. quote the full set of mailpieces;
4. clearly tell the Veteran how many envelopes/packages will arrive;
5. preserve ordering with package-part labels;
6. never silently omit evidence.

Provider limits belong in provider adapters/configuration, not scattered through UI code.

## 38.18 Default physical print policy

Initial default should be conservative:

```text
recipient: Veteran's confirmed mailing address
paper: US Letter where source package supports it
printing: black-and-white unless content requires color or user selects color
service: standard economical domestic delivery
proof required before order: yes
user confirmation of address: yes
user confirmation of package contents: yes
```

Do not automatically send the package as soon as payment succeeds.

Recommended final physical flow:

```text
Package finalized
    ↓
Digital entitlement verified
    ↓
User chooses Print & Mail
    ↓
Address confirmation
    ↓
Live provider quote
    ↓
Show physical price
    ↓
Stripe payment
    ↓
Generate final immutable print artifact
    ↓
Provider proof/validation when available
    ↓
Explicit Send confirmation if the payment flow did not already include it
    ↓
Create provider order
    ↓
Track status
```

At minimum there must be explicit confirmation immediately before the order becomes non-cancelable/provider-submitted.

## 38.19 Print artifact isolation

Do not send arbitrary mutable Storage URLs to a provider.

Create a final immutable print artifact for the physical order.

Suggested path:

```text
users/{uid}/printOrders/{printOrderId}/artifacts/final-print-package.pdf
```

Record:

- SHA-256;
- byte length;
- page count;
- package revision;
- form catalog version;
- generation timestamp;
- source submissionPackageId.

If the provider requires a URL, generate a short-lived signed URL on the server with the narrowest practical lifetime.

Do not make Veteran document buckets public.

## 38.20 Physical order model

Suggested path:

```text
users/{uid}/printOrders/{printOrderId}
```

Example:

```json
{
  "submissionPackageId": "pkg_123",
  "status": "quoted",
  "provider": "letterstream",
  "providerQuoteId": "...",
  "providerOrderId": null,
  "pageCount": 42,
  "printMode": "blackAndWhite",
  "duplex": false,
  "deliveryMethod": "firstClass",
  "providerQuotedCostCents": 1538,
  "providerTaxCents": 0,
  "providerFulfillmentTotalCents": 1538,
  "serviceFeeCents": 995,
  "stripePercentUsed": 0.029,
  "stripeFixedFeeCentsUsed": 30,
  "customerChargeCents": 2640,
  "estimatedStripeFeeCents": 107,
  "actualStripeFeeCents": null,
  "currency": "USD",
  "stripePaymentIntentId": null,
  "shippingAddressSnapshot": {
    "name": "...",
    "line1": "...",
    "line2": null,
    "city": "...",
    "state": "...",
    "postalCode": "...",
    "country": "US"
  },
  "printArtifactPath": "...",
  "printArtifactSha256": "...",
  "quotedAt": "...",
  "paidAt": null,
  "submittedToProviderAt": null,
  "mailedAt": null,
  "deliveredAt": null
}
```

The shipping-address snapshot is intentional: later profile-address edits must not rewrite the historical address used for an existing order.

## 38.21 Physical order status state machine

Use deterministic states such as:

```text
draft
    ↓
quoted
    ↓
awaitingPayment
    ↓
paid
    ↓
preparingArtifact
    ↓
readyForProvider
    ↓
submittedToProvider
    ↓
inProduction
    ↓
mailed
    ↓
delivered | completed
```

Failure/cancellation branches:

```text
quoteExpired
paymentFailed
providerRejected
cancelRequested
cancelled
undeliverable
refunded
manualReview
```

Do not let the LLM invent or mutate this state machine.

## 38.22 Quote expiration

Vendor quotes must have a short server-defined lifetime.

Suggested initial policy:

```text
quote valid for 15 minutes
```

At checkout/payment time, if the quote is expired:

1. request a fresh provider quote;
2. recompute customer physical price;
3. if price changed materially, show the new price before charging;
4. do not silently absorb an arbitrarily large cost change.

## 38.23 Physical billing and idempotency

Create Stripe PaymentIntents server-side.

Use idempotency keys for:

- PaymentIntent creation;
- vendor order creation;
- any provider call capable of creating physical mail.

A webhook retry must never create a duplicate package mailing.

Recommended unique domain key:

```text
printOrderId
```

The server should refuse to create a second live provider order for a `printOrderId` that already has a provider order ID unless a deliberate resend workflow is being executed.

## 38.24 Print/mail address verification

Before accepting final fulfillment payment, validate/normalize the mailing address through the selected provider or another approved address-verification mechanism where available.

Show corrections to the Veteran if the normalized address materially differs.

The Veteran must confirm the final destination address.

Do not automatically overwrite the Veteran's profile address because a mail vendor normalized one order's address.

## 38.25 Fulfillment tracking UX

If the provider exposes tracking/status events, show them in the app.

Example user statuses:

```text
Order received
Preparing your package
Printed
Mailed
In transit (when available)
Delivered (when available)
```

Do not show a provider-internal code directly to the user.

Keep raw provider status in audit/provider metadata and map it to stable application statuses.

## 38.26 Billing feature flags/config

Create server-controlled commerce configuration.

Suggested global document:

```text
commerceConfig/current
```

Example:

```json
{
  "currency": "USD",
  "digitalClaimPackageBusinessPriceCents": 25000,
  "premiumMonthlyBusinessPriceCents": 3000,
  "printMailServiceFeeCents": 995,
  "stripePercentBps": 290,
  "stripeFixedFeeCents": 30,
  "digitalPackagePurchasesEnabled": true,
  "premiumEnabled": true,
  "printMailEnabled": false,
  "activePrintMailProvider": "letterstream"
}
```

Do not use this document as a substitute for App Store/Google Play price metadata. Mobile store UI must display the localized store-provided price for digital IAP.

The business-price fields are expected/target values used for validation, analytics, and web pricing.

## 38.27 Paywall behavior

The paywall should make the alternatives obvious without dark patterns.

Recommended structure:

```text
Choose how you want to unlock your claim package

ONE-TIME
Digital Claim Package
$250
Unlock this submission package permanently.

PREMIUM
$30/month
Generate digital claim packages while active plus ongoing premium tools.

[Continue with one-time package]
[Start Premium]
```

Then, after digital access exists:

```text
Want a printed copy mailed to you?

Print & Mail
Calculated from page count and delivery option.

[Get print/mail price]
[No thanks, download digitally]
```

Do not place Print & Mail ahead of digital entitlement in a way that implies Stripe physical checkout can replace the required digital purchase on iOS/Android.

## 38.28 Premium upgrade messaging

Where Premium is promoted, the copy should emphasize ongoing utility:

```text
Track symptoms over time
Build a record of flare-ups and daily-life impact
Prepare for C&P exams using your actual history
Generate digital claim packages while subscribed
Use advanced claim and evidence tools
```

Avoid messaging like:

```text
Subscribe so we can get you a higher VA rating.
```

No outcome guarantees.

## 38.29 Subscription cancellation UX

Users must be able to see:

- Premium active/inactive state;
- next renewal date where available;
- cancellation/manage-subscription route;
- what access changes when Premium ends;
- confirmation that their claim history and existing generated packages are retained.

On Apple/Google, use the appropriate platform subscription-management deep link/flow.

On web, use Stripe customer-portal functionality or equivalent secure subscription-management workflow.

Do not build a fake local “cancel” toggle that fails to cancel the underlying store subscription.

## 38.30 Restore purchases

Mobile apps must provide a visible Restore Purchases function when required/appropriate for the platform.

After restore:

1. RevenueCat/store state is refreshed;
2. server entitlement projection is reconciled;
3. existing permanent package unlocks remain sourced from our Firestore ledger;
4. missing server transaction records should be reconciled cautiously using verified store history, never client claims alone.

## 38.31 Owner action gates — billing setup order

Billing must be introduced only after the application can generate a test claim package end-to-end in DEV without payment.

Do not make payment infrastructure a blocker for early claims-workflow development.

### OWNER ACTION GATE 38A — Apple developer commerce setup

Agent must STOP and ask owner to complete the required App Store Connect setup.

Owner tasks include:

```text
[ ] Confirm Apple Developer Program account is active
[ ] Create/confirm iOS app record in App Store Connect
[ ] Accept current Paid Applications / commerce agreements
[ ] Complete banking/tax information required for paid IAP
[ ] Create one-time repeat-purchasable Digital Claim Package product
[ ] Set target U.S. storefront price to closest approved point to $250
[ ] Create Premium auto-renewable monthly subscription
[ ] Set target U.S. storefront price to closest approved point to $30/month
[ ] Record exact product IDs in the project's secure configuration documentation
[ ] Confirm products are available for sandbox testing
```

Recommended IDs, subject to bundle naming rules:

```text
com.<company>.<app>.claim_package_unlock
com.<company>.<app>.premium_monthly
```

Agent must not invent final production bundle/product IDs without reading the actual project configuration.

### OWNER ACTION GATE 38B — Google Play commerce setup

Agent must STOP and ask owner to complete Google Play Console setup.

Owner tasks include:

```text
[ ] Confirm Play Console developer account
[ ] Create/confirm Android app
[ ] Complete merchant/payments profile
[ ] Accept current commerce terms
[ ] Review/enroll in applicable service-fee program if eligible
[ ] Create repeat-purchasable one-time product for Digital Claim Package
[ ] Set target U.S. price closest to $250
[ ] Create monthly Premium subscription/base plan
[ ] Set target U.S. price closest to $30/month
[ ] Add license testers/test accounts
[ ] Record exact product IDs
```

### OWNER ACTION GATE 38C — RevenueCat setup

After Apple and Google products exist, owner/agent jointly configure RevenueCat.

Owner tasks:

```text
[ ] Create RevenueCat account/project
[ ] Add iOS app
[ ] Add Android app
[ ] Connect App Store credentials/API configuration
[ ] Connect Google Play service account/configuration
[ ] Import/map store products
[ ] Create `premium` entitlement
[ ] Attach monthly subscription products to `premium`
[ ] Configure one-time package product for purchase event tracking without treating it as account-wide permanent entitlement
[ ] Configure DEV/sandbox testing
[ ] Configure webhook destination to DEV Cloud Function
[ ] Store RevenueCat webhook auth secret in Secret Manager
```

Agent then implements and verifies RevenueCat integration using Firebase UID as app user ID.

### OWNER ACTION GATE 38D — Stripe setup

Owner tasks:

```text
[ ] Create/confirm Stripe account
[ ] Complete business verification
[ ] Complete payout bank details
[ ] Use Stripe test mode first
[ ] Create web one-time Digital Claim Package price/product as needed
[ ] Create web Premium recurring price/product as needed
[ ] Configure Customer Portal for web subscription management
[ ] Configure webhook endpoint to DEV Cloud Function
[ ] Obtain webhook signing secret
[ ] Configure Apple Pay/web-domain requirements if web checkout uses it
[ ] Configure Google Pay/payment method availability where applicable
[ ] Store all server secrets only in Secret Manager
```

Never put Stripe secret keys in `.env` files committed to source control.

### OWNER ACTION GATE 38E — Print/mail provider setup

Only after DEV print artifact generation exists.

If LetterStream is selected:

```text
[ ] Create LetterStream account
[ ] Contact LetterStream support for API access
[ ] Explain SaaS/Veteran claim-package fulfillment use case
[ ] Request Monetization Mode unless owner chooses otherwise
[ ] Obtain API documentation/credentials
[ ] Review HIPAA/privacy/security documentation
[ ] Execute BAA or appropriate data-processing agreement if available/required
[ ] Configure prepay/low-balance approach as needed
[ ] Store production credentials in Secret Manager
```

If another provider is selected, equivalent privacy/API/payment/account steps are required.

## 38.32 DEV billing test matrix

Do not enable production billing until all applicable tests pass.

### Digital one-time

```text
[ ] Successful Apple sandbox purchase unlocks exactly one package
[ ] Successful Google test purchase unlocks exactly one package
[ ] Successful web Stripe test purchase unlocks exactly one package
[ ] Replayed webhook does not duplicate unlock
[ ] Same transaction cannot unlock second package
[ ] Cancelled purchase creates no unlock
[ ] Failed purchase creates no unlock
[ ] Restoring/reconciling does not duplicate transaction
```

### Premium

```text
[ ] iOS Premium activates
[ ] Android Premium activates
[ ] Web Premium activates
[ ] Cross-device login sees same Premium entitlement after backend reconciliation
[ ] Cancellation retains access through paid-through period as provider indicates
[ ] Expiration removes future Premium generation access
[ ] Existing historical generated packages remain available
[ ] Billing retry/grace state is represented correctly
```

### Physical

```text
[ ] Package must already have digital entitlement before mobile physical checkout
[ ] Provider quote generated from final artifact
[ ] Live provider quote is an input to the Print & Mail price, not the price itself
[ ] Customer charge equals the Section 38.14 gross-up of quote + service fee
[ ] Stripe fee is covered by the charge, not absorbed
[ ] Provider cost, service fee, rate used, and actual Stripe fee are retained internally
[ ] Veteran sees one Print & Mail price, not the internal cost breakdown
[ ] Stripe test payment creates paid printOrder
[ ] Provider createOrder is idempotent
[ ] Duplicate Stripe webhook cannot mail twice
[ ] Bad address is surfaced before final send
[ ] Provider rejection moves order to failure/manual review
[ ] Test package arrives with correct content/page ordering
[ ] Sensitive Storage object remains private
[ ] Signed provider URL expires
```

## 38.33 Production release gate — commerce

Before production commerce is enabled:

```text
[ ] Digital package generation is stable without billing
[ ] Apple products approved/available as required
[ ] Google products active as required
[ ] RevenueCat production credentials configured
[ ] Stripe live account/webhooks configured
[ ] Store policy review re-performed using current policies
[ ] Current platform fees reviewed for margin impact
[ ] Print/mail provider production vendor review complete
[ ] BAA/data agreement complete where appropriate
[ ] One real low-risk internal purchase tested per platform if permitted
[ ] One real physical test order delivered correctly
[ ] Refund/cancellation support procedure documented
[ ] Customer support contact/process documented
[ ] `commerceConfig/current.printMailEnabled` remains false until physical acceptance test passes
```

## 38.34 Architecture rule: billing is not claim logic

Claims domain code must not contain expressions like:

```text
if (platform == ios && productId == ...)
```

Domain services should ask stable questions such as:

```text
CanUserGeneratePackage(uid, packageId)?
CanUserDownloadPackage(uid, packageId)?
CanUserUsePremiumFeature(uid, featureKey)?
CanUserOrderPrintMail(uid, packageId)?
```

Billing adapters answer how entitlement was obtained.

This separation is mandatory so store/payment policy changes do not infect the VA claims domain model.

## 38.35 Recommended entitlement service contract

Conceptually:

```ts
interface EntitlementService {
  getPremiumStatus(uid: string): Promise<PremiumStatus>;
  canGeneratePackage(uid: string, packageId: string): Promise<boolean>;
  canDownloadPackage(uid: string, packageId: string): Promise<boolean>;
  hasPermanentPackageUnlock(uid: string, packageId: string): Promise<boolean>;
  grantPackageUnlockFromVerifiedTransaction(input: VerifiedPackagePurchase): Promise<void>;
}
```

Client-facing responses should not expose unnecessary provider secrets/raw receipt data.

## 38.36 Recommended checkout summary copy

### One-time digital only

```text
Digital Claim Package
$250

Unlock this submission package, including supported completed VA forms and generated package documents. You can regenerate and re-download this purchased package later.
```

### Premium

```text
Premium
$30/month

Generate digital claim packages while Premium is active and unlock ongoing tools including symptom tracking, longitudinal condition history, advanced C&P preparation, and premium assistant features.

Cancel anytime through the platform where you subscribed.
```

### Physical add-on

```text
Print & Mail
$XX.XX

Have your finalized claim package professionally printed, assembled, and mailed to you.

This price includes printing, postage, fulfillment, a service fee, and payment processing.

This mails the package to you. It does not submit the claim to VA. This charge is non-refundable once paid.
```

The checkout UI must keep this simple. Do not expose the provider quote, the $9.95 service fee, postage, taxes, or the Stripe gross-up as separate customer-facing lines. The Veteran sees one `Print & Mail` price and the disclosure above. Internal records retain the full breakdown.

### Non-entitled user selecting physical delivery

The UI should first explain:

```text
Print & Mail is an add-on to a completed claim package.

First unlock this claim package for $250 or start Premium. After that, we'll calculate the exact print-and-mail price from the final page count.
```

This is clearer and safer than attempting a mixed physical/digital transaction.

## 38.37 Current research snapshot — do not treat as permanent pricing

Verified 2026-09-29 for planning purposes:

| Provider | Relevant current public pricing/capability | Notes |
|---|---|---|
| LetterStream | First-Class from ~$1.27; B&W additional pages ~$0.12; First-Class Flat from ~$2.73; 75-page Flat example ~$15.38; Certified/FedEx options | Strong first candidate; API price check; Monetization Mode; privacy/HIPAA claims |
| DocuPost | Letters from ~$0.95; B&W ~$0.30/page; color ~$0.40/page; First-Class upgrade ~$0.23; Certified upgrade ~$10.25 | API available; signed BAA/HIPAA claims; straightforward pay-as-you-go |
| Lob | Letters from published sub-$1 base rates depending plan; mature API/webhooks/address tools | Strong enterprise option; HIPAA/BAA support; commercial tier may matter |
| PostalMethods | Base letter roughly ~$1.08-$1.33 depending prepaid tier plus per-page and page-band postage charges | Transparent cost benchmark |
| Click2Mail | Domestic First-Class full-color letter ~$1.45 first 2-page sheet + ~$0.75/additional sheet | Useful comparison; privacy/compliance fit must be separately verified |

Primary pricing rule remains:

> **Never calculate production physical checkout from this table. Get a live quote from the configured provider.**

