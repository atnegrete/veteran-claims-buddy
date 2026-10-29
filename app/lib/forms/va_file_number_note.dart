import 'package:flutter/material.dart';

/// The VA file number label and its info icon.
///
/// The explanation is a Flutter [Tooltip]. A mouse hover shows it. A tap
/// shows it on a phone.
class VaFileNumberNote extends StatelessWidget {
  const VaFileNumberNote({super.key});

  static const message =
      'This is the number VA uses to track the claims file. '
      'For most Veterans it matches the Social Security number. '
      'Veterans who served before the mid-1970s may have a different '
      '8- or 9-digit number. It can be left blank when the Social Security '
      'number is on the form. It is printed on a VA decision letter, and on '
      'a benefit summary letter: https://www.va.gov/records/download-va-letters/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'VA file number',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        Tooltip(
          message: message,
          triggerMode: TooltipTriggerMode.tap,
          constraints: const BoxConstraints(maxWidth: 320),
          showDuration: const Duration(seconds: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.info_outline,
              semanticLabel: 'About the VA file number',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
