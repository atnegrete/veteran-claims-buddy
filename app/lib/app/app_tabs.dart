import 'package:flutter/material.dart';

/// One tab in an [AppTabs] strip.
class AppTab {
  const AppTab({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// The one tabbed-view control. A row of equal-width tabs over a divider line,
/// with the active tab washed in the selection blue and underlined by a blue
/// indicator. The active label is `onSurface` (white) and the rest are
/// `onSurfaceVariant` (gray); color sits on the wash and the indicator, never
/// on the letters.
///
/// This renders only the tab strip. Place the selected panel directly under it
/// so the two read as one tabbed view, and swap that panel on [selected]. Do
/// not hand-build a second row-of-buttons tab bar.
class AppTabs extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<AppTab> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _TabCell(
                  tab: tabs[i],
                  active: i == selected,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final AppTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? null : onTap,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tab.icon != null) ...[
                        Icon(tab.icon, size: 18, color: color),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          tab.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: color,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 2.5,
                    color: active ? scheme.primary : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
