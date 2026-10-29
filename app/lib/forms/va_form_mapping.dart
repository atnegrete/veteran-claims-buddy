/// Revision-specific mapping from canonical answer keys to VA PDF field names
/// (handoff 37.9). One mapping is pinned to the exact form revision it was
/// authored against. Published to Firestore `vaFormMappings/{form}__{revision}`
/// by `scripts/va_forms_publish_mappings.js`; read here to drive auto-fill.
library;

/// Canonical answer keys. These are stable identifiers the mapping and the
/// canonical profile agree on, independent of any one PDF's field names.
class CanonicalKeys {
  const CanonicalKeys._();

  static const legalFirstName = 'vet.legalFirstName';
  static const legalMiddleName = 'vet.legalMiddleName';
  static const legalLastName = 'vet.legalLastName';
  static const dateOfBirth = 'vet.dateOfBirth';
  static const ssn = 'vet.ssn';
  static const vaFileNumber = 'vet.vaFileNumber';

  /// 21-0966 item 3. "1" is Yes, an earlier claim. "2" is No, this is the
  /// first claim. Absent until Case Info is answered.
  static const priorVaClaim = 'vet.priorVaClaim';

  /// The VA file number written on 21-0966 only when [priorVaClaim] is Yes.
  /// Other forms keep using [vaFileNumber].
  static const priorClaimFileNumber = 'vet.priorClaimFileNumber';

  static const email = 'vet.email';
  static const phone = 'vet.phone';
  static const mailingStreet = 'vet.mailingStreet';
  static const mailingUnit = 'vet.mailingUnit';
  static const mailingCity = 'vet.mailingCity';
  static const mailingState = 'vet.mailingState';
  static const mailingZip = 'vet.mailingZip';
  static const serviceBranch = 'service.branch';
  static const serviceEntryDate = 'service.entryDate';
  static const serviceSeparationDate = 'service.separationDate';

  /// The AI-drafted or Veteran-entered statement body for a statement form.
  static const statementBody = 'statement.body';

  // Derived sub-values. Official VA PDFs split identity values across several
  // AcroForm fields (SSN into three boxes, the date of birth into month/day/
  // year, the phone into area/prefix/line). These keys are computed
  // deterministically from the base values above by the canonical profile, so
  // the fill path stays "one key, one field" with no transforms. A derived key
  // is absent whenever its base value is absent or malformed; it is never
  // guessed.
  static const legalMiddleInitial = 'vet.legalMiddleInitial';
  static const ssnArea = 'vet.ssnArea';
  static const ssnGroup = 'vet.ssnGroup';
  static const ssnSerial = 'vet.ssnSerial';
  static const dobYear = 'vet.dobYear';
  static const dobMonth = 'vet.dobMonth';
  static const dobDay = 'vet.dobDay';
  static const phoneAreaCode = 'vet.phoneAreaCode';
  static const phonePrefix = 'vet.phonePrefix';
  static const phoneLine = 'vet.phoneLine';

  // Combined forms of the same values, for the PDFs that use one box instead of
  // several. Also deterministic, also derived.
  static const fullName = 'vet.fullName'; // First [Middle] Last
  static const dobUsSlashes = 'vet.dobUsSlashes'; // MM/DD/YYYY
  static const phoneUsDashes = 'vet.phoneUsDashes'; // XXX-XXX-XXXX
  static const mailingZip5 = 'vet.mailingZip5';
  static const mailingZip4 = 'vet.mailingZip4';

  /// Identifier keys the Veteran must supply explicitly before a form is final.
  static const protectedIdentifierKeys = <String>{
    legalFirstName,
    legalLastName,
    dateOfBirth,
    ssn,
    vaFileNumber,
  };
}

/// How a single PDF field is filled.
enum FormFieldType { text, date, checkbox, radio }

FormFieldType formFieldTypeFrom(String? value) {
  return switch (value) {
    'date' => FormFieldType.date,
    'checkbox' => FormFieldType.checkbox,
    'radio' => FormFieldType.radio,
    _ => FormFieldType.text,
  };
}

/// Where a field's value comes from. `auto` is a certain Veteran value from a
/// canonical key; `ask` is a blank the Veteran fills; `constant` is fixed; and
/// `dev` is a signature or office-use box the Veteran never fills (hidden from
/// the editor, shown only in the dev PDF-key debug panel).
enum FormFieldSource { auto, ask, constant, dev }

FormFieldSource formFieldSourceFrom(String? value, {bool hasCanonical = false, bool hasConstant = false}) {
  return switch (value) {
    'auto' => FormFieldSource.auto,
    'ask' => FormFieldSource.ask,
    'constant' => FormFieldSource.constant,
    'dev' => FormFieldSource.dev,
    _ => hasCanonical
        ? FormFieldSource.auto
        : hasConstant
            ? FormFieldSource.constant
            : FormFieldSource.ask,
  };
}

/// One PDF field and where its value comes from.
class VaFormFieldMap {
  const VaFormFieldMap({
    required this.pdfField,
    required this.label,
    this.group,
    this.source = FormFieldSource.ask,
    this.canonicalKey,
    this.constantValue,
    this.options = const [],
    this.maxLength,
    this.required = false,
    this.type = FormFieldType.text,
  });

  /// The AcroForm field name in the official PDF revision.
  final String pdfField;

  /// A human label for the preview.
  final String label;

  /// The logical value this field belongs to. Fields that share a group are a
  /// single editor input that fills every matching PDF field.
  final String? group;

  /// Where the value comes from.
  final FormFieldSource source;

  /// The canonical key that supplies the value, or null for a constant/ask.
  final String? canonicalKey;

  /// A fixed value (for example a checkbox that is always on for this form).
  final String? constantValue;

  /// For radio/dropdown fields, the export values the PDF accepts.
  final List<String> options;

  /// The field's own maximum character count, read from the AcroForm. Null when
  /// the field sets no limit.
  final int? maxLength;

  /// Whether a final PDF cannot be generated without this value.
  final bool required;

  final FormFieldType type;

  static VaFormFieldMap fromData(Map<String, dynamic> data) {
    final canonical = data['canonicalKey'];
    final constant = data['constantValue'];
    final group = data['group'];
    final rawOptions = data['options'];
    final options = <String>[
      if (rawOptions is List)
        for (final o in rawOptions)
          if (o is String) o,
    ];
    final rawMax = data['maxLength'];
    final hasCanonical = canonical is String && canonical.isNotEmpty;
    final hasConstant = constant is String && constant.isNotEmpty;
    return VaFormFieldMap(
      pdfField: data['pdfField'] as String? ?? '',
      label: data['label'] as String? ?? (data['pdfField'] as String? ?? ''),
      group: group is String && group.isNotEmpty ? group : null,
      source: formFieldSourceFrom(
        data['source'] as String?,
        hasCanonical: hasCanonical,
        hasConstant: hasConstant,
      ),
      canonicalKey: hasCanonical ? canonical : null,
      constantValue: hasConstant ? constant : null,
      options: options,
      maxLength: rawMax is int && rawMax > 0 ? rawMax : null,
      required: data['required'] == true,
      type: formFieldTypeFrom(data['type'] as String?),
    );
  }
}

/// A full form mapping for one revision.
class VaFormMapping {
  const VaFormMapping({
    required this.formNumber,
    required this.revisionId,
    required this.fields,
  });

  final String formNumber;
  final String revisionId;
  final List<VaFormFieldMap> fields;

  static VaFormMapping fromData(String id, Map<String, dynamic> data) {
    final rawFields = data['fields'];
    final fields = <VaFormFieldMap>[];
    if (rawFields is List) {
      for (final entry in rawFields) {
        if (entry is Map<String, dynamic>) {
          fields.add(VaFormFieldMap.fromData(entry));
        }
      }
    }
    return VaFormMapping(
      formNumber: data['formNumber'] as String? ?? '',
      revisionId: data['revisionId'] as String? ?? id,
      fields: fields,
    );
  }
}
