import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The only badge. Color is the fill. The label is white or gray.
enum AppBadgeRole { primary, secondary, quiet, danger }

class AppBadge extends StatelessWidget {
  const AppBadge._({required this.role, this.label, this.icon});

  /// Navy fill, white label. A count or a part that is in progress.
  const AppBadge.primary({required String label, IconData? icon})
    : this._(role: AppBadgeRole.primary, label: label, icon: icon);

  /// Outline, white label. A neutral notice.
  const AppBadge.secondary({required String label, IconData? icon})
    : this._(role: AppBadgeRole.secondary, label: label, icon: icon);

  /// Outline, gray label. Not started, or a small status mark.
  const AppBadge.quiet({String? label, IconData? icon})
    : this._(role: AppBadgeRole.quiet, label: label, icon: icon);

  /// Red fill, white label.
  const AppBadge.danger({required String label, IconData? icon})
    : this._(role: AppBadgeRole.danger, label: label, icon: icon);

  /// The repeated line on a claim step. No icon.
  const AppBadge.notFiled()
    : this._(
        role: AppBadgeRole.secondary,
        label: 'Nothing is filed with the VA at this step.',
      );

  final AppBadgeRole role;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _BadgeColors.resolve(role, theme.colorScheme);
    final hasLabel = label != null && label!.isNotEmpty;
    final mark = icon == null
        ? null
        : Icon(icon, size: 14, color: colors.foreground);
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textMax = math.max(0.0, constraints.maxWidth - 48);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hasLabel ? 10 : 7,
                vertical: hasLabel ? 5 : 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?mark,
                  if (mark != null && hasLabel) const SizedBox(width: 6),
                  if (hasLabel)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: textMax),
                      child: Text(
                        label!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static _BadgeColors resolve(AppBadgeRole role, ColorScheme scheme) {
    switch (role) {
      case AppBadgeRole.primary:
        return _BadgeColors(
          background: scheme.secondary,
          foreground: scheme.onSecondary,
          border: scheme.secondary,
        );
      case AppBadgeRole.secondary:
        return _BadgeColors(
          background: scheme.surface,
          foreground: scheme.onSurface,
          border: scheme.outline,
        );
      case AppBadgeRole.quiet:
        return _BadgeColors(
          background: scheme.surface,
          foreground: scheme.onSurfaceVariant,
          border: scheme.outline,
        );
      case AppBadgeRole.danger:
        return _BadgeColors(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          border: scheme.errorContainer,
        );
    }
  }
}
