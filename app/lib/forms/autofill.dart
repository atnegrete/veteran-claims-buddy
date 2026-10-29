/// Deterministic auto-fill: a form mapping plus a canonical profile produce the
/// field values that go into the PDF, and a list of still-missing required
/// fields. No model is involved (handoff 1.6, 37.10).
library;

import 'canonical_profile.dart';
import 'va_form_mapping.dart';

/// One filled field for the preview and for PDF generation.
class FilledField {
  const FilledField({
    required this.pdfField,
    required this.label,
    required this.value,
    required this.type,
    required this.fromCanonical,
  });

  final String pdfField;
  final String label;

  /// The resolved value, or null when it could not be filled.
  final String? value;
  final FormFieldType type;

  /// True when the value came from the canonical profile (vs a constant or a
  /// supplied extra such as a statement body).
  final bool fromCanonical;

  bool get isFilled => value != null && value!.isNotEmpty;
}

/// A missing required field the Veteran still needs to supply.
class MissingField {
  const MissingField({required this.canonicalKey, required this.label});

  final String canonicalKey;
  final String label;

  /// True when this is a protected identifier (SSN, VA file number, legal name,
  /// date of birth) collected on the identifiers step.
  bool get isIdentifier =>
      CanonicalKeys.protectedIdentifierKeys.contains(canonicalKey);
}

/// The result of filling one form.
class AutofillResult {
  const AutofillResult({required this.fields, required this.missing});

  final List<FilledField> fields;
  final List<MissingField> missing;

  bool get isComplete => missing.isEmpty;

  /// The subset of fields that have a value, as a plain map for generation.
  Map<String, String> get filledValues => {
    for (final field in fields)
      if (field.isFilled) field.pdfField: field.value!,
  };
}

/// Fills [mapping] from [profile]. [extraValues] supplies values that are not
/// in the canonical profile (for example a drafted statement body keyed by
/// [CanonicalKeys.statementBody]). Deterministic.
AutofillResult fillForm({
  required VaFormMapping mapping,
  required CanonicalProfile profile,
  Map<String, String> extraValues = const {},
}) {
  final fields = <FilledField>[];
  final missing = <MissingField>[];
  final seenMissing = <String>{};

  for (final field in mapping.fields) {
    String? value;
    var fromCanonical = false;

    if (field.constantValue != null) {
      value = field.constantValue;
    } else if (field.canonicalKey != null) {
      final key = field.canonicalKey!;
      value = extraValues[key]?.trim();
      if (value == null || value.isEmpty) {
        value = profile.value(key);
        fromCanonical = value != null;
      }
      if ((value == null || value.isEmpty) && field.required) {
        if (seenMissing.add(key)) {
          missing.add(MissingField(canonicalKey: key, label: field.label));
        }
      }
    }

    fields.add(
      FilledField(
        pdfField: field.pdfField,
        label: field.label,
        value: (value != null && value.isEmpty) ? null : value,
        type: field.type,
        fromCanonical: fromCanonical,
      ),
    );
  }

  return AutofillResult(fields: fields, missing: missing);
}
