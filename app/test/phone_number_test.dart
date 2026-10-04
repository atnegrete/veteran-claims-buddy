import 'package:app/auth/phone_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ten digits become a U.S. E.164 number', () {
    expect(toE164('5555550100'), '+15555550100');
    expect(toE164('(555) 555-0100'), '+15555550100');
    expect(toE164('+1 (555) 555-0100'), '+15555550100');
    expect(toE164('15555550100'), '+15555550100');
  });

  test('a non-U.S. country code is rejected', () {
    expect(toE164('+44 7700 900123'), isNull);
  });

  test('the mask keeps +1 and ten digits', () {
    expect(formatUsPhone(''), '+1 ');
    expect(formatUsPhone('555'), '+1 (555');
    expect(formatUsPhone('555555'), '+1 (555) 555');
    expect(formatUsPhone('5555550100'), '+1 (555) 555-0100');
    expect(formatUsPhone('15555550100999'), '+1 (555) 555-0100');
    expect(formatUsPhone('+44 7700 900123'), '+1 ');
  });

  testWidgets('the mobile field starts with +1', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MobileNumberField(controller: controller)),
      ),
    );
    expect(controller.text, '+1 ');
    await tester.enterText(find.byType(EditableText), '5555550100');
    await tester.pump();
    expect(controller.text, '+1 (555) 555-0100');
    expect(find.textContaining('/'), findsNothing);
  });

  test('incomplete numbers are rejected', () {
    expect(toE164('555'), isNull);
    expect(toE164('+1 '), isNull);
    expect(toE164(''), isNull);
  });

  test('the display label keeps only the last four digits', () {
    expect(maskPhoneNumber('+15555550100'), 'Text message ending in 0100');
    expect(maskPhoneNumber('+15555550100').contains('555555'), isFalse);
  });
}
