import 'package:app/auth/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ten digits become a U.S. E.164 number', () {
    expect(toE164('5555550100'), '+15555550100');
    expect(toE164('(555) 555-0100'), '+15555550100');
  });

  test('an existing country code is preserved', () {
    expect(toE164('+44 7700 900123'), '+447700900123');
    expect(toE164('15555550100'), '+15555550100');
  });

  test('incomplete numbers are rejected', () {
    expect(toE164('555'), isNull);
    expect(toE164(''), isNull);
  });

  test('the display label keeps only the last four digits', () {
    expect(maskPhoneNumber('+15555550100'), 'Text message ending in 0100');
    expect(maskPhoneNumber('+15555550100').contains('555555'), isFalse);
  });
}
