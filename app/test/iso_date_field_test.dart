import 'package:app/forms/iso_date_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = IsoDateInputFormatter();

  TextEditingValue format(String text) {
    return formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  test('digits become a YYYY-MM-DD mask', () {
    expect(format('20100102').text, '2010-01-02');
    expect(format('2010').text, '2010');
    expect(format('201001').text, '2010-01');
  });

  test('letters and extra digits are dropped', () {
    expect(format('2010-01-02abc99').text, '2010-01-02');
  });

  test('a month and year mask stops after YYYY-MM', () {
    const monthFormatter = YearMonthInputFormatter();
    final value = monthFormatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '20100315',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    expect(value.text, '2010-03');
  });
}
