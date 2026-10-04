import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// One labeled fact on an [EntryCard]. Use the same words as the form.
class EntryField {
  const EntryField({required this.label, required this.value});

  final String label;
  final String value;
}

/// One saved item. Each fact has a label. A blank value is left off.
///
/// Wide cards put the label beside the value. Narrow cards put it above.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.fields, required this.onRemove});

  final List<EntryField> fields;
  final VoidCallback? onRemove;

  static const besideWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final field in fields)
        if (field.value.trim().isNotEmpty) field,
    ];
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final beside = constraints.maxWidth >= besideWidth;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _EntryFieldLine(field: shown[i], beside: beside),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            TextButton(
              style: dangerTextStyle().copyWith(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryFieldLine extends StatelessWidget {
  const _EntryFieldLine({required this.field, required this.beside});

  final EntryField field;
  final bool beside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      field.label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final value = Text(field.value, style: theme.textTheme.bodyMedium);
    if (!beside) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, const SizedBox(height: 2), value],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 176, child: label),
        const SizedBox(width: 12),
        Expanded(child: value),
      ],
    );
  }
}

/// Empty: the form is open. After one item is saved, the form closes and
/// Add Another opens it again.
class RepeatableEntries extends StatelessWidget {
  const RepeatableEntries({
    super.key,
    required this.entries,
    required this.form,
    required this.addingAnother,
    required this.onAddAnother,
    this.onCancel,
  });

  final List<Widget> entries;
  final Widget form;
  final bool addingAnother;
  final VoidCallback? onAddAnother;
  final VoidCallback? onCancel;

  bool get _showForm => entries.isEmpty || addingAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          entries[i],
        ],
        if (entries.isNotEmpty && !_showForm) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: secondaryFilledStyle(),
            onPressed: onAddAnother,
            child: const Text('Add Another'),
          ),
        ],
        if (_showForm) ...[
          if (entries.isNotEmpty) const SizedBox(height: 16),
          form,
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
