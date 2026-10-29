import 'package:flutter/material.dart';

import 'form_actions.dart';
import 'step_rail.dart';

/// A stepped form with back, next, and a way to reopen a step already reached.
///
/// Steps after [farthestIndex] stay closed so the form cannot be skipped ahead.
class StepForm extends StatelessWidget {
  const StepForm({
    super.key,
    required this.labels,
    required this.currentIndex,
    required this.farthestIndex,
    required this.onStepSelected,
    required this.child,
    this.onNext,
    this.nextLabel = 'Continue',
    this.busy = false,
  });

  final List<String> labels;
  final int currentIndex;
  final int farthestIndex;
  final ValueChanged<int> onStepSelected;
  final Widget child;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = farthestIndex < currentIndex ? currentIndex : farthestIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step ${currentIndex + 1} of ${labels.length}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _StepTrack(
          labels: labels,
          currentIndex: currentIndex,
          farthestIndex: reached,
          onStepSelected: busy ? null : onStepSelected,
        ),
        const SizedBox(height: 16),
        child,
        if (onNext != null || currentIndex > 0)
          FormActions(
            onBack: currentIndex > 0
                ? () => onStepSelected(currentIndex - 1)
                : null,
            onPrimary: onNext,
            primaryLabel: nextLabel,
            busy: busy,
          ),
      ],
    );
  }
}

class _StepTrack extends StatelessWidget {
  const _StepTrack({
    required this.labels,
    required this.currentIndex,
    required this.farthestIndex,
    required this.onStepSelected,
  });

  final List<String> labels;
  final int currentIndex;
  final int farthestIndex;
  final ValueChanged<int>? onStepSelected;

  @override
  Widget build(BuildContext context) {
    return StepRail(
      steps: [
        for (var index = 0; index < labels.length; index++)
          StepRailItem(
            label: labels[index],
            state: index == currentIndex
                ? StepRailState.current
                : index < currentIndex
                ? StepRailState.done
                : index <= farthestIndex
                ? StepRailState.open
                : StepRailState.locked,
            onTap:
                index <= farthestIndex &&
                    index != currentIndex &&
                    onStepSelected != null
                ? () => onStepSelected!(index)
                : null,
          ),
      ],
    );
  }
}
