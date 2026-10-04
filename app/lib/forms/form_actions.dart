import 'package:flutter/material.dart';

/// Back on the left, the primary action on the right, with a divider above.
///
/// The primary button is full width only when it is the only button.
/// Under 320 points the two buttons stack, primary first.
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    this.onBack,
    this.onPrimary,
    this.primaryLabel = 'Continue',
    this.backLabel = 'Back',
    this.busy = false,
    this.busyLabel = 'Saving…',
  });

  final VoidCallback? onBack;
  final VoidCallback? onPrimary;
  final String primaryLabel;
  final String backLabel;
  final bool busy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    if (onBack == null && onPrimary == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final showBack = onBack != null;
            final showPrimary = onPrimary != null;
            final stacked =
                showBack && showPrimary && constraints.maxWidth < 320;
            final primary = showPrimary
                ? _primary(fullWidth: stacked || !showBack)
                : null;
            final back = showBack ? _back(fullWidth: stacked) : null;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [primary!, const SizedBox(height: 16), back!],
              );
            }
            if (primary != null && back != null) {
              return Row(children: [back, const Spacer(), primary]);
            }
            if (primary != null) return primary;
            return Align(alignment: Alignment.centerLeft, child: back!);
          },
        ),
      ],
    );
  }

  Widget _back({required bool fullWidth}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(fullWidth ? 0 : 112, 48),
      ),
      onPressed: busy ? null : onBack,
      child: Text(backLabel),
    );
  }

  Widget _primary({required bool fullWidth}) {
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: Size(fullWidth ? 0 : 160, 48)),
      onPressed: busy ? null : onPrimary,
      child: Text(busy ? busyLabel : primaryLabel),
    );
  }
}
