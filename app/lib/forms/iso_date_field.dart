import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return TextField(
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
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [IsoDateInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
      ),
    );
  }
}
