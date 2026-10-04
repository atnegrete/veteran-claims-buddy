import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_input_chain.dart';

/// A real calendar day in `YYYY-MM-DD`.
bool validIsoDate(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1) return false;
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

/// Keeps a date field in `YYYY-MM-DD` as the user types.
class IsoDateInputFormatter extends TextInputFormatter {
  const IsoDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 4 || i == 6) buffer.write('-');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(text[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}

/// Keeps a best-guess month field in `YYYY-MM` as the user types.
class YearMonthInputFormatter extends TextInputFormatter {
  const YearMonthInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 6 ? digits.substring(0, 6) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 4) buffer.write('-');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(text[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}

class YearMonthField extends StatelessWidget {
  const YearMonthField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ChainTextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [YearMonthInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM',
        helperText: 'A best guess is fine.',
      ),
    );
  }
}

/// A time of day in `HH:MM`, 00:00 through 23:59.
bool validTimeOfDay(String text) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
  if (match == null) return false;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  return hour <= 23 && minute <= 59;
}

/// Keeps a time field in `HH:MM` as the user types.
class TimeOfDayInputFormatter extends TextInputFormatter {
  const TimeOfDayInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2) buffer.write(':');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(text[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}

class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ChainTextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [TimeOfDayInputFormatter()],
      decoration: InputDecoration(labelText: label, hintText: 'HH:MM'),
    );
  }
}

class IsoDateField extends StatelessWidget {
  const IsoDateField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ChainTextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [IsoDateInputFormatter()],
      decoration: InputDecoration(labelText: label, hintText: 'YYYY-MM-DD'),
    );
  }
}
