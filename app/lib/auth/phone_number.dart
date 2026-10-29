import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../forms/text_input_chain.dart';

/// The country code the mobile field always shows.
const usPhonePrefix = '+1 ';

/// Ten national digits from a typed or pasted U.S. number.
String nationalDigits(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('+') && !trimmed.startsWith('+1')) return '';
  var digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('1') &&
      (trimmed.startsWith('+1') || digits.length > 10)) {
    digits = digits.substring(1);
  }
  if (digits.length > 10) digits = digits.substring(0, 10);
  return digits;
}

/// `+1 (555) 555-0100`. The `+1` stays even when no digits have been typed.
String formatUsPhone(String text) {
  final digits = nationalDigits(text);
  final buffer = StringBuffer(usPhonePrefix);
  if (digits.isEmpty) return buffer.toString();
  buffer.write('(');
  buffer.write(digits.length <= 3 ? digits : digits.substring(0, 3));
  if (digits.length <= 3) return buffer.toString();
  buffer.write(') ');
  buffer.write(
    digits.length <= 6 ? digits.substring(3) : digits.substring(3, 6),
  );
  if (digits.length <= 6) return buffer.toString();
  buffer.write('-');
  buffer.write(digits.substring(6));
  return buffer.toString();
}

/// Turns a U.S. mobile number into E.164, or returns null.
String? toE164(String input) {
  final digits = nationalDigits(input);
  if (digits.length != 10) return null;
  return '+1$digits';
}

/// A label safe to show after Firebase has the real number.
String maskPhoneNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return 'Text message';
  return 'Text message ending in ${digits.substring(digits.length - 4)}';
}

/// Keeps a mobile field as `+1` plus ten digits.
class UsPhoneInputFormatter extends TextInputFormatter {
  const UsPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final wanted = nationalDigits(newValue.text.substring(0, cursor)).length;
    final text = formatUsPhone(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _offsetFor(text, wanted)),
    );
  }
}

int _offsetFor(String formatted, int wanted) {
  if (wanted <= 0) return usPhonePrefix.length;
  var seen = 0;
  var skippedCountry = false;
  for (var i = 0; i < formatted.length; i++) {
    final char = formatted.codeUnitAt(i);
    if (char < 48 || char > 57) continue;
    if (!skippedCountry) {
      skippedCountry = true;
      continue;
    }
    seen++;
    if (seen == wanted) return i + 1;
  }
  return formatted.length;
}

/// Mobile number for the sign-in check. The mask supplies `+1`.
class MobileNumberField extends StatefulWidget {
  const MobileNumberField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<MobileNumberField> createState() => _MobileNumberFieldState();
}

class _MobileNumberFieldState extends State<MobileNumberField> {
  @override
  void initState() {
    super.initState();
    final text = formatUsPhone(widget.controller.text);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChainTextField(
      controller: widget.controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: const [UsPhoneInputFormatter()],
      onChanged: widget.onChanged,
      decoration: const InputDecoration(labelText: 'Mobile number'),
    );
  }
}
