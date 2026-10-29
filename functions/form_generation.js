const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { assertEnrollmentConfirmed } = require("./auth_state");
const { buildSections, sectionDraftsFrom } = require("./form_sections");

// Server-side form resolution + pdf-lib fill (handoff 37.10-37.12, 37.24). The
// canonical data flows into the PDF; the PDF never becomes the database. A
// generated artifact is an output, never the canonical record. This runs once
// an official revision template has been imported (owner gate M13 / F3).

function str(value) {
  return typeof value === "string" ? value.trim() : "";
}

// First token is the first name, last token is the last name, anything between
// is the middle. A single token is the last name only. Mirrors splitLegalName
// in app/lib/forms/canonical_profile.dart.
function splitLegalName(fullName) {
  const name = str(fullName);
  if (!name) return {};
  const parts = name.split(/\s+/);
  if (parts.length === 1) return { last: parts[0] };
  return {
    first: parts[0],
    middle: parts.slice(1, -1).join(" "),
    last: parts[parts.length - 1],
  };
}

// The name on a form is the first, middle, and last name saved for forms.
function legalNameFromDocs(identifiers = {}) {
  return {
    first: str(identifiers.legalFirstName),
    middle: str(identifiers.legalMiddleName),
    last: str(identifiers.legalLastName),
  };
}

// Pure: assemble canonical values from the Veteran's stored docs. Mirrors
// app/lib/forms/canonical_profile.dart so the preview and the PDF agree.
function canonicalFromDocs({ identifiers = {}, user = {}, service = {} }) {
  const values = {};
  function put(key, value) {
    const text = str(value);
    if (text) values[key] = text;
  }
  const legal = legalNameFromDocs(identifiers);
  put("vet.legalFirstName", legal.first);
  put("vet.legalMiddleName", legal.middle);
  put("vet.legalLastName", legal.last);
  put("vet.dateOfBirth", identifiers.dateOfBirth);
  put("vet.ssn", identifiers.ssn);
  put("vet.vaFileNumber", identifiers.vaFileNumber);
  // 21-0966 item 3. "1" is Yes (an earlier claim). "2" is No (this is the
  // first claim). Absent when Case Info has not been answered. Item 4 on
  // that form is written only when the answer is Yes; other forms keep
  // using vet.vaFileNumber.
  if (user.firstVaDisabilityClaim === false) {
    values["vet.priorVaClaim"] = "1";
    put("vet.priorClaimFileNumber", identifiers.vaFileNumber);
  } else if (user.firstVaDisabilityClaim === true) {
    values["vet.priorVaClaim"] = "2";
  }
  put("vet.mailingStreet", identifiers.mailingStreet);
  put("vet.mailingUnit", identifiers.mailingUnit);
  put("vet.mailingCity", identifiers.mailingCity);
  put("vet.mailingState", identifiers.mailingState);
  put("vet.mailingZip", identifiers.mailingZip);
  put("vet.phone", identifiers.phone);
  put("vet.email", identifiers.email || user.email);
  put("service.branch", service.branch);
  put("service.entryDate", service.entryDate);
  put("service.separationDate", service.separationDate);
  Object.assign(values, deriveCanonicalValues(values));
  return values;
}

// Pure: derive the split sub-values official PDFs need (SSN into three boxes,
// date of birth into month/day/year, phone into area/prefix/line, middle
// initial). Mirrors deriveCanonicalValues in app/lib/forms/canonical_profile.dart
// so the preview and the generated PDF agree. A sub-value is only produced when
// its base value is well-formed; a malformed value yields nothing.
function deriveCanonicalValues(values) {
  const out = {};
  const middle = str(values["vet.legalMiddleName"]);
  if (middle) out["vet.legalMiddleInitial"] = middle.slice(0, 1).toUpperCase();

  const ssn = str(values["vet.ssn"]).replace(/\D/g, "");
  if (ssn.length === 9) {
    out["vet.ssnArea"] = ssn.slice(0, 3);
    out["vet.ssnGroup"] = ssn.slice(3, 5);
    out["vet.ssnSerial"] = ssn.slice(5, 9);
  }

  const dob = str(values["vet.dateOfBirth"]);
  const dobMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dob);
  if (dobMatch) {
    out["vet.dobYear"] = dobMatch[1];
    out["vet.dobMonth"] = dobMatch[2];
    out["vet.dobDay"] = dobMatch[3];
  }

  const phone = str(values["vet.phone"]).replace(/\D/g, "");
  const national = phone.length === 11 && phone.startsWith("1") ? phone.slice(1) : phone;
  if (national.length === 10) {
    out["vet.phoneAreaCode"] = national.slice(0, 3);
    out["vet.phonePrefix"] = national.slice(3, 6);
    out["vet.phoneLine"] = national.slice(6, 10);
    out["vet.phoneUsDashes"] = `${national.slice(0, 3)}-${national.slice(3, 6)}-${national.slice(6, 10)}`;
  }

  const first = str(values["vet.legalFirstName"]);
  const last = str(values["vet.legalLastName"]);
  if (first && last) {
    out["vet.fullName"] = [first, middle || null, last].filter(Boolean).join(" ");
  }

  if (dobMatch) out["vet.dobUsSlashes"] = `${dobMatch[2]}/${dobMatch[3]}/${dobMatch[1]}`;

  const zip = str(values["vet.mailingZip"]);
  const zipMatch = /^(\d{5})(?:-(\d{4}))?$/.exec(zip);
  if (zipMatch) {
    out["vet.mailingZip5"] = zipMatch[1];
    if (zipMatch[2]) out["vet.mailingZip4"] = zipMatch[2];
  }

  return out;
}

function fieldSource(field) {
  if (field.source) return field.source;
  if (field.canonicalKey) return "auto";
  if (field.constantValue != null && field.constantValue !== "") return "constant";
  return "ask";
}

function clipText(value, maxLength) {
  if (typeof maxLength === "number" && maxLength >= 0 && value.length > maxLength) {
    return value.slice(0, maxLength);
  }
  return value;
}

function fieldParent(pdfField) {
  const dot = pdfField.lastIndexOf(".");
  return dot === -1 ? "" : pdfField.slice(0, dot);
}

// Boxes that share a canonical value and sit on the same parent are one
// continuation (the email split across two 20-character lines). The same
// value on a later page is a repeat, so each page gets the whole value.
function placeText(fields, raw) {
  const value = str(raw);
  const pieces = new Map();
  if (!value) return pieces;
  const buckets = new Map();
  for (const field of fields) {
    const key = fieldParent(field.pdfField);
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(field);
  }
  for (const group of buckets.values()) {
    const split =
      group.length > 1 &&
      group.every((field) => typeof field.maxLength === "number" && field.maxLength > 0) &&
      group.some((field) => value.length > field.maxLength);
    if (split) {
      let rest = value;
      for (const field of group) {
        if (!rest) break;
        const piece = rest.slice(0, field.maxLength);
        rest = rest.slice(piece.length);
        if (piece) pieces.set(field.pdfField, piece);
      }
    } else {
      for (const field of group) {
        const piece = clipText(value, field.maxLength);
        if (piece) pieces.set(field.pdfField, piece);
      }
    }
  }
  return pieces;
}

function missingField(field) {
  return {
    group: field.group || null,
    canonicalKey: field.canonicalKey || null,
    label: field.label || field.pdfField,
  };
}

// Pure: fill only `auto` (a certain canonical value) and `constant` fields.
// `ask` and `dev` fields are left blank; the Veteran does not type into them.
// Derived splits (SSN, phone, date of birth) are recomputed from the base
// values already on the profile. Required gaps are reported only for auto and
// constant fields. Text that is longer than a box is clipped, or continued
// into the next box that shares that value on the same parent.
function resolveFieldValues(mapping, base) {
  const fields = Array.isArray(mapping.fields) ? mapping.fields : [];
  const eff = { ...base, ...deriveCanonicalValues(base) };
  const values = {};
  const missing = [];
  const textGroups = new Map();
  for (const field of fields) {
    const source = fieldSource(field);
    if (source === "ask" || source === "dev") continue;
    const type = field.type || "text";
    if (source === "constant") {
      const value = clipText(
        field.constantValue != null && field.constantValue !== ""
          ? String(field.constantValue)
          : "",
        type === "checkbox" || type === "radio" ? undefined : field.maxLength,
      );
      if (!value && field.required) missing.push(missingField(field));
      if (value) values[field.pdfField] = { value, type };
      continue;
    }
    const full = field.canonicalKey ? str(eff[field.canonicalKey]) : "";
    if (!full && field.required) missing.push(missingField(field));
    if (!full) continue;
    if (type === "checkbox" || type === "radio") {
      values[field.pdfField] = { value: full, type };
      continue;
    }
    if (!textGroups.has(field.canonicalKey)) textGroups.set(field.canonicalKey, []);
    textGroups.get(field.canonicalKey).push(field);
  }
  for (const group of textGroups.values()) {
    const full = str(eff[group[0].canonicalKey]);
    for (const [pdfField, piece] of placeText(group, full)) {
      const field = group.find((item) => item.pdfField === pdfField);
      values[pdfField] = { value: piece, type: field.type || "text" };
    }
  }
  return { values, missing };
}

// Writes a section builder's pdfField -> text map over the resolved values.
function mergeSectionValues(resolved, sections) {
  for (const [pdfField, raw] of Object.entries(sections || {})) {
    const value = str(raw);
    if (value) resolved.values[pdfField] = { value, type: "text" };
  }
  return resolved;
}

function isChecked(value) {
  return value && value !== "0" && value.toLowerCase() !== "false" && value.toLowerCase() !== "off";
}

function writeText(field, text) {
  const max = field.getMaxLength();
  const clipped = typeof max === "number" && text.length > max ? text.slice(0, max) : text;
  if (!clipped) return;
  field.setText(clipped);
}

// Pure-ish: write one resolved value into the form, tolerating fields the
// template lacks or shapes it cannot accept. Filling must never throw, so a
// preview always renders. Text is clipped to the box before it is written.
function setField(form, name, entry) {
  try {
    if (entry.type === "checkbox") {
      const box = form.getCheckBox(name);
      if (isChecked(entry.value)) box.check();
      else box.uncheck();
    } else if (entry.type === "radio") {
      const field = form.getFieldMaybe
        ? form.getFieldMaybe(name)
        : form.getField(name);
      if (field && typeof field.select === "function") field.select(entry.value);
    } else {
      writeText(form.getTextField(name), entry.value);
    }
  } catch (_) {
    // A field the mapping names but the template lacks, or a value the field
    // will not accept, is skipped. The golden test (F4) guarantees the mapping
    // matches the revision.
  }
}

// Stamps a diagonal, semi-transparent banner across every page so a preview can
// never be mistaken for a submittable form.
async function watermarkPdf(bytes, label = "PREVIEW \u2014 NOT FOR SUBMISSION") {
  const { PDFDocument, StandardFonts, rgb, degrees } = require("pdf-lib");
  const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
  const font = await doc.embedFont(StandardFonts.HelveticaBold);
  for (const page of doc.getPages()) {
    const { width, height } = page.getSize();
    const size = Math.max(18, Math.min(width, height) * 0.045);
    const textWidth = font.widthOfTextAtSize(label, size);
    page.drawText(label, {
      x: width / 2 - (textWidth / 2) * Math.cos(Math.PI / 4),
      y: height / 2 - (textWidth / 2) * Math.sin(Math.PI / 4),
      size,
      font,
      color: rgb(0.7, 0.1, 0.1),
      rotate: degrees(45),
      opacity: 0.25,
    });
  }
  return doc.save({ updateFieldAppearances: false });
}

function appearanceIsUsable(widget) {
  try {
    widget.getNormalAppearance();
    return true;
  } catch (_) {
    return false;
  }
}

// Official VA signature widgets often have an appearance dictionary with no
// /N entry. pdf-lib throws "Unexpected N type: undefined" as soon as it tries
// to redraw every field, and the text we just set is never painted. Those
// signatures are removed first so the remaining fields can be drawn.
function removeUnusableSignatures(doc) {
  const { PDFSignature } = require("pdf-lib");
  const form = doc.getForm();
  const pages = doc.getPages();
  const signatures = form
    .getFields()
    .filter((field) => field instanceof PDFSignature);
  for (const field of signatures) {
    const widgets = field.acroField.getWidgets();
    if (widgets.length > 0 && widgets.every(appearanceIsUsable)) continue;
    for (const widget of widgets) {
      const ref = doc.context.getObjectRef(widget.dict);
      if (!ref) continue;
      for (const page of pages) page.node.removeAnnot(ref);
    }
    if (field.ref) {
      for (const page of pages) page.node.removeAnnot(field.ref);
    }
    form.acroForm.removeField(field.acroField);
  }
}

// One bad widget must not stop the fields that did accept a value. Each dirty
// field is drawn on its own with an embedded font, which is what the flattened
// page actually shows.
function paintAppearances(form, font, fontForField) {
  for (const field of form.getFields()) {
    if (!field.needsAppearancesUpdate()) continue;
    const face = fontForField ? fontForField(field) : font;
    try {
      field.defaultUpdateAppearances(face || font);
    } catch (_) {
      // This widget cannot be drawn. The fields that can still are.
    }
  }
}

async function embedBodyAndScript(doc) {
  const { StandardFonts } = require("pdf-lib");
  const body = await doc.embedFont(StandardFonts.Helvetica);
  const script = await doc.embedFont(StandardFonts.TimesRomanItalic);
  return { body, script };
}

function fontChooser(signatureFields, fonts) {
  return (field) => {
    const name = typeof field.getName === "function" ? field.getName() : "";
    return signatureFields.has(name) ? fonts.script : fonts.body;
  };
}

// A signature widget is not a text field. Remember its page and rectangle
// before it is removed, then paint the typed legal name into that box.
function signaturePlacements(doc, signatureFields, resolved) {
  if (!signatureFields || signatureFields.size === 0) return [];
  const { PDFSignature } = require("pdf-lib");
  const values = resolved && resolved.values ? resolved.values : {};
  let form;
  try {
    form = doc.getForm();
  } catch (_) {
    return [];
  }
  const pages = doc.getPages();
  const placements = [];
  for (const field of form.getFields()) {
    if (!(field instanceof PDFSignature)) continue;
    let name = "";
    try {
      name = field.getName();
    } catch (_) {
      continue;
    }
    if (!signatureFields.has(name)) continue;
    const text = str(values[name] && values[name].value);
    if (!text) continue;
    for (const widget of field.acroField.getWidgets()) {
      placements.push({
        pageIndex: pageIndexForWidget(doc, pages, widget),
        rect: widget.getRectangle(),
        text,
      });
    }
  }
  return placements;
}

function pageIndexForWidget(doc, pages, widget) {
  const pageRef = typeof widget.P === "function" ? widget.P() : undefined;
  if (pageRef) {
    const key = pageRef.toString();
    for (let i = 0; i < pages.length; i++) {
      if (pages[i].ref && pages[i].ref.toString() === key) return i;
    }
  }
  const ref = doc.context.getObjectRef(widget.dict);
  if (!ref) return 0;
  const key = ref.toString();
  for (let i = 0; i < pages.length; i++) {
    const annots = pages[i].node.Annots();
    if (!annots) continue;
    for (let j = 0; j < annots.size(); j++) {
      const annot = annots.get(j);
      if (annot && annot.toString() === key) return i;
    }
  }
  return 0;
}

function drawSignatureNames(doc, placements, font) {
  if (!placements.length || !font) return;
  const { rgb } = require("pdf-lib");
  const pages = doc.getPages();
  const ink = rgb(0, 0, 0);
  for (const placement of placements) {
    const page = pages[placement.pageIndex];
    const rect = placement.rect;
    if (!page || !rect || rect.width < 4 || rect.height < 4) continue;
    const inset = 4;
    const maxWidth = Math.max(1, rect.width - inset * 2);
    let size = Math.min(16, Math.max(8, rect.height - 6));
    let shown = placement.text;
    while (shown.length > 1 && font.widthOfTextAtSize(shown, size) > maxWidth) {
      if (size > 8) size -= 1;
      else shown = shown.slice(0, -1);
    }
    page.drawText(shown, {
      x: rect.x + inset,
      y: rect.y + Math.max(0, (rect.height - size) / 2),
      size,
      font,
      color: ink,
    });
  }
}

async function fillPdf(templateBytes, resolved, options = {}) {
  const { PDFDocument } = require("pdf-lib");
  const signatureFields = options.signatureFields || new Set();
  const doc = await PDFDocument.load(templateBytes, { ignoreEncryption: true });
  const placements = signaturePlacements(doc, signatureFields, resolved);
  removeUnusableSignatures(doc);
  const form = doc.getForm();
  for (const [name, entry] of Object.entries(resolved.values)) {
    setField(form, name, entry);
  }
  const fonts = await embedBodyAndScript(doc);
  paintAppearances(form, fonts.body, fontChooser(signatureFields, fonts));
  drawSignatureNames(doc, placements, fonts.script);
  const filled = await doc.save({ updateFieldAppearances: false });
  let flattened = filled;
  try {
    const flatDoc = await PDFDocument.load(filled, { ignoreEncryption: true });
    removeUnusableSignatures(flatDoc);
    const flatFonts = await embedBodyAndScript(flatDoc);
    const flatForm = flatDoc.getForm();
    paintAppearances(flatForm, flatFonts.body, fontChooser(signatureFields, flatFonts));
    flatForm.flatten({ updateFieldAppearances: false });
    flattened = await flatDoc.save({ updateFieldAppearances: false });
  } catch (_) {
    // The filled form still previews when a template cannot be flattened.
    flattened = filled;
  }
  if (options.watermark) flattened = await watermarkPdf(flattened);
  return { filled, flattened };
}

function projectBucket() {
  const project =
    process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || "";
  return `${project}.firebasestorage.app`;
}

async function loadMapping(db, formNumber) {
  const snap = await db
    .collection("vaFormMappings")
    .where("formNumber", "==", formNumber)
    .get();
  if (snap.empty) return null;
  // Newest revision wins until catalog pinning (F5) governs selection.
  const docs = snap.docs.sort((a, b) =>
    str(b.data().revisionId).localeCompare(str(a.data().revisionId)),
  );
  return { id: docs[0].id, ...docs[0].data() };
}

async function loadTemplate(db, storage, formNumber, revisionId) {
  const revSnap = await db
    .collection("vaFormRevisions")
    .where("formNumber", "==", formNumber)
    .where("revision", "==", revisionId)
    .limit(1)
    .get();
  if (revSnap.empty) return null;
  const path = str(revSnap.docs[0].data().storagePath);
  if (!path) return null;
  const file = storage.bucket(projectBucket()).file(path);
  const [bytes] = await file.download();
  return bytes;
}

async function loadCanonical(db, uid, caseId) {
  const [idDoc, userDoc, periodSnap] = await Promise.all([
    db.doc(`users/${uid}/identifiers/profile`).get(),
    db.doc(`users/${uid}`).get(),
    db.collection(`users/${uid}/servicePeriods`).get(),
  ]);
  const periods = periodSnap.docs.map((doc) => doc.data());
  const first = periods[0] || {};
  return canonicalFromDocs({
    identifiers: idDoc.exists ? idDoc.data() : {},
    user: userDoc.exists ? userDoc.data() : {},
    service: {
      branch: first.branch,
      entryDate: first.startDate,
      separationDate: periods.length ? periods[periods.length - 1].endDate : "",
    },
  });
}

// The claim's conditions, each one's connection notes, and the evidence notes
// tied to it. Section builders turn this into repeating PDF rows.
async function loadClaimContext(db, uid, caseId) {
  const [issueSnap, linkSnap] = await Promise.all([
    db.collection(`users/${uid}/conditions`).where("activeCaseId", "==", caseId).get(),
    db.collection(`users/${uid}/evidenceLinks`).get(),
  ]);
  const linksByIssue = {};
  for (const doc of linkSnap.docs) {
    const data = doc.data();
    const issueId = str(data.conditionId);
    if (!issueId) continue;
    if (!linksByIssue[issueId]) linksByIssue[issueId] = [];
    linksByIssue[issueId].push({
      evidenceType: data.evidenceType,
      summary: data.summary,
    });
  }
  const issues = [];
  const theoriesByIssue = {};
  for (const doc of issueSnap.docs) {
    issues.push({ id: doc.id, displayName: str(doc.data().displayName) });
    const theories = await db
      .collection(`users/${uid}/conditions/${doc.id}/theories`)
      .get();
    theoriesByIssue[doc.id] = theories.docs.map((theory) => ({
      type: theory.data().type,
      summary: theory.data().summary,
    }));
  }
  return { issues, theoriesByIssue, linksByIssue };
}

function resolvedForPackage(mapping, pkg, canonical, claim, liveDrafts) {
  const baseValues = { ...canonical };
  if (str(pkg.statementBody)) baseValues["statement.body"] = str(pkg.statementBody);
  const resolved = resolveFieldValues(mapping, baseValues);
  const drafts = sectionDraftsFrom(pkg.sectionDrafts, liveDrafts);
  const sections = buildSections(pkg.formNumber, { ...claim, sectionDrafts: drafts });
  return mergeSectionValues(resolved, sections);
}

async function requireReady(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const user = await getAuth().getUser(request.auth.uid);
  if (!assertEnrollmentConfirmed(user).ok) {
    throw new HttpsError(
      "failed-precondition",
      "Verified email and an enrolled text-message check are required.",
    );
  }
  return request.auth.uid;
}

async function generateFormHandler(request, deps = {}) {
  const uid = await (deps.requireReady ?? requireReady)(request);
  const packageFormId = str(request.data?.packageFormId);
  if (!packageFormId) {
    throw new HttpsError("invalid-argument", "That form could not be opened.");
  }
  const db = deps.firestore ?? getFirestore();
  const storage = deps.storage ?? getStorage();
  const pkgRef = db.doc(`users/${uid}/packageForms/${packageFormId}`);
  const pkgDoc = await pkgRef.get();
  if (!pkgDoc.exists) {
    throw new HttpsError("not-found", "That form is not in your package.");
  }
  const pkg = pkgDoc.data();
  const mapping = await (deps.loadMapping ?? loadMapping)(db, pkg.formNumber);
  if (!mapping) {
    throw new HttpsError(
      "failed-precondition",
      "This form is not ready to generate yet.",
    );
  }
  const canonical = await (deps.loadCanonical ?? loadCanonical)(db, uid, pkg.caseId);
  const claim = await (deps.loadClaimContext ?? loadClaimContext)(db, uid, pkg.caseId);
  const resolved = resolvedForPackage(mapping, pkg, canonical, claim);
  if (resolved.missing.length > 0) {
    throw new HttpsError("failed-precondition", "Some required fields are still missing.", {
      missing: resolved.missing,
    });
  }
  const templateBytes = await (deps.loadTemplate ?? loadTemplate)(
    db,
    storage,
    pkg.formNumber,
    mapping.revisionId,
  );
  if (!templateBytes) {
    throw new HttpsError("failed-precondition", "The form template is not imported yet.");
  }
  const { filled, flattened } = await (deps.fillPdf ?? fillPdf)(templateBytes, resolved);
  const generatedRef = db.collection(`users/${uid}/generatedForms`).doc();
  const generatedFormId = generatedRef.id;
  const bucket = storage.bucket(projectBucket());
  const base = `users/${uid}/generatedForms/${generatedFormId}`;
  await Promise.all([
    bucket.file(`${base}/filled.pdf`).save(Buffer.from(filled), {
      contentType: "application/pdf",
    }),
    bucket.file(`${base}/filled-flattened.pdf`).save(Buffer.from(flattened), {
      contentType: "application/pdf",
    }),
  ]);
  await generatedRef.set({
    caseId: pkg.caseId,
    packageFormId,
    formNumber: pkg.formNumber,
    revisionId: mapping.revisionId,
    mappingId: mapping.id,
    fieldCount: Object.keys(resolved.values).length,
    status: "generated",
    schemaVersion: 1,
    createdAt: FieldValue.serverTimestamp(),
  });
  await pkgRef.set(
    { generatedFormId, status: "ready", updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { generatedFormId, revisionId: mapping.revisionId };
}

const generateForm = onCall(
  { timeoutSeconds: 300, memory: "1GiB" },
  (request) => generateFormHandler(request),
);

// Renders a watermarked, flattened preview of a form filled from saved identity
// data, the drafted statement, and any per-form section drafts (including the
// editor's current unsaved drafts). The preview is a disposable artifact, not
// the generated submission. It never throws on missing required fields.
async function previewFormHandler(request, deps = {}) {
  const uid = await (deps.requireReady ?? requireReady)(request);
  const packageFormId = str(request.data?.packageFormId);
  if (!packageFormId) {
    throw new HttpsError("invalid-argument", "That form could not be opened.");
  }
  const db = deps.firestore ?? getFirestore();
  const storage = deps.storage ?? getStorage();
  const pkgDoc = await db.doc(`users/${uid}/packageForms/${packageFormId}`).get();
  if (!pkgDoc.exists) {
    throw new HttpsError("not-found", "That form is not in your package.");
  }
  const pkg = pkgDoc.data();
  const mapping = await (deps.loadMapping ?? loadMapping)(db, pkg.formNumber);
  if (!mapping) {
    throw new HttpsError("failed-precondition", "This form is not ready to preview yet.");
  }
  const canonical = await (deps.loadCanonical ?? loadCanonical)(db, uid, pkg.caseId);
  const claim = await (deps.loadClaimContext ?? loadClaimContext)(db, uid, pkg.caseId);
  const liveDrafts =
    request.data?.sectionDrafts && typeof request.data.sectionDrafts === "object"
      ? request.data.sectionDrafts
      : {};
  const resolved = resolvedForPackage(mapping, pkg, canonical, claim, liveDrafts);
  const templateBytes = await (deps.loadTemplate ?? loadTemplate)(
    db,
    storage,
    pkg.formNumber,
    mapping.revisionId,
  );
  if (!templateBytes) {
    throw new HttpsError("failed-precondition", "The form template is not imported yet.");
  }
  const { flattened } = await (deps.fillPdf ?? fillPdf)(templateBytes, resolved, {
    watermark: true,
  });
  const storagePath = `users/${uid}/formPreviews/${packageFormId}.pdf`;
  await storage
    .bucket(projectBucket())
    .file(storagePath)
    .save(Buffer.from(flattened), { contentType: "application/pdf" });
  return {
    storagePath,
    pdfBase64: Buffer.from(flattened).toString("base64"),
    fieldCount: Object.keys(resolved.values).length,
    missing: resolved.missing,
  };
}

const previewForm = onCall(
  { timeoutSeconds: 120, memory: "1GiB" },
  (request) => previewFormHandler(request),
);

const SSN_PATTERN = /^\d{3}-\d{2}-\d{4}$/;

function applyDownloadIdentity(base, { legalName, ssn }) {
  const next = { ...base };
  const split = splitLegalName(legalName);
  if (split.first) next["vet.legalFirstName"] = split.first;
  if (split.last) next["vet.legalLastName"] = split.last;
  if (split.middle) next["vet.legalMiddleName"] = split.middle;
  else if (split.first || split.last) delete next["vet.legalMiddleName"];
  if (ssn) next["vet.ssn"] = ssn;
  return next;
}

function signDateParts(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(str(value))) return null;
  const [year, month, day] = value.split("-").map((part) => Number(part));
  const stamp = Date.UTC(year, month - 1, day);
  if (Number.isNaN(stamp)) return null;
  const now = new Date();
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  if (Math.abs(stamp - today) > 36 * 60 * 60 * 1000) return null;
  return {
    day: String(day).padStart(2, "0"),
    month: String(month).padStart(2, "0"),
    year: String(year),
  };
}

function utcTodayParts() {
  const now = new Date();
  return {
    day: String(now.getUTCDate()).padStart(2, "0"),
    month: String(now.getUTCMonth() + 1).padStart(2, "0"),
    year: String(now.getUTCFullYear()),
  };
}

// Writes the dialog's SSN into the boxes this form names, and, when signed,
// the name into the signature box and today's date into the date boxes.
function applyDownloadRoles(fields, resolved, { signed, signedOn, fullName, ssn }) {
  const values = { ...resolved.values };
  const digits = str(ssn).replace(/\D/g, "");
  const date = signed ? signedOn || utcTodayParts() : null;
  for (const field of fields || []) {
    const role = field.role;
    if (!role) continue;
    if (digits.length === 9) {
      const part =
        role === "veteranSsnArea"
          ? digits.slice(0, 3)
          : role === "veteranSsnGroup"
            ? digits.slice(3, 5)
            : role === "veteranSsnSerial"
              ? digits.slice(5, 9)
              : null;
      if (part) values[field.pdfField] = { value: part, type: "text" };
    }
    if (!signed) continue;
    if (role === "signature" && fullName) {
      values[field.pdfField] = { value: fullName, type: "text" };
    }
    const datePart =
      role === "signedDay"
        ? date.day
        : role === "signedMonth"
          ? date.month
          : role === "signedYear"
            ? date.year
            : null;
    if (datePart) values[field.pdfField] = { value: datePart, type: "text" };
  }
  return { ...resolved, values };
}

function signatureFieldNames(fields) {
  return new Set(
    (fields || []).filter((field) => field.role === "signature").map((field) => field.pdfField),
  );
}

async function caseDownloadUnlocked(db, uid, caseId) {
  const premiumSnap = await db.doc(`users/${uid}/billing/premium`).get();
  const premium = premiumSnap.exists ? premiumSnap.data() : {};
  const until = premium.premiumUntil;
  const untilMs = until && typeof until.toMillis === "function" ? until.toMillis() : 0;
  if (!(untilMs > Date.now())) return false;
  if (premium.source === "subscription") return true;
  const unlock = await db.doc(`users/${uid}/caseUnlocks/${caseId}`).get();
  return unlock.exists;
}

async function downloadFormHandler(request, deps = {}) {
  const uid = await (deps.requireReady ?? requireReady)(request);
  const packageFormId = str(request.data?.packageFormId);
  if (!packageFormId) {
    throw new HttpsError("invalid-argument", "That form could not be opened.");
  }
  const legalName = str(request.data?.legalName);
  if (!legalName || legalName.length > 80) {
    throw new HttpsError("invalid-argument", "Enter your full legal name.");
  }
  const signed = request.data?.signed === true;
  const ssn = str(request.data?.ssn);
  const db = deps.firestore ?? getFirestore();
  const storage = deps.storage ?? getStorage();
  const pkgDoc = await db.doc(`users/${uid}/packageForms/${packageFormId}`).get();
  if (!pkgDoc.exists) {
    throw new HttpsError("not-found", "That form is not in your package.");
  }
  const pkg = pkgDoc.data();
  const mapping = await (deps.loadMapping ?? loadMapping)(db, pkg.formNumber);
  if (!mapping) {
    throw new HttpsError("failed-precondition", "This form is not ready to download yet.");
  }
  const download = mapping.download || {};
  const collect = Array.isArray(download.collect) ? download.collect : [];
  const actions = Array.isArray(download.actions) ? download.actions : [];
  if (download.access !== "free" && download.access !== "premium") {
    throw new HttpsError("failed-precondition", "This form cannot be downloaded yet.");
  }
  if (download.access === "premium") {
    const unlocked = await (deps.caseDownloadUnlocked ?? caseDownloadUnlocked)(
      db,
      uid,
      pkg.caseId,
    );
    if (!unlocked) {
      throw new HttpsError(
        "failed-precondition",
        "Downloading this form needs Premium, or a one-time unlock for this case.",
      );
    }
  }
  if (collect.includes("ssn") && !SSN_PATTERN.test(ssn)) {
    throw new HttpsError("invalid-argument", "Enter the Social Security number as ###-##-####.");
  }
  if (signed && !actions.includes("signed")) {
    throw new HttpsError("failed-precondition", "This form is downloaded without a signature.");
  }
  if (!signed && !actions.includes("unsigned")) {
    throw new HttpsError("failed-precondition", "This form is downloaded with a signature.");
  }
  const canonical = applyDownloadIdentity(
    await (deps.loadCanonical ?? loadCanonical)(db, uid, pkg.caseId),
    { legalName, ssn: collect.includes("ssn") ? ssn : "" },
  );
  const claim = await (deps.loadClaimContext ?? loadClaimContext)(db, uid, pkg.caseId);
  const liveDrafts =
    request.data?.sectionDrafts && typeof request.data.sectionDrafts === "object"
      ? request.data.sectionDrafts
      : {};
  const resolved = applyDownloadRoles(
    mapping.fields,
    resolvedForPackage(mapping, pkg, canonical, claim, liveDrafts),
    {
      signed,
      signedOn: signDateParts(request.data?.signedOn) || utcTodayParts(),
      fullName: legalName,
      ssn: collect.includes("ssn") ? ssn : "",
    },
  );
  const templateBytes = await (deps.loadTemplate ?? loadTemplate)(
    db,
    storage,
    pkg.formNumber,
    mapping.revisionId,
  );
  if (!templateBytes) {
    throw new HttpsError("failed-precondition", "The form template is not imported yet.");
  }
  const { flattened } = await (deps.fillPdf ?? fillPdf)(templateBytes, resolved, {
    watermark: false,
    signatureFields: signed ? signatureFieldNames(mapping.fields) : new Set(),
  });
  return { pdfBase64: Buffer.from(flattened).toString("base64") };
}

const downloadForm = onCall(
  { timeoutSeconds: 120, memory: "1GiB" },
  (request) => downloadFormHandler(request),
);

module.exports = {
  generateForm,
  generateFormHandler,
  previewForm,
  previewFormHandler,
  downloadForm,
  downloadFormHandler,
  canonicalFromDocs,
  deriveCanonicalValues,
  resolveFieldValues,
  mergeSectionValues,
  loadClaimContext,
  applyDownloadIdentity,
  applyDownloadRoles,
  splitLegalName,
  signDateParts,
  fillPdf,
  watermarkPdf,
};
