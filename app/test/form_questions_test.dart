import 'package:app/claim/identifiers_repository.dart';
import 'package:app/forms/form_catalog.dart';
import 'package:app/forms/form_questions.dart';
import 'package:app/forms/identifier_fields.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('form questions', () {
    test('statement forms carry their question sets', () {
      expect(questionsFor('21-4138').map((q) => q.id),
          containsAll(<String>['condition_change', 'daily_impact']));
      expect(questionsFor('21-10210').map((q) => q.id),
          containsAll(<String>['witness_name', 'witness_relationship', 'observed']));
      expect(questionsFor(nexusFormId).map((q) => q.id),
          containsAll(<String>['cause', 'diagnosis', 'treatment']));
    });

    test('a form with no question step returns an empty list', () {
      expect(questionsFor('21-526EZ'), isEmpty);
      expect(questionsFor('not-a-form'), isEmpty);
    });

    test('owner-confirmed max-lengths are applied', () {
      int maxOf(String form, String id) =>
          questionsFor(form).firstWhere((q) => q.id == id).maxLength;
      expect(maxOf('21-4138', 'condition_change'), 4000);
      expect(maxOf('21-4138', 'daily_impact'), 4000);
      expect(maxOf('21-10210', 'witness_name'), 100);
      expect(maxOf('21-10210', 'witness_relationship'), 60);
      expect(maxOf('21-10210', 'observed'), 4000);
      expect(maxOf('21-0781', 'event'), 4000);
      expect(maxOf('21-0781', 'event_location'), 200);
      expect(maxOf('21-0781', 'since_impact'), 4000);
      expect(maxOf(nexusFormId, 'cause'), 4000);
      expect(maxOf(nexusFormId, 'diagnosis'), 4000);
      expect(maxOf(nexusFormId, 'treatment'), 4000);
      expect(maxOf('21-4142a', 'provider_name'), 120);
      expect(maxOf('21-4192', 'employer_name'), 120);
      expect(statementBodyMaxLength, 8000);
    });

    test('entry label uses the label question when answered', () {
      final buddy = formDefFor('21-10210')!;
      expect(entryLabelFor(buddy, {'witness_name': 'Jane Roe'}), 'Jane Roe');
      expect(entryLabelFor(buddy, const {}), buddy.shortTitle);

      final provider = formDefFor('21-4142a')!;
      expect(entryLabelFor(provider, {'provider_name': 'Dr. Smith'}), 'Dr. Smith');
    });
  });

  group('identifier validation', () {
    test('accepts empty values and well-formed shapes', () {
      expect(identifiersError(Identifiers.empty), isNull);
      expect(
        identifiersError(const Identifiers(
          legalFirstName: 'Alex',
          legalLastName: 'Veteran',
          dateOfBirth: '1985-07-04',
          ssn: '123-45-6789',
          vaFileNumber: '123456789',
          phone: '+15555550100',
        )),
        isNull,
      );
    });

    test('rejects malformed shapes with a specific message', () {
      expect(identifiersError(const Identifiers(ssn: '123456789')), isNotNull);
      expect(identifiersError(const Identifiers(vaFileNumber: '12')), isNotNull);
      expect(
        identifiersError(const Identifiers(dateOfBirth: '07/04/1985')),
        isNotNull,
      );
      expect(identifiersError(const Identifiers(phone: '5555550100')), isNotNull);
      expect(identifiersError(const Identifiers(mailingZip: '1234')), isNotNull);
      expect(identifiersError(const Identifiers(mailingState: 'Texas')), isNotNull);
      expect(
        identifiersError(const Identifiers(
          mailingStreet: '1 Main Street',
          mailingCity: 'Austin',
          mailingState: 'TX',
          mailingZip: '78701-1234',
        )),
        isNull,
      );
    });
  });

  group('SSN mask', () {
    String masked(String input) {
      const formatter = SsnInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      );
      return result.text;
    }

    test('inserts dashes and drops non-digits', () {
      expect(masked('123456789'), '123-45-6789');
      expect(masked('12345'), '123-45');
      expect(masked('abc123-45'), '123-45');
    });

    test('clips to nine digits', () {
      expect(masked('1234567890123'), '123-45-6789');
    });
  });
}
