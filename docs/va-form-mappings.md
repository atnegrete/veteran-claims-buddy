# VA form mappings (v2)

How an official VA PDF becomes a form the Veteran can fill. Nothing here files
with the VA. A generated or previewed PDF is an output artifact, never the
canonical record (handoff 37.10).

## The pipeline

Each form is cached, inspected, mapped, and published. Templates are filled only
in Cloud Functions with `pdf-lib`; the app never fills a PDF.

1. `npm run va:forms:cache -- --project dev --sandbox` — download each official
   revision and write its field inventory to
   `mappings/va-forms/inventory/<form>.json` (`{formNumber, revision, fields}`,
   each field carrying `name`, `type`, and either `maxLength` or `options`). If a
   committed inventory already exists, the run reports revision drift
   (added / removed / retyped fields) so the mapping can be re-validated.
2. `npm run va:forms:automap` — classify every field and write
   `mappings/va-forms/<form>.mapping.json` plus a per-form review report
   `mappings/va-forms/review/<form>.todo.json`.
3. `npm run test:scripts` — `scripts/va_forms_mappings.test.js` guarantees the
   committed mapping equals a fresh automap run, every `pdfField` exists in the
   revision, and every `auto` `canonicalKey` is known.
4. `npm run va:forms:fillcheck` — golden-fill the real cached PDFs with sentinel
   data to catch fields that reject a value.
5. `npm run va:forms:publish-mappings:dev` — publish to `vaFormMappings` on dev.

Because the golden test requires committed mappings to equal `buildMapping`'s
output, **all authoring decisions live in `scripts/va_forms_automap.js`**
(`FORM_RULES`, the classifier), never as hand-edits to the JSON.

## The mapping schema

`vaFormMappings/{form}__{revision}` holds `schemaVersion: 2` and a `fields`
array. Every fillable field is listed. Each field has:

- `pdfField` — the exact AcroForm field name in that revision.
- `label` — a human label. For `auto` fields this is the clean canonical label
  (shown via the group, not the raw field name).
- `type` — `text`, `date`, `checkbox`, or `radio`.
- `group` — the logical value this field belongs to. Fields that share a group
  are a single editor input that fills every matching PDF field (for example the
  three SSN boxes share `vet.ssn`). For `auto` fields the group is the base
  canonical key.
- `source`:
  - `auto` — a value we are certain of, supplied by a `canonicalKey` from the
    Veteran's saved data. Only the Veteran/claimant/patient's own identity is
    ever auto-filled.
  - `ask` — a blank the Veteran fills in the editor.
  - `constant` — a fixed `constantValue`.
  - `dev` — a signature or office/VA-use box the Veteran never fills. Hidden from
    the editor; shown only in the dev PDF-key panel.
- `canonicalKey` — present for `auto`. May be a base key (`vet.email`) or a
  derived split (`vet.ssnArea`); the split is computed deterministically by
  `deriveCanonicalValues`.
- `options` / `maxLength` — read from the AcroForm. A max-length is never
  invented; the editor and the Firestore rule reuse the field's own limit.
- `required` — whether a final PDF cannot be generated without this value.

## Authoring a form (the owner-question loop)

When a new revision comes in, or a form is authored for the first time:

1. Cache and automap. The classifier auto-fills only high-certainty Veteran
   identity. Everything else fillable becomes an `ask` field and is listed in
   `mappings/va-forms/review/<form>.todo.json`.
2. Read the review report. For any field that should actually be auto-filled from
   saved data, add a rule to `FORM_RULES` (or extend the classifier) — never edit
   the JSON by hand. For multi-subject forms (witness, dependent, child, spouse,
   provider, employer, representative), confirm the Veteran's data is **not**
   auto-filled into someone else's box; leave those `ask`.
3. Re-run automap, the script test, and fillcheck. Publish to dev.

When a field is genuinely uncertain, ask the owner directly rather than guessing.

## What actually fills a PDF

The mapping still lists every field (`auto`, `ask`, `constant`, `dev`) so a
revision can be reviewed and a debug build can show the raw keys. The product
fills only three things:

- `auto` — a certain canonical identity or service value, including derived
  splits (SSN, phone, date of birth).
- `constant` — a fixed value named in the mapping.
- A per-form **section builder** in `functions/form_sections.js`. The first one
  is 21-526EZ Section V: one row per claimed condition. `CURRENTDISABILITY[i]`
  is the issue name. The explanation cell is the saved connection notes and
  in-service or nexus evidence, unless the Veteran reviewed an AI draft
  (`packageForms.sectionDrafts`, keyed by claim-issue id). The began-or-worsened
  date is left blank because the claim does not store it.

`ask` and `dev` fields are left blank. There is no generic fill form and no
per-form override map. A correction to name, SSN, or phone is made in Profile
or Identifiers and then fills every form. 21-0966 leaves the non-veteran
claimant section blank. Its Yes or No for "Have you ever filed a VA claim?"
comes from Case Info. The Veteran's VA file number on that form is filled
only when the answer is Yes. The claimant's file-number box stays blank.
The download dialog can override the Veteran name and
Social Security number for that one file; the number from the dialog is not
saved. A `role` on a field names the box that override writes (signature, date
signed, or the Veteran SSN boxes).

`previewForm` renders a watermarked, flattened preview and does not throw when
a required auto field is still blank. `generateForm` uses the same fill and
refuses only when a required auto or constant field is still blank.
`draftDisabilityExplanation` drafts one Section V explanation from the facts
already saved on that condition.
