'use strict';

// Authoring aid (not a runtime dependency): proposes a draft field mapping for
// each imported revision by classifying its AcroForm field names against the
// Veteran's canonical keys. The OUTPUT (mappings/va-forms/<form>.mapping.json)
// is the real artifact: committed, reviewed by a human, and validated by
// va_forms_mappings.test.js before `va:forms:publish-mappings` writes it.
//
// Safety first. Official PDFs carry identity fields for several people (the
// Veteran, a separate claimant, a representative, witnesses, providers,
// dependents). We fill ONLY the Veteran and the claimant (a Veteran filing for
// themselves is the claimant); every other subject is left blank. The
// "bare triplet" (FirstThree/SecondTwo/LastFour) means SSN when a SecondTwo
// sibling is present (SSN is 3-2-4) and phone when an AreaCode sibling is
// present instead (phone is 3-3-4).

const fs = require('fs');
const path = require('path');

const INVENTORY_DIR = path.join(__dirname, '..', 'mappings', 'va-forms', 'inventory');
const OUT_DIR = path.join(__dirname, '..', 'mappings', 'va-forms');
const REVIEW_DIR = path.join(OUT_DIR, 'review');

// Subjects that are NOT the Veteran/claimant. A field whose name mentions one
// of these is never auto-filled with the Veteran's data; it becomes a blank
// user-entered ("ask") field instead.
const OTHER_SUBJECTS = [
  'represent', 'poc', 'alternate', 'witness', 'preparer', 'provider',
  'physician', 'employer', 'child', 'spouse', 'dependent', 'deceased',
  'maiden', 'accredit', 'authorized', 'nameofva', 'alternatesigner',
  'nameifnotveteran', 'insurance', 'organization', 'informant', 'fiduciary',
];

// A derived canonical key is filled from a base value; the editor shows one
// input per GROUP (the base value) and it fills every matching PDF field.
const CANONICAL_GROUP = {
  'vet.legalFirstName': 'vet.legalFirstName',
  'vet.legalMiddleName': 'vet.legalMiddleName',
  'vet.legalMiddleInitial': 'vet.legalMiddleName',
  'vet.legalLastName': 'vet.legalLastName',
  'vet.fullName': 'vet.fullName',
  'vet.ssn': 'vet.ssn',
  'vet.ssnArea': 'vet.ssn',
  'vet.ssnGroup': 'vet.ssn',
  'vet.ssnSerial': 'vet.ssn',
  'vet.dateOfBirth': 'vet.dateOfBirth',
  'vet.dobYear': 'vet.dateOfBirth',
  'vet.dobMonth': 'vet.dateOfBirth',
  'vet.dobDay': 'vet.dateOfBirth',
  'vet.dobUsSlashes': 'vet.dateOfBirth',
  'vet.vaFileNumber': 'vet.vaFileNumber',
  'vet.email': 'vet.email',
  'vet.phone': 'vet.phone',
  'vet.phoneAreaCode': 'vet.phone',
  'vet.phonePrefix': 'vet.phone',
  'vet.phoneLine': 'vet.phone',
  'vet.phoneUsDashes': 'vet.phone',
  'service.branch': 'service.branch',
  'service.entryDate': 'service.entryDate',
  'service.separationDate': 'service.separationDate',
  'statement.body': 'statement.body',
};

// Human label for each canonical group (the auto-filled defaults).
const CANONICAL_LABEL = {
  'vet.legalFirstName': 'Legal first name',
  'vet.legalMiddleName': 'Middle name',
  'vet.legalLastName': 'Legal last name',
  'vet.fullName': 'Full legal name',
  'vet.ssn': 'Social Security number',
  'vet.dateOfBirth': 'Date of birth',
  'vet.vaFileNumber': 'VA file number',
  'vet.priorVaClaim': 'Have you ever filed a VA claim?',
  'vet.priorClaimFileNumber': 'VA file number',
  'vet.email': 'Email address',
  'vet.phone': 'Phone number',
  'service.branch': 'Branch of service',
  'service.entryDate': 'Service start date',
  'service.separationDate': 'Service separation date',
  'statement.body': 'Statement',
};

// Fields the Veteran does not fill: signatures and office/VA-use boxes. Hidden
// from the editor (shown only in the dev PDF-key debug panel).
const DEV_PATTERNS = /signature|for\s*va\s*use|forva|office\s*use|officeuse|date\s*stamp|datestamp|do\s*not\s*write|accreditation/i;

const leafOf = (name) => name.slice(name.lastIndexOf('.') + 1);
const parentOf = (name) => name.slice(0, name.lastIndexOf('.'));
const alnum = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '');

// A readable label from a cryptic AcroForm leaf name, e.g.
// "CurrentMailingAddress_City[0]" -> "Current Mailing Address City".
function humanizeLabel(name) {
  let leaf = leafOf(name).replace(/\[\d+\]$/, '');
  leaf = leaf
    .replace(/_/g, ' ')
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/\s+/g, ' ')
    .trim();
  if (!leaf) return name;
  return leaf.charAt(0).toUpperCase() + leaf.slice(1);
}

// The logical value a blank user field belongs to: the same box repeated across
// pages shares one group (one input fills them all).
function groupForAsk(name) {
  return `ask:${alnum(leafOf(name).replace(/\[\d+\]$/, ''))}`;
}

// The editor input kind for a PDF field type.
function inputTypeFor(pdfType) {
  switch (pdfType) {
    case 'PDFCheckBox':
      return 'checkbox';
    case 'PDFRadioGroup':
    case 'PDFDropdown':
    case 'PDFOptionList':
      return 'radio';
    default:
      return 'text';
  }
}

// Per-form overrides. The global classifier is safe for single-subject forms
// (only the Veteran/claimant). Forms that carry other people's identity
// (witness, dependents, children, a provider, an employer) need explicit
// narrowing so the Veteran's data never lands in someone else's box. These were
// authored by reading each form's committed field inventory. See the notes.
const FORM_RULES = {
  // Statement in support of claim. The drafted statement goes in Remarks.
  '21-4138': { statement: 'form1[0].#subform[0].REMARKS[0]' },
  // PTSD / stressor statement. The drafted statement describes the event.
  '21-0781': {
    statement: 'F[0].#subform[2].Brief_Description_Of_The_Traumatic_Events[0]',
  },
  // Employer-completed; header names the Veteran. Exclude the ambiguous DOB
  // cluster and the employer name/address block.
  '21-4192': { excludeName: /dob|nameandaddress/i },
  // Lay/Witness statement. #subform[2] is the witness. The bare numeric triplet
  // is unmappable here (SSN1/2/3 already give the SSN cleanly, and the bare
  // FirstThree/SecondTwo/LastFour mix SSN and phone across indices), so drop it.
  // The claimant's statement goes in TextField1 on subform[1].
  '21-10210': {
    excludePath: /#subform\[2\]/,
    excludeName: /(firstthreenumbers|secondtwonumbers|lastfournumbers|areacode)\[/i,
    statement: 'vba210304[0].#subform[1].TextField1[0]',
  },
  // Authorization to disclose. The only identities are the patient (the
  // Veteran, repeated on every page) and the providers (named, no SSN) plus the
  // signer. Fill the patient; never the provider/facility blocks or the signer.
  '21-4142': { excludeName: /provider|facility|person_signing|printed_name/i },
  '21-4142a': { excludeName: /provider|facility|person_signing|printed_name/i },
  // Dependents. Fill only fields explicitly named for the Veteran or claimant;
  // every child / dependent / step-child / former-spouse field stays blank.
  '21-686c': { includeName: /veterans?_|claimants[_-]/i },
  // School attendance. The student and Veteran SSN parts are split across
  // inconsistently-named fields; only these are safely the Veteran's.
  '21-674': {
    allow: {
      'form1[0].#subform[0].Veteran_Claimant_FirstName[0]': 'vet.legalFirstName',
      'form1[0].#subform[0].Social_Security_Number_FirstThreeNumbers[0]': 'vet.ssnArea',
      'form1[0].#subform[0].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]': 'vet.ssnGroup',
      'form1[0].#subform[0].Social_Security_Number_LastFourNumbers[0]': 'vet.ssnSerial',
      'form1[0].#subform[0].VA_File_Number_If_Applicable[0]': 'vet.vaFileNumber',
    },
  },
  // Intent to File. Section I is the Veteran. Section II is someone filing
  // for the Veteran, which this product does not prepare, so those boxes stay
  // blank. The unprefixed phone triplet is the Veteran's (3-3-4): first three
  // is the area code, not a second copy of the prefix.
  '21-0966': {
    // Item 13 is the claimant's file number. Item 4, VA_File_Number[0], is
    // the Veteran's and is forced below.
    excludeName: /claimants|address_of_parent|relationshiptoveteran|international_phone|va_file_number\[1\]/i,
    forceKey: {
      'F[0].Page_1[0].TelephoneNumber_FirstThreeNumbers[0]': 'vet.phoneAreaCode',
      'F[0].Page_1[0].TelephoneNumber_SecondThreeNumbers[0]': 'vet.phonePrefix',
      'F[0].Page_1[0].TelephoneNumber_LastFourNumbers[0]': 'vet.phoneLine',
      // Item 3. Export "1" is Yes, "2" is No. Positions on the 2023-02-28
      // template: YES sits higher (y 527) than NO (y 512).
      'F[0].Page_1[0].RadioButtonList[2]': 'vet.priorVaClaim',
      // Item 4, the Veteran box at y 508. The claimant box at y 240 stays ask.
      'F[0].Page_1[0].VA_File_Number[0]': 'vet.priorClaimFileNumber',
    },
    constants: {
      'F[0].#subform[1].Compensation[0]': 'Yes',
    },
    roles: {
      'F[0].Page_1[0].Veterans_Social_SecurityNumber_FirstThreeNumbers[0]': 'veteranSsnArea',
      'F[0].Page_1[0].Veterans_Social_SecurityNumber_SecondTwoNumbers[0]': 'veteranSsnGroup',
      'F[0].Page_1[0].VeteransSocialSecurityNumber_LastFourNumbers[0]': 'veteranSsnSerial',
      'F[0].#subform[1].SignatureField1[0]': 'signature',
      'F[0].#subform[1].DATE_SIGNED_Day[0]': 'signedDay',
      'F[0].#subform[1].DATE_SIGNED_Month[0]': 'signedMonth',
      'F[0].#subform[1].DATE_SIGNED_Year[0]': 'signedYear',
    },
    download: {
      access: 'free',
      collect: ['legalName', 'ssn'],
      actions: ['unsigned', 'signed'],
    },
    // The top email line is [1]. The bottom line is [0]. Continuation walks
    // the mapping in list order, so the top line is emitted first.
    continuationOrder: [
      'F[0].Page_1[0].EMAIL_ADDRESS[1]',
      'F[0].Page_1[0].EMAIL_ADDRESS[0]',
    ],
  },
};

// Does this field's parent subform contain a bare SecondTwoNumbers sibling?
// That marks the bare FirstThree/SecondTwo/LastFour triplet as an SSN (3-2-4)
// rather than a phone number (3-3-4).
function parentHasBareSecondTwo(name, byParent) {
  const siblings = byParent.get(parentOf(name)) || [];
  return siblings.some((leaf) => /^secondtwonumbers\[/i.test(leaf));
}

function parentHasAreaCode(name, byParent) {
  const siblings = byParent.get(parentOf(name)) || [];
  return siblings.some((leaf) => /areacode/i.test(leaf));
}

// Returns a canonicalKey for one field, or null to leave it blank.
function classify(field, byParent, rules = {}) {
  // Auto-fill only sets plain text fields. Checkboxes, radios, dropdowns, and
  // signatures are left for the Veteran so a label like "contact me by phone"
  // never gets mistaken for a phone-number box.
  if (field.type !== 'PDFTextField') return null;
  const name = field.name;
  const low = name.toLowerCase();
  const a = alnum(name);
  const leaf = leafOf(name);
  const leafA = alnum(leaf);

  if (OTHER_SUBJECTS.some((s) => low.includes(s))) return null;

  // SSN1 / SSN2 / SSN3 are the three boxes of one SSN (3-2-4), not three SSNs.
  if (/^ssn1\[/i.test(leaf)) return 'vet.ssnArea';
  if (/^ssn2\[/i.test(leaf)) return 'vet.ssnGroup';
  if (/^ssn3\[/i.test(leaf)) return 'vet.ssnSerial';

  // Explicit SSN label.
  if (a.includes('socialsecuritynumber') || /(^|[^a-z])ssn/.test(low)) {
    if (a.includes('firstthree')) return 'vet.ssnArea';
    if (a.includes('secondtwo')) return 'vet.ssnGroup';
    if (a.includes('lastfour')) return 'vet.ssnSerial';
    if (!/(firstthree|secondtwo|lastfour|three|two|four)/.test(a)) return 'vet.ssn';
    return null;
  }

  // Explicit phone label.
  if (a.includes('phone') || a.includes('telephone')) {
    if (a.includes('international')) return null;
    if (a.includes('areacode')) return 'vet.phoneAreaCode';
    if (a.includes('firstthree') || a.includes('middlethree') || a.includes('secondthree')) {
      return 'vet.phonePrefix';
    }
    if (a.includes('lastfour')) return 'vet.phoneLine';
    if (!/(three|four|area)/.test(a)) return 'vet.phoneUsDashes';
    return null;
  }

  // Bare area code is always phone.
  if (leafA.startsWith('areacode')) return 'vet.phoneAreaCode';
  if (leafA.startsWith('internationalphonenumber')) return null;

  // Bare numeric triplet: SSN (3-2-4) vs phone (3-3-4) by sibling context,
  // unless the form forces the bare triplet to be read as a phone number.
  if (/^firstthreenumbers\[/i.test(leaf)) {
    if (rules.bareTripletIsPhone) return 'vet.phonePrefix';
    if (parentHasBareSecondTwo(name, byParent)) return 'vet.ssnArea';
    if (parentHasAreaCode(name, byParent)) return 'vet.phonePrefix';
    return null;
  }
  if (/^secondtwonumbers\[/i.test(leaf)) return rules.bareTripletIsPhone ? null : 'vet.ssnGroup';
  if (/^lastfournumbers\[/i.test(leaf)) {
    if (rules.bareTripletIsPhone) return 'vet.phoneLine';
    if (parentHasBareSecondTwo(name, byParent)) return 'vet.ssnSerial';
    if (parentHasAreaCode(name, byParent)) return 'vet.phoneLine';
    return null;
  }
  if (/^middle_?three/i.test(leaf)) return 'vet.phonePrefix';

  // Names.
  if (/first_?name/i.test(low)) return 'vet.legalFirstName';
  if (/last_?name/i.test(low)) return 'vet.legalLastName';
  if (/middle_?initial/i.test(low)) return 'vet.legalMiddleInitial';
  // A single combined "Veteran's name" box (e.g. VETERANSNAME[0]).
  if (leafA.replace(/\d+$/, '') === 'veteransname') return 'vet.fullName';

  // Email.
  if (/e[-_]?mail/i.test(low) || a.includes('email')) return 'vet.email';

  // VA file / service number.
  if (a.includes('vafilenumber') || a.includes('veteransfilenumber')) {
    return 'vet.vaFileNumber';
  }

  // Date of birth.
  if (a.includes('dob') || a.includes('dateofbirth') || a.includes('birthdate')) {
    if (a.includes('day')) return 'vet.dobDay';
    if (a.includes('month')) return 'vet.dobMonth';
    if (a.includes('year')) return 'vet.dobYear';
    return 'vet.dobUsSlashes';
  }

  return null;
}

function attachRole(field, rules) {
  const role = rules.roles && rules.roles[field.pdfField];
  if (!role) return field;
  return { ...field, role };
}

// Decides the auto canonical key for one field, honoring the per-form rules
// that gate which fields may be auto-filled. Returns null when the field is not
// a certain Veteran value (it then becomes a blank "ask" field).
function autoKeyFor(field, byParent, rules) {
  const name = field.name;
  if (rules.forceKey && Object.prototype.hasOwnProperty.call(rules.forceKey, name)) {
    return rules.forceKey[name];
  }
  if (rules.allow) {
    return Object.prototype.hasOwnProperty.call(rules.allow, name)
      ? rules.allow[name]
      : null;
  }
  if (rules.excludePath && rules.excludePath.test(name)) return null;
  if (rules.excludeName && rules.excludeName.test(name)) return null;
  if (rules.includeName && !rules.includeName.test(name)) return null;
  return classify(field, byParent, rules);
}

// Moves the named boxes into [order] while leaving every other field where it
// was. Continuation fills the first listed box, then the next.
function applyContinuationOrder(fields, order) {
  if (!order || order.length === 0) return fields;
  const wanted = new Set(order);
  const picked = new Map();
  for (const field of fields) {
    if (wanted.has(field.pdfField)) picked.set(field.pdfField, field);
  }
  let inserted = false;
  const out = [];
  for (const field of fields) {
    if (!wanted.has(field.pdfField)) {
      out.push(field);
      continue;
    }
    if (!inserted) {
      for (const name of order) out.push(picked.get(name));
      inserted = true;
    }
  }
  return out;
}

// Builds the full v2 mapping for one revision: EVERY fillable field appears,
// classified as `auto` (a certain Veteran value, with a canonicalKey), `ask`
// (the Veteran fills it), `constant`, or `dev` (signatures / office-use, hidden
// from the editor). Fields that share a `group` are one input that fills every
// matching PDF field.
function buildMapping(inv) {
  const rules = FORM_RULES[inv.formNumber] || {};
  const byParent = new Map();
  for (const f of inv.fields) {
    const p = parentOf(f.name);
    if (!byParent.has(p)) byParent.set(p, []);
    byParent.get(p).push(leafOf(f.name));
  }
  const valid = new Set(inv.fields.map((f) => f.name));
  if (rules.allow) {
    for (const pdfField of Object.keys(rules.allow)) {
      if (!valid.has(pdfField)) {
        throw new Error(`${inv.formNumber}: allowlisted field not in revision: ${pdfField}`);
      }
    }
  }
  if (rules.statement && !valid.has(rules.statement)) {
    throw new Error(`${inv.formNumber}: statement field not in revision: ${rules.statement}`);
  }
  for (const pdfField of Object.keys(rules.forceKey || {})) {
    if (!valid.has(pdfField)) {
      throw new Error(`${inv.formNumber}: forceKey field not in revision: ${pdfField}`);
    }
  }
  for (const pdfField of Object.keys(rules.constants || {})) {
    if (!valid.has(pdfField)) {
      throw new Error(`${inv.formNumber}: constant field not in revision: ${pdfField}`);
    }
  }
  for (const pdfField of Object.keys(rules.roles || {})) {
    if (!valid.has(pdfField)) {
      throw new Error(`${inv.formNumber}: role field not in revision: ${pdfField}`);
    }
  }
  for (const pdfField of rules.continuationOrder || []) {
    if (!valid.has(pdfField)) {
      throw new Error(`${inv.formNumber}: continuation field not in revision: ${pdfField}`);
    }
  }

  const fields = inv.fields.map((f) => {
    const input = inputTypeFor(f.type);
    const base = { pdfField: f.name, type: input, required: false };
    if (typeof f.maxLength === 'number') base.maxLength = f.maxLength;
    if (Array.isArray(f.options) && f.options.length) base.options = f.options;

    // The drafted statement body wins for the statement field.
    if (rules.statement && f.name === rules.statement) {
      return attachRole({
        ...base,
        label: CANONICAL_LABEL['statement.body'],
        group: 'statement.body',
        source: 'auto',
        canonicalKey: 'statement.body',
      }, rules);
    }

    if (rules.constants && rules.constants[f.name] != null) {
      return attachRole({
        ...base,
        label: humanizeLabel(f.name),
        group: null,
        source: 'constant',
        constantValue: String(rules.constants[f.name]),
      }, rules);
    }

    // Signatures and office/VA-use boxes are not for the Veteran to fill.
    if (f.type === 'PDFSignature' || DEV_PATTERNS.test(f.name)) {
      return attachRole(
        { ...base, label: humanizeLabel(f.name), group: null, source: 'dev' },
        rules,
      );
    }

    const key = autoKeyFor(f, byParent, rules);
    if (key) {
      return attachRole({
        ...base,
        label: CANONICAL_LABEL[key] || humanizeLabel(f.name),
        group: CANONICAL_GROUP[key] || key,
        source: 'auto',
        canonicalKey: key,
      }, rules);
    }

    // Everything else is a blank field the Veteran fills in the editor.
    return attachRole({
      ...base,
      label: humanizeLabel(f.name),
      group: groupForAsk(f.name),
      source: 'ask',
    }, rules);
  });

  const mapping = {
    formNumber: inv.formNumber,
    revision: inv.revision,
    fields: applyContinuationOrder(fields, rules.continuationOrder),
  };
  if (rules.download) mapping.download = rules.download;
  return mapping;
}

// A per-form review report: the fields that are NOT auto-filled, so the owner
// can see what the Veteran is being asked to fill and promote any to auto.
function reviewReport(mapping) {
  const rows = mapping.fields
    .filter((f) => f.source === 'ask' || f.source === 'dev')
    .map((f) => ({
      pdfField: f.pdfField,
      label: f.label,
      type: f.type,
      source: f.source,
      ...(f.options ? { options: f.options } : {}),
    }));
  return { formNumber: mapping.formNumber, revision: mapping.revision, review: rows };
}

function main() {
  fs.mkdirSync(REVIEW_DIR, { recursive: true });
  const files = fs.readdirSync(INVENTORY_DIR).filter((f) => f.endsWith('.json'));
  for (const file of files) {
    const inv = JSON.parse(fs.readFileSync(path.join(INVENTORY_DIR, file), 'utf8'));
    const mapping = buildMapping(inv);
    fs.writeFileSync(
      path.join(OUT_DIR, `${inv.formNumber}.mapping.json`),
      `${JSON.stringify(mapping, null, 2)}\n`,
    );
    fs.writeFileSync(
      path.join(REVIEW_DIR, `${inv.formNumber}.todo.json`),
      `${JSON.stringify(reviewReport(mapping), null, 2)}\n`,
    );
    const counts = { auto: 0, ask: 0, dev: 0, constant: 0 };
    const groups = new Set();
    for (const f of mapping.fields) {
      counts[f.source] = (counts[f.source] || 0) + 1;
      if (f.group && f.source !== 'dev') groups.add(f.group);
    }
    console.log(
      `${inv.formNumber}: ${mapping.fields.length} fields — ` +
        `auto:${counts.auto} ask:${counts.ask} dev:${counts.dev} (${groups.size} inputs)`,
    );
  }
}

if (require.main === module) main();

module.exports = { classify, buildMapping, reviewReport };
