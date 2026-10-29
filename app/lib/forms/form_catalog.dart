/// The supported-form allowlist (handoff 37.29).
///
/// This is the single source of truth, in the app, for which VA forms the
/// product knows how to prepare, how many of each can go on one claim, whether
/// the app drafts a statement for it, and the one-line "what this is / where it
/// goes" copy shown on the form detail card. The deterministic recommender
/// (`form_recommender.dart`) and the Forms UI both read this list.
///
/// A generated PDF is an output, never the canonical record (handoff 37.10).
/// Nothing here files anything with the VA.
library;

/// How many copies of one form can live on a single claim.
enum FormMultiplicity {
  /// Only one makes sense per claim (for example 21-526EZ).
  single,

  /// The Veteran can add several, each a separate entry (for example a buddy
  /// statement per witness, or a records release per provider).
  multiple,
}

/// Whether the app drafts a written statement for the form, and in which voice.
enum FormStatementKind {
  /// No statement. Structured fields only, filled deterministically.
  none,

  /// A first-person statement in the Veteran's or a witness's own words.
  lay,

  /// An unsigned draft the Veteran brings to their own physician. It is never a
  /// finished or signed medical opinion.
  doctorDraft,
}

/// Which build phase a form belongs to.
enum FormScope {
  /// Wired end-to-end now: auto-fill + (if applicable) AI statement + preview.
  v1,

  /// A fillable supporting form in the same disability-claim flow.
  v1Support,

  /// Listed for completeness; not qualified in this pass (different benefit
  /// line). Adding one later is a catalog row + a revision import + a mapping.
  phase2,
}

/// The nexus letter is evidence, not a numbered VA form. It uses this id.
const nexusFormId = 'nexus';

/// Whether downloading a filled copy of a form is free, paid, or not offered.
enum FormDownloadAccess { hidden, free, premium }

/// What the shared download dialog asks for, and which buttons it shows.
///
/// A later form turns this on without a new dialog. [collectSsn] and
/// [allowSigned] are independent, because some forms have no Social Security
/// boxes and some are not signed here.
class FormDownloadPolicy {
  const FormDownloadPolicy({
    this.access = FormDownloadAccess.hidden,
    this.collectLegalName = false,
    this.collectSsn = false,
    this.allowUnsigned = false,
    this.allowSigned = false,
  });

  final FormDownloadAccess access;
  final bool collectLegalName;
  final bool collectSsn;
  final bool allowUnsigned;
  final bool allowSigned;

  bool get offered => access != FormDownloadAccess.hidden;

  static const hidden = FormDownloadPolicy();
}

/// One entry in the supported-form allowlist.
class VaFormDef {
  const VaFormDef({
    required this.formNumber,
    required this.title,
    required this.shortTitle,
    required this.whatItIs,
    required this.whereItGoes,
    required this.multiplicity,
    required this.statement,
    required this.scope,
    this.companionFormNumbers = const [],
    this.download = FormDownloadPolicy.hidden,
  });

  /// The VA form number, or [nexusFormId] for the nexus letter.
  final String formNumber;

  /// The full VA title.
  final String title;

  /// A short label for lists and cards.
  final String shortTitle;

  /// Info-card copy: what this form is.
  final String whatItIs;

  /// Info-card copy: where it goes / what happens when it is submitted. This
  /// replaces the old bare "VA decision reviews" external link.
  final String whereItGoes;

  final FormMultiplicity multiplicity;
  final FormStatementKind statement;
  final FormScope scope;

  /// Forms packaged alongside this one (for example 21-4142a with 21-4142).
  final List<String> companionFormNumbers;

  /// Download dialog for this form. Hidden until a form is ready to offer it.
  final FormDownloadPolicy download;

  bool get isMultiple => multiplicity == FormMultiplicity.multiple;
  bool get needsStatement => statement != FormStatementKind.none;
  bool get isEvidence => formNumber == nexusFormId;
}

/// The allowlist. Order is roughly the order a claim uses them. Only [v1] and
/// [v1Support] are built end-to-end in this pass; phase2 rows are intentionally
/// left for a later import + mapping with no code change.
const supportedForms = <VaFormDef>[
  VaFormDef(
    formNumber: '21-0966',
    title: 'Intent to File a Claim',
    shortTitle: 'Intent to File',
    whatItIs:
        'This is VA Form 21-0966. It is not your disability claim. It tells the VA you are going to file one.',
    whereItGoes:
        'If the VA grants your claim, compensation can be paid back to the day they receive this form, even while you keep working on the other forms here. You have one year from that day to file the complete claim. The day you download it does not count.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
    download: FormDownloadPolicy(
      access: FormDownloadAccess.free,
      collectLegalName: true,
      collectSsn: true,
      allowUnsigned: true,
      allowSigned: true,
    ),
  ),
  VaFormDef(
    formNumber: '21-526EZ',
    title: 'Application for Disability Compensation and Related Compensation Benefits',
    shortTitle: 'Disability compensation claim',
    whatItIs:
        'The main VA disability compensation application for the conditions on this claim.',
    whereItGoes:
        'This is the claim itself. When you submit it, the VA opens a disability compensation claim for the listed conditions.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '21-4138',
    title: 'Statement in Support of Claim',
    shortTitle: 'Personal statement',
    whatItIs:
        'A written statement in your own words about how a condition started or affects your life.',
    whereItGoes:
        'Rides along with your claim as supporting evidence. The reviewer reads it alongside your records.',
    multiplicity: FormMultiplicity.multiple,
    statement: FormStatementKind.lay,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '21-10210',
    title: 'Lay or Witness Statement',
    shortTitle: 'Buddy statement',
    whatItIs:
        'A statement from someone who witnessed your condition, an event, or how it affects you.',
    whereItGoes:
        'Supporting evidence from a witness. It is attached to your claim; the witness signs it, not the app.',
    multiplicity: FormMultiplicity.multiple,
    statement: FormStatementKind.lay,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '21-0781',
    title: 'Statement in Support of Claimed Mental Health Disorder(s) Due to an In-Service Traumatic Event(s)',
    shortTitle: 'Mental-health event statement',
    whatItIs:
        'Describes the in-service event behind a claimed mental-health condition.',
    whereItGoes:
        'Supports a mental-health condition on your claim by giving the VA the event details they look for.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.lay,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: nexusFormId,
    title: 'Nexus letter (medical opinion draft)',
    shortTitle: 'Nexus letter',
    whatItIs:
        'An unsigned draft linking a condition to your service, written for you to take to your own doctor. It is not a medical opinion and the app never signs it.',
    whereItGoes:
        'You bring this draft to a physician. If they agree and sign their own opinion, that signed letter becomes evidence on your claim.',
    multiplicity: FormMultiplicity.multiple,
    statement: FormStatementKind.doctorDraft,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '21-4142',
    title: 'Authorization to Disclose Information to the Department of Veterans Affairs',
    shortTitle: 'Private records authorization',
    whatItIs:
        'Lets the VA request your records directly from a private (non-VA) doctor or hospital.',
    whereItGoes:
        'Goes to the VA with 21-4142a so they can gather private treatment records for your claim.',
    multiplicity: FormMultiplicity.multiple,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
    companionFormNumbers: ['21-4142a'],
  ),
  VaFormDef(
    formNumber: '21-4142a',
    title: 'General Release for Medical Provider Information to the Department of Veterans Affairs',
    shortTitle: 'Provider details for records',
    whatItIs:
        'Names each private provider and the treatment dates for the records release.',
    whereItGoes:
        'Pairs with 21-4142. Together they let the VA request the records you name.',
    multiplicity: FormMultiplicity.multiple,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '21-8940',
    title: "Veteran's Application for Increased Compensation Based on Unemployability",
    shortTitle: 'Individual Unemployability',
    whatItIs:
        'Applies for a higher benefit when service-connected conditions keep you from working.',
    whereItGoes:
        'Files a request for Individual Unemployability (TDIU) on your claim, with 21-4192 for employer details.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
    companionFormNumbers: ['21-4192'],
  ),
  VaFormDef(
    formNumber: '21-4192',
    title: 'Request for Employment Information in Connection with Claim for Disability Benefits',
    shortTitle: 'Employer information',
    whatItIs:
        'Employer information that supports an Individual Unemployability request.',
    whereItGoes:
        'A former employer completes it. It supports the 21-8940 unemployability request.',
    multiplicity: FormMultiplicity.multiple,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '20-0995',
    title: 'Decision Review Request: Supplemental Claim',
    shortTitle: 'Supplemental Claim',
    whatItIs:
        'Asks the VA to review a decided issue again with new and relevant evidence.',
    whereItGoes:
        'Opens a Supplemental Claim lane. Available after a decision denies, defers, or reduces an issue.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '20-0996',
    title: 'Decision Review Request: Higher-Level Review',
    shortTitle: 'Higher-Level Review',
    whatItIs:
        'Asks a senior reviewer to re-check the same evidence. You do not add new evidence on this path.',
    whereItGoes:
        'Opens a Higher-Level Review lane. Available after a decision denies, defers, or reduces an issue.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '10182',
    title: 'Decision Review Request: Board Appeal (Notice of Disagreement)',
    shortTitle: 'Board Appeal',
    whatItIs:
        'Takes a decided issue to a Veterans Law Judge at the Board of Veterans\' Appeals.',
    whereItGoes:
        'Opens a Board Appeal. One docket lets you add more evidence. Available after an adverse decision.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
  ),
  VaFormDef(
    formNumber: '20-10206',
    title: 'Privacy Act Request',
    shortTitle: 'Records request',
    whatItIs: 'Requests a copy of your own VA claims file.',
    whereItGoes:
        'Goes to the VA records office. It asks for your file; it does not change your claim.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1,
  ),
  // v1-support: fillable supporting forms in the same disability-claim flow.
  VaFormDef(
    formNumber: '21-686c',
    title: 'Application Request to Add and/or Remove Dependents',
    shortTitle: 'Add or remove dependents',
    whatItIs:
        'Adds or removes a spouse, child, or dependent parent on your compensation.',
    whereItGoes:
        'Files a dependents request with the VA. Dependents can raise your monthly amount once your rating qualifies.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1Support,
    companionFormNumbers: ['21-674'],
  ),
  VaFormDef(
    formNumber: '21-674',
    title: 'Request for Approval of School Attendance',
    shortTitle: 'School attendance (child 18-23)',
    whatItIs:
        'Keeps a child aged 18 to 23 on your benefits while they attend school.',
    whereItGoes:
        'Pairs with 21-686c so a school-age child stays a dependent on your compensation.',
    multiplicity: FormMultiplicity.multiple,
    statement: FormStatementKind.none,
    scope: FormScope.v1Support,
  ),
  VaFormDef(
    formNumber: '21-0845',
    title: 'Authorization to Disclose Personal Information to a Third Party',
    shortTitle: 'Third-party authorization',
    whatItIs:
        'Lets the VA talk about your claim with a person or organization you name.',
    whereItGoes:
        'Files with the VA so a representative or family member can discuss your claim on your behalf.',
    multiplicity: FormMultiplicity.single,
    statement: FormStatementKind.none,
    scope: FormScope.v1Support,
  ),
];

final Map<String, VaFormDef> _byNumber = {
  for (final form in supportedForms) form.formNumber: form,
};

/// Looks up a form definition by number, or null when it is not supported.
VaFormDef? formDefFor(String formNumber) => _byNumber[formNumber];

/// The forms built end-to-end in this pass.
List<VaFormDef> get activeForms => [
  for (final form in supportedForms)
    if (form.scope == FormScope.v1 || form.scope == FormScope.v1Support) form,
];
