import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_input_chain.dart';

/// Keeps an SSN field as `###-##-####` while the user types. Digits only; the
/// dashes are part of the mask. A mask does not show a character count
/// (`.cursor/rules/formatted-inputs.mdc`).
class SsnInputFormatter extends TextInputFormatter {
  const SsnInputFormatter();

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
    final clipped = digits.length > 9 ? digits.substring(0, 9) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 3 || i == 5) buffer.write('-');
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

/// An SSN in `###-##-####`.
class SsnField extends StatelessWidget {
  const SsnField({super.key, required this.controller, this.enabled = true});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ChainTextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [SsnInputFormatter()],
      decoration: const InputDecoration(
        labelText: 'Social Security number',
        hintText: '###-##-####',
      ),
    );
  }
}

/// A VA file number: 8 or 9 digits, digits only.
class VaFileNumberField extends StatelessWidget {
  const VaFileNumberField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.showLabel = true,
  });

  final TextEditingController controller;
  final bool enabled;

  /// When a screen puts its own label beside an info note, the field label
  /// stays off so the name is not shown twice.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ChainTextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      decoration: InputDecoration(
        labelText: showLabel ? 'VA file number' : null,
        hintText: '8 or 9 digits',
        //helperText: 'Often the same as your SSN. Leave blank if unsure.',
      ),
    );
  }
}
