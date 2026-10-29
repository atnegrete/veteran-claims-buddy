const test = require("node:test");
const assert = require("node:assert/strict");
const {
  applyDownloadRoles,
  canonicalFromDocs,
  deriveCanonicalValues,
  resolveFieldValues,
  previewFormHandler,
  generateFormHandler,
  fillPdf,
  watermarkPdf,
} = require("./form_generation");

async function pdfShows(bytes, text) {
  const { PDFDocument, decodePDFRawStream, PDFRawStream } = require("pdf-lib");
  const doc = await PDFDocument.load(bytes);
  const hex = Buffer.from(text).toString("hex").toUpperCase();
  for (const [, obj] of doc.context.enumerateIndirectObjects()) {
    if (!(obj instanceof PDFRawStream)) continue;
    let decoded;
    try {
      decoded = Buffer.from(decodePDFRawStream(obj).decode()).toString("latin1");
    } catch (_) {
      continue;
    }
    if (decoded.includes(text) || decoded.toUpperCase().includes(hex)) return true;
  }
  return false;
}

function templateDeps(fieldNames) {
  return async () => {
    const { PDFDocument } = require("pdf-lib");
    const doc = await PDFDocument.create();
    doc.addPage([300, 300]);
    const form = doc.getForm();
    fieldNames.forEach((name, i) => {
      const f = form.createTextField(name);
      f.addToPage(doc.getPage(0), { x: 10, y: 10 + i * 30, width: 100, height: 20 });
    });
    return doc.save();
  };
}

test("canonicalFromDocs does not split the account name into a legal name", () => {
  const values = canonicalFromDocs({
    identifiers: {},
    user: { displayName: "Jane Quinn Veteran", email: "v@example.com" },
    service: {},
  });
  assert.equal(values["vet.legalFirstName"], undefined);
  assert.equal(values["vet.legalLastName"], undefined);
  assert.equal(values["vet.email"], "v@example.com");
});

test("canonicalFromDocs uses the form email and form phone, not sign-in", () => {
  const values = canonicalFromDocs({
    identifiers: {
      legalFirstName: "Ada",
      legalLastName: "Lovelace",
      email: "forms@example.com",
      phone: "+15555550100",
    },
    user: { email: "sign-in@example.com", phone: "+19995550199" },
    service: {},
  });
  assert.equal(values["vet.email"], "forms@example.com");
  assert.equal(values["vet.phoneAreaCode"], "555");
  assert.equal(values["vet.phonePrefix"], "555");
  assert.equal(values["vet.phoneLine"], "0100");
});

test("canonicalFromDocs keeps a saved legal name over the account name", () => {
  const values = canonicalFromDocs({
    identifiers: { legalFirstName: "Janet", legalLastName: "Smith" },
    user: { displayName: "Jane Veteran" },
    service: {},
  });
  assert.equal(values["vet.legalFirstName"], "Janet");
  assert.equal(values["vet.legalLastName"], "Smith");
  assert.equal(values["vet.fullName"], "Janet Smith");
});

test("applyDownloadRoles signs only when asked and only the named boxes", () => {
  const fields = [
    { pdfField: "ssn1", role: "veteranSsnArea" },
    { pdfField: "sig", role: "signature" },
    { pdfField: "day", role: "signedDay" },
  ];
  const unsigned = applyDownloadRoles(fields, { values: {}, missing: [] }, {
    signed: false,
    signedOn: { day: "09", month: "10", year: "2026" },
    fullName: "Jane Veteran",
    ssn: "123-45-6789",
  });
  assert.equal(unsigned.values.ssn1.value, "123");
  assert.equal(unsigned.values.sig, undefined);
  assert.equal(unsigned.values.day, undefined);

  const signed = applyDownloadRoles(fields, { values: {}, missing: [] }, {
    signed: true,
    signedOn: { day: "09", month: "10", year: "2026" },
    fullName: "Jane Veteran",
    ssn: "123-45-6789",
  });
  assert.equal(signed.values.sig.value, "Jane Veteran");
  assert.equal(signed.values.day.value, "09");
});

test("canonicalFromDocs assembles stored values and omits blanks", () => {
  const values = canonicalFromDocs({
    identifiers: { legalFirstName: "Jane", legalLastName: "Veteran", ssn: "123-45-6789" },
    user: { email: "v@example.com" },
    service: { branch: "Army", entryDate: "2008-01-01", separationDate: "" },
  });
  assert.equal(values["vet.legalFirstName"], "Jane");
  assert.equal(values["vet.ssn"], "123-45-6789");
  assert.equal(values["vet.email"], "v@example.com");
  assert.equal(values["service.branch"], "Army");
  assert.ok(!("service.separationDate" in values));
  assert.ok(!("vet.priorVaClaim" in values));
});

test("canonicalFromDocs maps a prior claim to Yes and keeps a first claim's file number off 21-0966", () => {
  const prior = canonicalFromDocs({
    identifiers: { vaFileNumber: "12345678" },
    user: { firstVaDisabilityClaim: false },
  });
  assert.equal(prior["vet.priorVaClaim"], "1");
  assert.equal(prior["vet.priorClaimFileNumber"], "12345678");
  assert.equal(prior["vet.vaFileNumber"], "12345678");

  const first = canonicalFromDocs({
    identifiers: { vaFileNumber: "12345678" },
    user: { firstVaDisabilityClaim: true },
  });
  assert.equal(first["vet.priorVaClaim"], "2");
  assert.ok(!("vet.priorClaimFileNumber" in first));
  assert.equal(first["vet.vaFileNumber"], "12345678");
});

test("deriveCanonicalValues splits identity values the way PDFs need them", () => {
  const out = deriveCanonicalValues({
    "vet.legalFirstName": "Jane",
    "vet.legalMiddleName": "Quinn",
    "vet.legalLastName": "Veteran",
    "vet.ssn": "123-45-6789",
    "vet.dateOfBirth": "1986-07-04",
    "vet.phone": "+15551234567",
  });
  assert.equal(out["vet.legalMiddleInitial"], "Q");
  assert.equal(out["vet.ssnArea"], "123");
  assert.equal(out["vet.ssnGroup"], "45");
  assert.equal(out["vet.ssnSerial"], "6789");
  assert.equal(out["vet.dobMonth"], "07");
  assert.equal(out["vet.dobDay"], "04");
  assert.equal(out["vet.dobYear"], "1986");
  assert.equal(out["vet.dobUsSlashes"], "07/04/1986");
  assert.equal(out["vet.phoneAreaCode"], "555");
  assert.equal(out["vet.phonePrefix"], "123");
  assert.equal(out["vet.phoneLine"], "4567");
  assert.equal(out["vet.phoneUsDashes"], "555-123-4567");
  assert.equal(out["vet.fullName"], "Jane Quinn Veteran");
});

test("deriveCanonicalValues splits a ZIP+4", () => {
  const out = deriveCanonicalValues({ "vet.mailingZip": "78701-1234" });
  assert.equal(out["vet.mailingZip5"], "78701");
  assert.equal(out["vet.mailingZip4"], "1234");
});

test("deriveCanonicalValues yields nothing for malformed values", () => {
  const out = deriveCanonicalValues({ "vet.ssn": "12-3", "vet.dateOfBirth": "July" });
  assert.ok(!("vet.ssnArea" in out));
  assert.ok(!("vet.dobYear" in out));
});

test("resolveFieldValues fills auto and constant fields and skips ask and dev", () => {
  const mapping = {
    fields: [
      { pdfField: "last", canonicalKey: "vet.legalLastName", required: true },
      { pdfField: "ssn", canonicalKey: "vet.ssn", required: true },
      { pdfField: "stmt", canonicalKey: "statement.body" },
      { pdfField: "box", constantValue: "1", type: "checkbox" },
      { pdfField: "city", source: "ask", group: "ask:city", required: true },
      { pdfField: "sig", source: "dev" },
    ],
  };
  const resolved = resolveFieldValues(mapping, {
    "vet.legalLastName": "Veteran",
    "statement.body": "My knee hurts.",
  });
  assert.equal(resolved.values.last.value, "Veteran");
  assert.equal(resolved.values.stmt.value, "My knee hurts.");
  assert.equal(resolved.values.box.value, "1");
  assert.equal(resolved.values.box.type, "checkbox");
  assert.ok(!("city" in resolved.values), "ask fields are not filled");
  assert.ok(!("sig" in resolved.values), "dev fields are not filled");
  assert.equal(resolved.missing.length, 1);
  assert.equal(resolved.missing[0].canonicalKey, "vet.ssn");
});

test("resolveFieldValues continues a long email across sibling boxes and repeats a value that fits", () => {
  const email = "alex.veteran.longname@example.com";
  const mapping = {
    fields: [
      { pdfField: "form1[0].#subform[0].EMAIL_ADDRESS[0]", source: "auto", canonicalKey: "vet.email", maxLength: 20, type: "text" },
      { pdfField: "form1[0].#subform[0].EMAIL_ADDRESS[1]", source: "auto", canonicalKey: "vet.email", maxLength: 20, type: "text" },
      { pdfField: "F[0].#subform[9].SocialSecurityNumber_FirstThreeNumbers[0]", source: "auto", canonicalKey: "vet.ssnArea", maxLength: 3, type: "text" },
      { pdfField: "F[0].#subform[10].SocialSecurityNumber_FirstThreeNumbers[1]", source: "auto", canonicalKey: "vet.ssnArea", maxLength: 3, type: "text" },
      { pdfField: "last", source: "auto", canonicalKey: "vet.legalLastName", maxLength: 18, type: "text" },
    ],
  };
  const resolved = resolveFieldValues(mapping, {
    "vet.email": email,
    "vet.ssn": "999-88-7777",
    "vet.legalLastName": "AVeryLongLastNameThatExceedsTheBox",
  });
  assert.equal(resolved.values["form1[0].#subform[0].EMAIL_ADDRESS[0]"].value, email.slice(0, 20));
  assert.equal(resolved.values["form1[0].#subform[0].EMAIL_ADDRESS[1]"].value, email.slice(20));
  assert.equal(resolved.values["F[0].#subform[9].SocialSecurityNumber_FirstThreeNumbers[0]"].value, "999");
  assert.equal(resolved.values["F[0].#subform[10].SocialSecurityNumber_FirstThreeNumbers[1]"].value, "999");
  assert.equal(resolved.values.last.value, "AVeryLongLastNameT");
});

test("resolveFieldValues writes a long email onto the top line of 21-0966 first", () => {
  const email = "alan.t.negrete@gmail.com";
  const mapping = {
    fields: [
      { pdfField: "F[0].Page_1[0].EMAIL_ADDRESS[1]", source: "auto", canonicalKey: "vet.email", maxLength: 20, type: "text" },
      { pdfField: "F[0].Page_1[0].EMAIL_ADDRESS[0]", source: "auto", canonicalKey: "vet.email", maxLength: 20, type: "text" },
    ],
  };
  const resolved = resolveFieldValues(mapping, { "vet.email": email });
  assert.equal(resolved.values["F[0].Page_1[0].EMAIL_ADDRESS[1]"].value, email.slice(0, 20));
  assert.equal(resolved.values["F[0].Page_1[0].EMAIL_ADDRESS[0]"].value, email.slice(20));
});

test("resolveFieldValues derives split values from the saved base", () => {
  const mapping = {
    fields: [
      { pdfField: "area", source: "auto", canonicalKey: "vet.ssnArea" },
      { pdfField: "serial", source: "auto", canonicalKey: "vet.ssnSerial" },
    ],
  };
  const resolved = resolveFieldValues(mapping, { "vet.ssn": "999-88-7777" });
  assert.equal(resolved.values.area.value, "999");
  assert.equal(resolved.values.serial.value, "7777");
});

test("fillPdf and watermarkPdf produce a flattened, stamped PDF", async () => {
  const { PDFDocument } = require("pdf-lib");
  const doc = await PDFDocument.create();
  doc.addPage([300, 300]);
  const form = doc.getForm();
  const text = form.createTextField("greeting");
  text.addToPage(doc.getPage(0), { x: 10, y: 10, width: 100, height: 20 });
  const template = await doc.save();

  const resolved = { values: { greeting: { value: "Jane", type: "text" } } };
  const { flattened } = await fillPdf(template, resolved, { watermark: true });
  assert.ok(flattened.length > 0);
  assert.equal(await pdfShows(flattened, "Jane"), true, "the flattened page contains the filled name");
  const reopened = await PDFDocument.load(flattened);
  assert.equal(reopened.getForm().getFields().length, 0, "preview is flattened");

  const stamped = await watermarkPdf(await PDFDocument.create().then((d) => {
    d.addPage([200, 200]);
    return d.save();
  }));
  assert.ok(stamped.length > 0);
});

test("previewFormHandler renders a watermarked preview without throwing on gaps", async () => {
  const saved = {};
  const deps = {
    requireReady: async () => "uid1",
    firestore: {
      doc: (path) => ({
        get: async () => ({
          exists: true,
          data: () => ({ formNumber: "21-4138", caseId: "c1" }),
        }),
      }),
    },
    storage: {
      bucket: () => ({
        file: (p) => ({
          save: async (buf) => {
            saved.path = p;
            saved.bytes = buf.length;
          },
        }),
      }),
    },
    loadMapping: async () => ({
      id: "m1",
      revisionId: "2021-06-16",
      fields: [
        { pdfField: "last", source: "auto", canonicalKey: "vet.legalLastName", group: "vet.legalLastName", required: true },
        { pdfField: "city", source: "ask", group: "ask:city" },
      ],
    }),
    loadCanonical: async () => ({ "vet.legalLastName": "Veteran" }),
    loadClaimContext: async () => ({ issues: [], theoriesByIssue: {}, linksByIssue: {} }),
    loadTemplate: async () => {
      const { PDFDocument } = require("pdf-lib");
      const doc = await PDFDocument.create();
      doc.addPage([300, 300]);
      const form = doc.getForm();
      ["last", "city"].forEach((name, i) => {
        const f = form.createTextField(name);
        f.addToPage(doc.getPage(0), { x: 10, y: 10 + i * 30, width: 100, height: 20 });
      });
      return doc.save();
    },
  };
  const result = await previewFormHandler(
    { auth: { uid: "uid1" }, data: { packageFormId: "pf1" } },
    deps,
  );
  assert.equal(result.storagePath, "users/uid1/formPreviews/pf1.pdf");
  assert.equal(result.fieldCount, 1, "only the auto field is filled");
  assert.equal(typeof result.pdfBase64, "string");
  assert.ok(result.pdfBase64.length > 20, "the preview bytes come back with the call");
  assert.ok(saved.bytes > 0, "preview bytes were written to storage");
});

test("generateFormHandler fills auto fields, ignores ask, and marks the form ready", async () => {
  const written = { files: {}, pkg: null, generated: null };
  const mapping = {
    id: "m1",
    revisionId: "2021-06-16",
    fields: [
      { pdfField: "last", source: "auto", canonicalKey: "vet.legalLastName", group: "vet.legalLastName", required: true },
      { pdfField: "city", source: "ask", group: "ask:city", required: true },
    ],
  };
  const pkg = { formNumber: "21-4138", caseId: "c1" };
  const deps = {
    requireReady: async () => "uid1",
    firestore: {
      doc: (path) => ({
        get: async () => ({ exists: true, data: () => pkg }),
        set: async (data) => {
          written.pkg = data;
        },
      }),
      collection: () => ({
        doc: () => ({
          id: "gen1",
          set: async (data) => {
            written.generated = data;
          },
        }),
      }),
    },
    storage: {
      bucket: () => ({
        file: (p) => ({
          save: async (buf) => {
            written.files[p] = buf.length;
          },
        }),
      }),
    },
    loadMapping: async () => mapping,
    loadCanonical: async () => ({ "vet.legalLastName": "Veteran" }),
    loadClaimContext: async () => ({ issues: [], theoriesByIssue: {}, linksByIssue: {} }),
    loadTemplate: templateDeps(["last", "city"]),
  };
  const result = await generateFormHandler(
    { auth: { uid: "uid1" }, data: { packageFormId: "pf1" } },
    deps,
  );
  assert.equal(result.generatedFormId, "gen1");
  assert.equal(written.generated.fieldCount, 1, "the ask field is left blank");
  assert.equal(written.pkg.status, "ready");
  assert.ok(Object.keys(written.files).some((p) => p.endsWith("filled.pdf")));
});

test("generateFormHandler refuses when a required auto field is still blank", async () => {
  const mapping = {
    id: "m1",
    revisionId: "2021-06-16",
    fields: [
      { pdfField: "last", source: "auto", canonicalKey: "vet.legalLastName", required: true },
    ],
  };
  const deps = {
    requireReady: async () => "uid1",
    firestore: {
      doc: () => ({
        get: async () => ({ exists: true, data: () => ({ formNumber: "21-4138", caseId: "c1" }) }),
      }),
    },
    storage: { bucket: () => ({ file: () => ({ save: async () => {} }) }) },
    loadMapping: async () => mapping,
    loadCanonical: async () => ({}),
    loadClaimContext: async () => ({ issues: [], theoriesByIssue: {}, linksByIssue: {} }),
    loadTemplate: templateDeps(["last"]),
  };
  await assert.rejects(
    () => generateFormHandler({ auth: { uid: "uid1" }, data: { packageFormId: "pf1" } }, deps),
    /required fields are still missing/,
  );
});

test("previewFormHandler merges a 21-526EZ section draft over the assembled note", async () => {
  const saved = {};
  const deps = {
    requireReady: async () => "uid1",
    firestore: {
      doc: () => ({
        get: async () => ({
          exists: true,
          data: () => ({
            formNumber: "21-526EZ",
            caseId: "c1",
            sectionDrafts: { knee: "Saved prose." },
          }),
        }),
      }),
    },
    storage: {
      bucket: () => ({
        file: (p) => ({
          save: async (buf) => {
            saved.bytes = buf.length;
          },
        }),
      }),
    },
    loadMapping: async () => ({
      id: "m1",
      revisionId: "r",
      fields: [
        { pdfField: "last", source: "auto", canonicalKey: "vet.legalLastName" },
      ],
    }),
    loadCanonical: async () => ({ "vet.legalLastName": "Veteran" }),
    loadClaimContext: async () => ({
      issues: [{ id: "knee", displayName: "Knee" }],
      theoriesByIssue: { knee: [{ type: "direct", summary: "Twisted it on a run." }] },
      linksByIssue: {},
    }),
    loadTemplate: templateDeps(["last"]),
  };
  const result = await previewFormHandler(
    {
      auth: { uid: "uid1" },
      data: { packageFormId: "pf1", sectionDrafts: { knee: "Reviewed prose." } },
    },
    deps,
  );
  // last name + disability name + explanation
  assert.equal(result.fieldCount, 3);
  assert.ok(saved.bytes > 0);
});

async function signatureTemplate() {
  const { PDFDocument, PDFName, PDFString } = require("pdf-lib");
  const doc = await PDFDocument.create();
  const page = doc.addPage([612, 792]);
  const widget = doc.context.obj({
    Type: "Annot",
    Subtype: "Widget",
    FT: "Sig",
    T: PDFString.of("SignatureField1"),
    Rect: [45, 408, 293, 433],
    F: 4,
    P: page.ref,
  });
  const widgetRef = doc.context.register(widget);
  page.node.addAnnot(widgetRef);
  doc.catalog.set(PDFName.of("AcroForm"), doc.context.obj({ Fields: [widgetRef] }));
  return doc.save();
}

test("a signature with no appearance shows the typed name only on a signed fill", async () => {
  const bytes = await signatureTemplate();
  const signed = await fillPdf(
    bytes,
    { values: { SignatureField1: { value: "Jane Veteran", type: "text" } }, missing: [] },
    { signatureFields: new Set(["SignatureField1"]) },
  );
  assert.equal(await pdfShows(signed.flattened, "Jane Veteran"), true);

  const unsigned = await fillPdf(
    bytes,
    { values: {}, missing: [] },
    { signatureFields: new Set() },
  );
  assert.equal(await pdfShows(unsigned.flattened, "Jane Veteran"), false);
});

test("21-0966 signed fill paints the legal name and an unsigned fill does not", async (t) => {
  const fs = require("fs");
  const path = require("path");
  const cache = path.join(__dirname, "..", ".va-forms-cache", "21-0966", "original.pdf");
  if (!fs.existsSync(cache)) {
    t.skip("the imported 21-0966 template is not cached");
    return;
  }
  const bytes = fs.readFileSync(cache);
  const signature = "F[0].#subform[1].SignatureField1[0]";
  const signed = await fillPdf(
    bytes,
    { values: { [signature]: { value: "Jane Veteran", type: "text" } }, missing: [] },
    { signatureFields: new Set([signature]) },
  );
  assert.equal(await pdfShows(signed.flattened, "Jane Veteran"), true);
  const unsigned = await fillPdf(bytes, { values: {}, missing: [] });
  assert.equal(await pdfShows(unsigned.flattened, "Jane Veteran"), false);
});
