import 'package:flutter/material.dart';

/// A list and the form that opens from it.
///
/// A wide pane shows both. A narrow pane shows the form and hides the list.
/// [detail] stays mounted while the form is closed so the route can stay alive.
class NestedSplit extends StatelessWidget {
  const NestedSplit({
    super.key,
    required this.master,
    required this.detail,
    required this.open,
  });

  final Widget master;
  final Widget detail;
  final bool open;

  static const breakWidth = 840.0;
  static const masterWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakWidth;
        final showMaster = !open || wide;
        final showDetail = open;
        return Stack(
          fit: StackFit.expand,
          children: [
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

/// A card that fills the pane. The title stays put. The body scrolls,
/// unless [expandChild] is set and the child scrolls itself.
class NestedForm extends StatefulWidget {
  const NestedForm({
    super.key,
    required this.child,
    this.title,
    this.intro,
    this.notice,
    this.footer,
    this.expandChild = false,
  });

  final Widget child;
  final String? title;
  final String? intro;
  final Widget? notice;
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
            if (widget.title != null ||
                widget.intro != null ||
                widget.notice != null) ...[
              if (widget.title != null)
                Text(widget.title!, style: theme.textTheme.titleLarge),
              if (widget.intro != null) ...[
                if (widget.title != null) const SizedBox(height: 8),
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
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
