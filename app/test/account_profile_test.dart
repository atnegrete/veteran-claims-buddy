import 'package:app/account/profile.dart';
import 'package:app/support/support_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a profile name collapses extra spaces and stays within 102 characters',
    () {
      expect(normalizeProfileName('  Alex   Rivera '), 'Alex Rivera');
      expect(joinLegalName(first: 'Ada', middle: 'Augusta', last: 'King'), 'Ada Augusta King');
      expect(profileNameOk('Alex'), isTrue);
      expect(profileNameOk(''), isTrue);
      expect(profileNameOk('a' * 102), isTrue);
      expect(profileNameOk('a' * 103), isFalse);
      expect(profileTimezoneOrDefault('Mars/Base'), defaultProfileTimezone);
      expect(profileTimezoneOrDefault('America/Phoenix'), 'America/Phoenix');
    },
  );

  test('a support ticket needs a subject and a message', () {
    expect(supportSubjectOk('  Password help  '), isTrue);
    expect(supportSubjectOk('   '), isFalse);
    expect(supportSubjectOk('a' * 121), isFalse);
    expect(supportMessageOk('I cannot sign in.'), isTrue);
    expect(supportMessageOk('   '), isFalse);
    expect(supportCategoryLabel('printMail'), 'Print & Mail');
    expect(supportStatusLabel('waitingOnUser'), 'Waiting on you');
  });
}
