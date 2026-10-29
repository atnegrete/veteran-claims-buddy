import 'package:flutter/material.dart';

import 'step_rail.dart';

/// A list and the form that opens from it.
///
/// A wide pane shows both. A narrow pane hides the list. When [steps] is set,
/// that narrow pane shows [NestedStepBar] above the form. Otherwise it shows
/// only the form. [detail] stays mounted while the form is closed so the route
/// can stay alive.
class NestedSplit extends StatelessWidget {
  const NestedSplit({
    super.key,
    required this.master,
    required this.detail,
    required this.open,
    this.steps,
  });

  final Widget master;
  final Widget detail;
  final bool open;

  /// The parts of this list. Set on a condition so a narrow pane shows a step
  /// bar instead of the cards. A form leaves this null.
  final List<NestedStep>? steps;

  static const breakWidth = 840.0;
  static const masterWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakWidth;
        final showMaster = !open || wide;
        final showDetail = open;
        final showSteps = !wide && open && (steps?.isNotEmpty ?? false);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (showSteps)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NestedStepBar(steps: steps!),
                  const SizedBox(height: 16),
                  Expanded(
                    child: NestedStepScope(inStepFlow: true, child: detail),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showMaster && showDetail)
                    SizedBox(width: masterWidth, child: master),
                  if (showMaster && showDetail) const SizedBox(width: 16),
                  if (showMaster && !showDetail) Expanded(child: master),
                  if (showDetail) Expanded(child: detail),
                ],
              ),
            if (!showMaster) Offstage(child: master),
            if (!showDetail) Offstage(child: detail),
          ],
        );
      },
    );
  }
}

/// Tells the open form that the card list is hidden.
///
/// The form pane is narrower than the page, so the form cannot measure this
/// itself. [FormsWorkspace] sets it from the page width.
class NestedListHidden extends InheritedWidget {
  const NestedListHidden({
    super.key,
    required this.hidden,
    required super.child,
  });

  final bool hidden;

  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NestedListHidden>();
    return scope?.hidden ?? false;
  }

  @override
  bool updateShouldNotify(NestedListHidden oldWidget) {
    return hidden != oldWidget.hidden;
  }
}

/// Tells a [NestedForm] it sits under a [NestedStepBar].
///
/// The step bar already names the current part, so the form drops its own
/// title to avoid showing it twice.
class NestedStepScope extends InheritedWidget {
  const NestedStepScope({
    super.key,
    required this.inStepFlow,
    required super.child,
  });

  final bool inStepFlow;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NestedStepScope>();
    return scope?.inStepFlow ?? false;
  }

  @override
  bool updateShouldNotify(NestedStepScope oldWidget) {
    return inStepFlow != oldWidget.inStepFlow;
  }
}

/// One part in a [NestedStepBar].
///
/// [title] is the full name shown in the caption. [shortTitle] is the compact
/// label under the rail circle. [onPressed] is null when the part is closed.
class NestedStep {
  const NestedStep({
    required this.title,
    required this.shortTitle,
    required this.selected,
    this.done = false,
    this.enabled = true,
    this.onPressed,
  });

  final String title;
  final String shortTitle;
  final bool selected;

  /// A finished part. The rail circle shows a check.
  final bool done;

  /// A closed part. The rail circle is muted and does not open.
  final bool enabled;
  final VoidCallback? onPressed;
}

/// The step flow for a condition on a narrow pane.
///
/// A "Step n of m" caption with the full current part name sits above a
/// [StepRail]: numbered circles joined by a line, a check on a finished part,
/// a filled current part, and a muted locked part. The rail scrolls and
/// centers the current part when the steps do not fit.
class NestedStepBar extends StatelessWidget {
  const NestedStepBar({super.key, required this.steps});

  final List<NestedStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = steps.length;
    final currentIndex = steps.indexWhere((step) => step.selected);
    final current = currentIndex >= 0 ? steps[currentIndex] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null) ...[
          Text(
            'Step ${currentIndex + 1} of $total',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(current.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
        ],
        StepRail(
          steps: [
            for (final step in steps)
              StepRailItem(
                label: step.shortTitle,
                state: step.selected
                    ? StepRailState.current
                    : !step.enabled
                    ? StepRailState.locked
                    : step.done
                    ? StepRailState.done
                    : StepRailState.open,
                onTap: !step.enabled || step.selected ? null : step.onPressed,
              ),
          ],
        ),
      ],
    );
  }
}

/// An outlined close control. The edge shows it can be pressed.
class NestedCloseButton extends StatelessWidget {
  const NestedCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close',
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: const Icon(Icons.close, semanticLabel: 'Close'),
      ),
    );
  }
}

/// A card that fills the pane. The title stays put. The body scrolls,
/// unless [expandChild] is set and the child scrolls itself.
///
/// The scrollbar sits in a gutter beside the form. It does not cover it.
class NestedForm extends StatefulWidget {
  const NestedForm({
    super.key,
    required this.child,
    this.title,
    this.intro,
    this.notice,
    this.headerAction,
    this.footer,
    this.expandChild = false,
  });

  final Widget child;
  final String? title;
  final String? intro;
  final Widget? notice;

  /// Sits at the top right of the card, beside [title]. A close button.
  final Widget? headerAction;
  final Widget? footer;
  final bool expandChild;

  @override
  State<NestedForm> createState() => _NestedFormState();
}

class _NestedFormState extends State<NestedForm> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A step bar already names the current part, so the form drops its title.
    final title = NestedStepScope.of(context) ? null : widget.title;
    final body = widget.expandChild
        ? widget.child
        : Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              child: widget.child,
            ),
          );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null ||
                widget.intro != null ||
                widget.notice != null ||
                widget.headerAction != null) ...[
              if (title != null || widget.headerAction != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleLarge),
                      )
                    else
                      const Spacer(),
                    if (widget.headerAction != null) ...[
                      if (title != null) const SizedBox(width: 12),
                      widget.headerAction!,
                    ],
                  ],
                ),
              if (widget.intro != null) ...[
                if (title != null) const SizedBox(height: 8),
                Text(
                  widget.intro!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (widget.notice != null) ...[
                const SizedBox(height: 12),
                widget.notice!,
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],
            Expanded(child: body),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
  }
}

/// One row in a [NestedSplit] list. [trailing] is the progress mark.
class SelectRow extends StatelessWidget {
  const SelectRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
    this.trailing,
    this.leading,
    this.accent,
  });

  final String title;
  final String subtitle;
  final bool selected;

  /// Null when the row is closed and must not open.
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;

  /// A left edge on this row. The fill stays the row color.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = onTap == null
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: accent == null
                ? null
                : Border(left: BorderSide(color: accent!, width: 3)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: titleColor,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
