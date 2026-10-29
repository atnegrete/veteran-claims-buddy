# Nexus knowledge pack

How the nexus engine knows the law and the VA presumptive framework. This is a
curated, versioned reference pack. Nothing here files with the VA, and nothing
here is a signed medical or legal opinion.

## Where it lives

`functions/knowledge/nexus/`. It is bundled with Cloud Functions and `require`d
at runtime by `functions/nexus_knowledge.js` (deterministic, no external
calls). It is **not** published to Firestore like the VA form mappings; the
owner picked a repo-maintained pack, so a content change ships with a Functions
deploy.

```
functions/knowledge/nexus/
  manifest.json            version + reviewedOn + changelog
  standards.json           the medical / legal standards
  letter-patterns.json     the required letter structure per nexus kind
  presumptive/*.json       one presumptive pathway per file
  conditions/*.json        one curated per-condition citation set per file
```

## The engine

The Nexus Letters flow is a short AI interview that fills the gaps, then two
generated PDFs, then a continuous "ask the AI to tweak it" loop. It is split
across three modules that all read this pack:

- `functions/nexus_letter.js` loads the condition's connection notes, evidence,
  service periods, deployments, exposures, and MOS (`loadNexusContext`), and
  finds presumptive pathways the Veteran plausibly meets (`matchPresumptive`).
- `functions/nexus_interview.js` (`nexusInterviewStep`) walks the per-kind
  `interviewSlots`, skips any slot already answered by saved facts, asks Gemini
  to phrase one grounded question at a time, and stores the transcript at
  `users/{uid}/conditions/{issueId}/nexusLetter/current`. The interview is
  complete when every un-seeded slot has an answer.
- `functions/nexus_generate.js` (`generateNexusLetters`, `reviseNexusLetter`,
  `downloadNexusLetter`) drafts structured sections for both letters in one
  grounded Gemini call, renders them with `functions/nexus_letter_pdf.js`,
  re-renders one letter when the Veteran asks for a natural-language tweak, and
  returns a clean print copy on demand. The short interview uses a fast model and
  the drafting uses a stronger one; both are set in `functions/nexus_shared.js`
  and are overridable with `NEXUS_INTERVIEW_MODEL`, `NEXUS_DRAFT_MODEL`, and
  `NEXUS_DRAFT_TEMPERATURE`. These are optional; the defaults apply when unset.
  To override, copy `functions/.env.example` to a git-ignored `functions/.env`
  (all projects) or `functions/.env.<projectId>` (one project), uncomment the
  lines you want, and redeploy functions. If `gemini-2.5-pro` is not enabled on
  a project, drafting falls back to the interview model automatically.
- `functions/nexus_letter.js` `conditionCitationsFor` matches the claimed
  condition to a curated per-condition citation set and returns its vetted legal
  and medical citations for the server to inject.

Both PDFs render in two modes. The on-screen preview is watermarked and, on the
doctor draft, shows faint "to be completed by the physician" placeholders. The
downloadable copy (`downloadNexusLetter`) is a clean, unwatermarked, print-mode
copy that replaces those placeholders with blank writing space. Both carry a
"Subject: Nexus letter ..." line and the Veteran's branch of service.

The two PDFs:

- **Doctor draft.** A scaffold letter titled "Nexus Letter" the physician
  reviews, completes, and signs only if they agree. It opens with a records line,
  then an organized third-person **Clinical summary** and the reported in-service
  history. Current diagnosis and Medical rationale are left as blank writing
  space (a faint placeholder in the preview only). The Opinion is a check-one
  pair of yes/no lines ("at least as likely as not" or "less likely than not")
  with a comments line, never asserted by the app. An appended "SUGGESTED DRAFT -
  OPTIONAL" page carries AI-proposed diagnosis and rationale the physician may
  adopt, plus a "Relevant medical literature" list drawn from the curated
  per-condition citation set when the condition matches one.
- **Veteran statement.** A plain-language statement the Veteran signs. A **Legal
  & Medical Citations** section lists each authority (the citation in regular
  type, a short description in italics beneath it), de-duplicated so no authority
  repeats; it combines the general legal standards the model selected with the
  matched condition's curated legal and medical citations. A **Closing Remarks**
  paragraph summarizes the claim, asks for fair and thorough consideration, and
  affirms the statements are true. It states no medical diagnosis, except where
  the Veteran's own answers report one ("my doctor told me ...").

Citations are never written by the model. The server attaches every citation
string from this pack (the general standards and the curated per-condition sets),
so the same claim yields the same citations every run and nothing is fabricated.

Neither PDF is a signed medical or legal opinion, and nothing here files with
the VA.

## Schemas

### manifest.json

- `version` — semantic version, bumped on every content change.
- `reviewedOn` — the date the pack was last reviewed end to end.
- `changelog` — `[{ version, date, note }]`, newest first.

### standards.json

`{ standards: [ { id, label, citation, plainText, lastReviewed, opinionTemplate? } ] }`

- `id` — referenced from `letter-patterns.json`.
- `citation` — the statute / regulation / case, quoted verbatim in the brief.
- `plainText` — a plain-language explanation.

### letter-patterns.json

`{ patterns: { direct|secondary|aggravation|supplemental: { label, standardIds[], basisDescription, interviewSlots[], components[] } } }`

- `standardIds` — must each resolve to a `standards.json` id.
- `basisDescription` — fills `{basis}` in the opinion template.
- `interviewSlots` — the ordered gap questions for this kind
  (`{ id, label, guidance }`). `guidance` tells the model how to phrase the one
  question. A slot is skipped when `functions/nexus_interview.js` can seed it
  from saved facts (for example, `inServiceEvent` from the saved connection
  note, `treatmentRecords` from evidence links).
- `components` — the ordered required parts of the physician letter
  (`{ id, label, guidance }`). This is the checklist that keeps the letter from
  missing a basic element.

### presumptive/\*.json

`{ id, label, authority, citation, sourceAsOf, qualifyingService: { locations[], dateRanges[{start,end,label}], branches[] }, exposures[], presumptiveConditions[], notes }`

- `citation` and `sourceAsOf` are required on every pathway.
- `exposures` use the app's exposure keys (`burnPit`, `herbicide`, `noise`,
  `radiation`, `solvent`, `asbestos`, `other`).
- `branches` use the app's branch keys; an empty list means any branch.
- `id` is the stable identifier a presumptive theory can store in
  `theories.presumptionRuleId`.

### conditions/\*.json

`{ id, label, matchTerms[], legalCitations: [{ citation, description }], medicalCitations: [{ citation, description, lastVerified }], lastReviewed }`

- Each file is one curated citation set for a claimed condition. Drop a file,
  ship a condition; `functions/nexus_knowledge.js` loads `conditions/` the same
  way it loads `presumptive/`.
- `matchTerms` are free-text aliases; `conditionCitationsFor` matches the claimed
  condition on normalized text (the same loose compare the presumptive matcher
  uses). An unmatched condition still gets the general legal standards.
- `citation` is quoted verbatim in the letters; `description` is the short,
  italicized note of what it supports.
- `legalCitations` are condition-specific regulations or case law (for example
  38 C.F.R. 3.385 for hearing loss and tinnitus). `medicalCitations` are vetted,
  real peer-reviewed references. The model never invents, edits, or selects
  these; the server injects them.

## The update loop (law changes)

1. Edit the relevant file under `functions/knowledge/nexus/`.
2. Set `sourceAsOf` on any changed pathway to the date you confirmed it.
3. Bump `manifest.version` and add a `changelog` entry.
4. Run `npm test` in `functions/`. `nexus_knowledge.test.js` fails if a file
   breaks schema, a referenced standard id does not resolve, a pathway is
   missing `citation`/`sourceAsOf`, or a condition string is empty.
5. Deploy Functions to dev.

Keep condition lists representative and current; the pack is a drafting aid, not
a substitute for the VA's published presumptive lists. The veteran statement
always tells the Veteran to check current VA rules.

## Adding a condition citation set

1. Add `conditions/<slug>.json` with `matchTerms`, `legalCitations`, and
   `medicalCitations`.
2. Every medical reference must be real and verified by a subject-matter expert
   before it ships. Do not generate citations; set `lastVerified` on each.
3. Bump `manifest.version`, add a changelog entry, run `npm test` in
   `functions/`, and deploy Functions to dev.

Only hearing loss and tinnitus is seeded today. A later, separate layer may let
the model also look up new, claim-specific citations with real grounding (Vertex
grounding with Google Search); until that lands every citation comes from this
pack so nothing is fabricated.
