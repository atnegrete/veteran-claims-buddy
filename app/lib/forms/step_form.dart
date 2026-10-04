import 'package:flutter/material.dart';

import 'form_actions.dart';

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            _StepDot(
              label: labels[index],
              index: index,
              current: index == currentIndex,
              complete: index < currentIndex,
              open: index <= farthestIndex,
              showLine: index < labels.length - 1,
              lineComplete: index < currentIndex,
              onTap:
                  index <= farthestIndex &&
                      index != currentIndex &&
                      onStepSelected != null
                  ? () => onStepSelected!(index)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.index,
    required this.current,
    required this.complete,
    required this.open,
    required this.showLine,
    required this.lineComplete,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool current;
  final bool complete;
  final bool open;
  final bool showLine;
  final bool lineComplete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current ? scheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current ? scheme.primary : scheme.outline,
                      width: current ? 0 : 1.5,
                    ),
                  ),
                  child: complete
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        )
                      : Text(
                          '${index + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: current
                                ? scheme.onPrimary
                                : open
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: current ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showLine)
          Container(
            width: 20,
            height: 2,
            margin: const EdgeInsets.only(bottom: 18),
            color: lineComplete ? scheme.onSurfaceVariant : scheme.outline,
          ),
      ],
    );
  }
}
