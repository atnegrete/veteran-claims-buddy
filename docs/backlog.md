# Backlog — deferred features and open decisions

**Updated:** 2026-10-04

This file tracks work that is deliberately **not** part of the current build, because it needs a product decision, a discussion, or something outside the agent's reach. `docs/build-progress.md` stays the checklist for the active build. When an item here is decided and ready, expand it into `docs/build-progress.md` and build it from there.

The agent-buildable MVP sequence (build-progress steps 6–23) is complete. Everything below is either a decision we have not made, a known limitation, or a later workflow.

Status values: `needs decision`, `blocked`, `deferred`.

## Open product decisions

These need a steer before any code is written.

### B1. Vet Buddy proposing changes to the claim (handoff 14D)
- **Status:** needs decision.
- **Today:** Vet Buddy only explains saved records. It never changes the claim. That is the core rule in `AGENTS.md`.
- **What 14D would add:** Vet Buddy could *propose* a change, and nothing is written until the Veteran taps Confirm. It could also post a proactive notice instead of only answering when asked.
- **The decision:** what is Vet Buddy allowed to propose? Options, narrow to broad:
  1. Only suggest adding a condition it already sees in the saved answers.
  2. Also suggest exam details or notes.
  3. Also post proactive notices (unprompted).
- **Why it waits:** this crosses the "explains, does not change" rule, so the scope has to be chosen on purpose, not invented.
- **When built:** expand into build-progress step 14, add a confirm-first UI in the chat bubble, a proposed-change record, Firestore rules for it, and the callable output that carries a proposal.

### B2. Monthly symptom summary
- **Status:** needs decision.
- **Today:** the Symptoms Tracker saves check-ins and events. `/symptoms/summaries/:summaryId` is not built.
- **The decision:** what a monthly summary contains, how it is generated, and how the Veteran confirms it before it is used anywhere else.
- **Why it waits:** the summary content and its confirmation step are undefined.

### B3. Starting another claim
- **Status:** deferred.
- **Today:** the first claim is created at the end of onboarding. Earlier claims are viewable from the account menu. The list does not ask for a name or explain a cap.
- **What is open:** the workflow to start a second claim, make it the open claim, and the cap-of-12 explanation.
- **Why it waits:** this is a later workflow in the navigation map; the flow has not been designed.

## Known limitations

### B4. HEIC photo reading (handoff 13D)
- **Status:** blocked.
- **Today:** PDF, JPEG, and PNG are read. HEIC is rejected.
- **Why it waits:** the prebuilt `sharp` library decodes AVIF, not iPhone HEIC, so those photos cannot be read safely. Needs a different decode path (a server-side HEIC converter or an image API) before HEIC can be accepted.

## Deferred forms (prepare)

Only the three decision-review drafts are open (Supplemental Claim 20-0995, Higher-Level Review 20-0996, Board Appeal 10182). These form routes exist in the navigation map but are **not open yet**. Each one needs its own data, draft screen, and the "nothing is filed" handling before it is built.

- **B5.** Intent to File — 21-0966.
- **B6.** Initial claim — 21-526EZ.
- **B7.** Unemployability — 21-8940 and 21-4192.
- **B8.** Mental-health event — 21-0781.
- **B9.** Records release — 21-4142 and 21-4142a.
- **B10.** Records request — 20-10206.
- **B11.** Identifiers step — SSN or VA file number, collected only when one of these forms needs it.

## Not-built screens

- **B12.** Package `/review`, `/approve`, and `/download`. The digital package is not generated yet, so reviewing, approving, and re-downloading generated files are not built. Tied to package generation, which is a paid step.
- **B13.** Document `/evidence/:documentId/processing` — a status screen shown while a file is read. Reading works; the dedicated status page is not built.

## Admin area

- **B14.** The hidden web-only admin area (`/admin/...`: support, users, billing, print-orders, forms, processing, security). None of it is built. Role granting stays a script. Mobile shows an unavailable state.

## Commerce and Print & Mail

- **B15.** Entitlements, buying on `/plans`, and the Print & Mail flow (`/package/print/...`). Blocked behind the commerce owner gates (build-progress M11 and handoff 38A–38E). Do not add `purchases_flutter` or `flutter_stripe` before those gates are done. `/plans` stays the only sales page. Expand from handoff section 38 when the gates are complete.
