import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_ui.dart';
import 'text_input_chain.dart';

const mailingStreetMax = 150;
const mailingUnitMax = 10;
const mailingCityMax = 50;

/// U.S. states and the District of Columbia. The stored value is the abbreviation.
const usStates = <String, String>{
  'AL': 'Alabama',
  'AK': 'Alaska',
  'AZ': 'Arizona',
  'AR': 'Arkansas',
  'CA': 'California',
  'CO': 'Colorado',
  'CT': 'Connecticut',
  'DE': 'Delaware',
  'DC': 'District of Columbia',
  'FL': 'Florida',
  'GA': 'Georgia',
  'HI': 'Hawaii',
  'ID': 'Idaho',
  'IL': 'Illinois',
  'IN': 'Indiana',
  'IA': 'Iowa',
  'KS': 'Kansas',
  'KY': 'Kentucky',
  'LA': 'Louisiana',
  'ME': 'Maine',
  'MD': 'Maryland',
  'MA': 'Massachusetts',
  'MI': 'Michigan',
  'MN': 'Minnesota',
  'MS': 'Mississippi',
  'MO': 'Missouri',
  'MT': 'Montana',
  'NE': 'Nebraska',
  'NV': 'Nevada',
  'NH': 'New Hampshire',
  'NJ': 'New Jersey',
  'NM': 'New Mexico',
  'NY': 'New York',
  'NC': 'North Carolina',
  'ND': 'North Dakota',
  'OH': 'Ohio',
  'OK': 'Oklahoma',
  'OR': 'Oregon',
  'PA': 'Pennsylvania',
  'RI': 'Rhode Island',
  'SC': 'South Carolina',
  'SD': 'South Dakota',
  'TN': 'Tennessee',
  'TX': 'Texas',
  'UT': 'Utah',
  'VT': 'Vermont',
  'VA': 'Virginia',
  'WA': 'Washington',
  'WV': 'West Virginia',
  'WI': 'Wisconsin',
  'WY': 'Wyoming',
};

bool validMailingState(String value) => usStates.containsKey(value);

bool validMailingZip(String value) =>
    RegExp(r'^\d{5}(-\d{4})?$').hasMatch(value);

/// Keeps a ZIP code as `#####` or `#####-####` as the user types.
class ZipCodeInputFormatter extends TextInputFormatter {
  const ZipCodeInputFormatter();

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
      if (i == 5) buffer.write('-');
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

class ZipCodeField extends StatelessWidget {
  const ZipCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ChainTextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [ZipCodeInputFormatter()],
      onChanged: onChanged,
      decoration: const InputDecoration(labelText: 'ZIP code'),
    );
  }
}

class MailingAddressFields extends StatelessWidget {
  const MailingAddressFields({
    super.key,
    required this.street,
    required this.unit,
    required this.city,
    required this.zip,
    required this.state,
    required this.onState,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController street;
  final TextEditingController unit;
  final TextEditingController city;
  final TextEditingController zip;
  final String state;
  final ValueChanged<String> onState;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final streetField = ChainTextField(
      controller: street,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      maxLength: mailingStreetMax,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      decoration: const InputDecoration(labelText: 'Street address'),
    );
    final unitField = ChainTextField(
      controller: unit,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      maxLength: mailingUnitMax,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      decoration: const InputDecoration(
        labelText: 'Apartment or unit (optional)',
      ),
    );
    final cityField = ChainTextField(
      controller: city,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      maxLength: mailingCityMax,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      decoration: const InputDecoration(labelText: 'City'),
    );
    final stateField = DropdownButtonFormField<String>(
      key: ValueKey(state),
      isExpanded: true,
      initialValue: usStates.containsKey(state) ? state : null,
      decoration: const InputDecoration(labelText: 'State'),
      items: [
        for (final entry in usStates.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled
          ? (value) {
              if (value == null) return;
              onState(value);
            }
          : null,
    );
    final zipField = ZipCodeField(
      controller: zip,
      enabled: enabled,
      onChanged: (_) => onChanged?.call(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow('Mailing address'),
            const SizedBox(height: 12),
            streetField,
            const SizedBox(height: 12),
            unitField,
            const SizedBox(height: 12),
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: cityField),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: stateField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: zipField),
                ],
              )
            else ...[
              cityField,
              const SizedBox(height: 12),
              stateField,
              const SizedBox(height: 12),
              zipField,
            ],
          ],
        );
      },
    );
  }
}
