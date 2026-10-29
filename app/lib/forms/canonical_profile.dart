/// The deterministic read-model that assembles everything auto-fill needs from
/// data the claim already stores. No AI. Canonical data flows into forms; the
/// forms never become the database (handoff 37.10).
library;

import 'va_form_mapping.dart';

/// A resolved set of canonical values for one Veteran, keyed by [CanonicalKeys].
/// A missing value is simply absent from [values]; it is never guessed.
class CanonicalProfile {
  const CanonicalProfile(this.values);

  final Map<String, String> values;

  static const empty = CanonicalProfile({});

  String? value(String canonicalKey) {
    final raw = values[canonicalKey];
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool has(String canonicalKey) => value(canonicalKey) != null;

  CanonicalProfile withValues(Map<String, String> extra) {
    return CanonicalProfile({...values, ...extra});
  }
}

/// Splits a stored display or legal name into first / middle / last parts.
/// Deterministic and simple: first token is first name, last token is last
/// name, anything between is the middle. A single token is the last name only.
Map<String, String> splitLegalName(String? fullName) {
  final name = (fullName ?? '').trim();
  if (name.isEmpty) return const {};
  final parts = name.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return {CanonicalKeys.legalLastName: parts.first};
  }
  final first = parts.first;
  final last = parts.last;
  final middle = parts.sublist(1, parts.length - 1).join(' ');
  return {
    CanonicalKeys.legalFirstName: first,
    if (middle.isNotEmpty) CanonicalKeys.legalMiddleName: middle,
    CanonicalKeys.legalLastName: last,
  };
}

/// Inputs the profile reads. Every field is already stored by the app; this
/// class only arranges them. [legalName], [dateOfBirth], [ssn], and
/// [vaFileNumber] come from the protected identifiers doc and stay null until
/// the Veteran enters them.
class CanonicalProfileInput {
  const CanonicalProfileInput({
    this.email,
    this.phone,
    this.mailingStreet,
    this.mailingUnit,
    this.mailingCity,
    this.mailingState,
    this.mailingZip,
    this.legalName,
    this.dateOfBirth,
    this.ssn,
    this.vaFileNumber,
    this.firstVaDisabilityClaim,
    this.serviceBranch,
    this.serviceEntryDate,
    this.serviceSeparationDate,
  });

  final String? email;
  final String? phone;
  final String? mailingStreet;
  final String? mailingUnit;
  final String? mailingCity;
  final String? mailingState;
  final String? mailingZip;
  final String? legalName;
  final String? dateOfBirth;
  final String? ssn;
  final String? vaFileNumber;

  /// `true` when this is the first VA disability claim, `false` when an
  /// earlier claim exists, null when Case Info has not been answered.
  final bool? firstVaDisabilityClaim;

  final String? serviceBranch;
  final String? serviceEntryDate;
  final String? serviceSeparationDate;
}

/// Derives the split sub-values official PDFs need from the base identity
/// values. Pure and deterministic. A sub-value is only added when its base
/// value is present and well-formed; a malformed value yields nothing rather
/// than a wrong guess. Shared shape with `canonicalFromDocs` in
/// `functions/form_generation.js` so the preview and the PDF agree.
Map<String, String> deriveCanonicalValues(Map<String, String> values) {
  final derived = <String, String>{};

  final middle = values[CanonicalKeys.legalMiddleName]?.trim();
  if (middle != null && middle.isNotEmpty) {
    derived[CanonicalKeys.legalMiddleInitial] =
        middle.substring(0, 1).toUpperCase();
  }

  final ssnDigits = (values[CanonicalKeys.ssn] ?? '').replaceAll(RegExp(r'\D'), '');
  if (ssnDigits.length == 9) {
    derived[CanonicalKeys.ssnArea] = ssnDigits.substring(0, 3);
    derived[CanonicalKeys.ssnGroup] = ssnDigits.substring(3, 5);
    derived[CanonicalKeys.ssnSerial] = ssnDigits.substring(5, 9);
  }

  final dob = values[CanonicalKeys.dateOfBirth] ?? '';
  final dobMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dob);
  if (dobMatch != null) {
    derived[CanonicalKeys.dobYear] = dobMatch.group(1)!;
    derived[CanonicalKeys.dobMonth] = dobMatch.group(2)!;
    derived[CanonicalKeys.dobDay] = dobMatch.group(3)!;
  }

  final phoneDigits =
      (values[CanonicalKeys.phone] ?? '').replaceAll(RegExp(r'\D'), '');
  // Stored as +1 plus ten digits; map the ten national digits.
  final national = phoneDigits.length == 11 && phoneDigits.startsWith('1')
      ? phoneDigits.substring(1)
      : phoneDigits;
  if (national.length == 10) {
    derived[CanonicalKeys.phoneAreaCode] = national.substring(0, 3);
    derived[CanonicalKeys.phonePrefix] = national.substring(3, 6);
    derived[CanonicalKeys.phoneLine] = national.substring(6, 10);
    derived[CanonicalKeys.phoneUsDashes] =
        '${national.substring(0, 3)}-${national.substring(3, 6)}-${national.substring(6, 10)}';
  }

  final first = values[CanonicalKeys.legalFirstName]?.trim();
  final last = values[CanonicalKeys.legalLastName]?.trim();
  if (first != null && first.isNotEmpty && last != null && last.isNotEmpty) {
    final mid = values[CanonicalKeys.legalMiddleName]?.trim();
    derived[CanonicalKeys.fullName] = [
      first,
      if (mid != null && mid.isNotEmpty) mid,
      last,
    ].join(' ');
  }

  if (dobMatch != null) {
    derived[CanonicalKeys.dobUsSlashes] =
        '${dobMatch.group(2)}/${dobMatch.group(3)}/${dobMatch.group(1)}';
  }

  final zip = values[CanonicalKeys.mailingZip] ?? '';
  final zipMatch = RegExp(r'^(\d{5})(?:-(\d{4}))?$').firstMatch(zip);
  if (zipMatch != null) {
    derived[CanonicalKeys.mailingZip5] = zipMatch.group(1)!;
    final plus4 = zipMatch.group(2);
    if (plus4 != null) derived[CanonicalKeys.mailingZip4] = plus4;
  }

  return derived;
}

/// Builds the canonical profile. Pure and deterministic.
CanonicalProfile buildCanonicalProfile(CanonicalProfileInput input) {
  final values = <String, String>{};

  void put(String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) values[key] = trimmed;
  }

  values.addAll(splitLegalName(input.legalName));
  put(CanonicalKeys.dateOfBirth, input.dateOfBirth);
  put(CanonicalKeys.ssn, input.ssn);
  put(CanonicalKeys.vaFileNumber, input.vaFileNumber);
  final firstClaim = input.firstVaDisabilityClaim;
  if (firstClaim == false) {
    values[CanonicalKeys.priorVaClaim] = '1';
    put(CanonicalKeys.priorClaimFileNumber, input.vaFileNumber);
  } else if (firstClaim == true) {
    values[CanonicalKeys.priorVaClaim] = '2';
  }
  put(CanonicalKeys.email, input.email);
  put(CanonicalKeys.phone, input.phone);
  put(CanonicalKeys.mailingStreet, input.mailingStreet);
  put(CanonicalKeys.mailingUnit, input.mailingUnit);
  put(CanonicalKeys.mailingCity, input.mailingCity);
  put(CanonicalKeys.mailingState, input.mailingState);
  put(CanonicalKeys.mailingZip, input.mailingZip);
  put(CanonicalKeys.serviceBranch, input.serviceBranch);
  put(CanonicalKeys.serviceEntryDate, input.serviceEntryDate);
  put(CanonicalKeys.serviceSeparationDate, input.serviceSeparationDate);

  values.addAll(deriveCanonicalValues(values));

  return CanonicalProfile(values);
}
