import 'package:app/forms/autofill.dart';
import 'package:app/forms/canonical_profile.dart';
import 'package:app/forms/form_catalog.dart';
import 'package:app/forms/va_form_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('form catalog', () {
    test('looks up a supported form by number', () {
      final form = formDefFor('21-526EZ');
      expect(form, isNotNull);
      expect(form!.multiplicity, FormMultiplicity.single);
      expect(form.needsStatement, isFalse);
    });

    test('buddy statement allows multiple and drafts a lay statement', () {
      final form = formDefFor('21-10210')!;
      expect(form.isMultiple, isTrue);
      expect(form.statement, FormStatementKind.lay);
    });

    test('nexus letter is evidence with a doctor draft', () {
      final form = formDefFor(nexusFormId)!;
      expect(form.isEvidence, isTrue);
      expect(form.statement, FormStatementKind.doctorDraft);
    });

    test('active forms exclude phase2 and are all v1 or v1-support', () {
      expect(activeForms, isNotEmpty);
      for (final form in activeForms) {
        expect(form.scope, isNot(FormScope.phase2));
      }
      expect(formDefFor('21-686c')!.scope, FormScope.v1Support);
    });

    test('an unknown form number resolves to null', () {
      expect(formDefFor('99-9999'), isNull);
    });
  });

  group('canonical profile', () {
    test('splits a three-part legal name', () {
      final parts = splitLegalName('Jane Q Veteran');
      expect(parts[CanonicalKeys.legalFirstName], 'Jane');
      expect(parts[CanonicalKeys.legalMiddleName], 'Q');
      expect(parts[CanonicalKeys.legalLastName], 'Veteran');
    });

    test('a single token is the last name only', () {
      final parts = splitLegalName('Veteran');
      expect(parts.containsKey(CanonicalKeys.legalFirstName), isFalse);
      expect(parts[CanonicalKeys.legalLastName], 'Veteran');
    });

    test('builds values and omits blanks', () {
      final profile = buildCanonicalProfile(
        const CanonicalProfileInput(
          email: 'v@example.com',
          legalName: 'Jane Veteran',
          serviceBranch: '  ',
        ),
      );
      expect(profile.value(CanonicalKeys.email), 'v@example.com');
      expect(profile.value(CanonicalKeys.legalFirstName), 'Jane');
      expect(profile.has(CanonicalKeys.serviceBranch), isFalse);
      expect(profile.has(CanonicalKeys.priorVaClaim), isFalse);
    });

    test('an earlier claim checks Yes and can fill the file number', () {
      final profile = buildCanonicalProfile(
        const CanonicalProfileInput(
          vaFileNumber: '12345678',
          firstVaDisabilityClaim: false,
        ),
      );
      expect(profile.value(CanonicalKeys.priorVaClaim), '1');
      expect(profile.value(CanonicalKeys.priorClaimFileNumber), '12345678');
      expect(profile.value(CanonicalKeys.vaFileNumber), '12345678');
    });

    test('a first claim checks No and leaves the 21-0966 file number blank', () {
      final profile = buildCanonicalProfile(
        const CanonicalProfileInput(
          vaFileNumber: '12345678',
          firstVaDisabilityClaim: true,
        ),
      );
      expect(profile.value(CanonicalKeys.priorVaClaim), '2');
      expect(profile.has(CanonicalKeys.priorClaimFileNumber), isFalse);
      expect(profile.value(CanonicalKeys.vaFileNumber), '12345678');
    });

    test('derives the split sub-values PDFs need', () {
      final profile = buildCanonicalProfile(
        const CanonicalProfileInput(
          legalName: 'Jane Quinn Veteran',
          ssn: '123-45-6789',
          dateOfBirth: '1986-07-04',
          phone: '+15551234567',
        ),
      );
      expect(profile.value(CanonicalKeys.legalMiddleInitial), 'Q');
      expect(profile.value(CanonicalKeys.ssnArea), '123');
      expect(profile.value(CanonicalKeys.ssnGroup), '45');
      expect(profile.value(CanonicalKeys.ssnSerial), '6789');
      expect(profile.value(CanonicalKeys.dobMonth), '07');
      expect(profile.value(CanonicalKeys.dobDay), '04');
      expect(profile.value(CanonicalKeys.dobYear), '1986');
      expect(profile.value(CanonicalKeys.dobUsSlashes), '07/04/1986');
      expect(profile.value(CanonicalKeys.phoneAreaCode), '555');
      expect(profile.value(CanonicalKeys.phonePrefix), '123');
      expect(profile.value(CanonicalKeys.phoneLine), '4567');
      expect(profile.value(CanonicalKeys.phoneUsDashes), '555-123-4567');
      expect(profile.value(CanonicalKeys.fullName), 'Jane Quinn Veteran');
    });

    test('derives nothing from malformed identity values', () {
      final profile = buildCanonicalProfile(
        const CanonicalProfileInput(ssn: '12-3', dateOfBirth: 'July'),
      );
      expect(profile.has(CanonicalKeys.ssnArea), isFalse);
      expect(profile.has(CanonicalKeys.dobYear), isFalse);
    });
  });

  group('autofill', () {
    VaFormMapping mapping() => VaFormMapping(
      formNumber: '21-4138',
      revisionId: '21-4138__2026-01',
      fields: const [
        VaFormFieldMap(
          pdfField: 'lastName',
          label: 'Last name',
          canonicalKey: CanonicalKeys.legalLastName,
          required: true,
        ),
        VaFormFieldMap(
          pdfField: 'ssn',
          label: 'SSN',
          canonicalKey: CanonicalKeys.ssn,
          required: true,
        ),
        VaFormFieldMap(
          pdfField: 'statement',
          label: 'Statement',
          canonicalKey: CanonicalKeys.statementBody,
        ),
        VaFormFieldMap(
          pdfField: 'box',
          label: 'Checkbox',
          constantValue: '1',
          type: FormFieldType.checkbox,
        ),
      ],
    );

    test('fills from profile, constants, and extras; lists missing required', () {
      final profile = buildCanonicalProfile(
        const CanonicalProfileInput(legalName: 'Jane Veteran'),
      );
      final result = fillForm(
        mapping: mapping(),
        profile: profile,
        extraValues: const {CanonicalKeys.statementBody: 'My knee hurts.'},
      );
      expect(result.filledValues['lastName'], 'Veteran');
      expect(result.filledValues['statement'], 'My knee hurts.');
      expect(result.filledValues['box'], '1');
      expect(result.isComplete, isFalse);
      expect(result.missing.single.canonicalKey, CanonicalKeys.ssn);
      expect(result.missing.single.isIdentifier, isTrue);
    });

    test('is complete when every required field resolves', () {
      final profile = buildCanonicalProfile(
        const CanonicalProfileInput(legalName: 'Jane Veteran', ssn: '123-45-6789'),
      );
      final result = fillForm(mapping: mapping(), profile: profile);
      expect(result.isComplete, isTrue);
      expect(result.filledValues['ssn'], '123-45-6789');
    });
  });
}
