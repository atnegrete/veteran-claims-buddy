import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A sand, uppercase label that sits above a title.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: eyebrowStyle());
  }
}

/// The lead paragraph under a page or card title. Muted, roomy line height.
class LeadText extends StatelessWidget {
  const LeadText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// An eyebrow, a display title, and an optional lead, stacked.
///
/// Used at the top of a card or an auth and onboarding screen.
class ScreenIntro extends StatelessWidget {
  const ScreenIntro({super.key, this.eyebrow, this.title, this.lead});

  final String? eyebrow;
  final String? title;
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[Eyebrow(eyebrow!), const SizedBox(height: 8)],
        if (title != null) Text(title!, style: theme.textTheme.headlineMedium),
        if (lead != null) ...[
          if (title != null) const SizedBox(height: 10),
          LeadText(lead!),
        ],
      ],
    );
  }
}

/// A short error sentence. The one way to show `colorScheme.error` text.
class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}

/// The tone of an [InfoNote], shown as the color of its left edge.
///
/// The edge carries the color. The text stays muted, so a note never paints
/// its sentence red or green.
enum InfoNoteTone { info, success, danger }

/// A quiet callout with a colored left edge. Holds a legal, safety, or status
/// line, such as the filing, SSN, 988, or deletion lines.
///
/// Pass [text] for a single sentence, or [child] for richer content. [tone]
/// sets the edge color: sand for a neutral note, green for a good outcome, red
/// for a problem.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    this.text,
    this.child,
    this.tone = InfoNoteTone.info,
  }) : assert(text != null || child != null);

  final String? text;
  final Widget? child;
  final InfoNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edge = switch (tone) {
      InfoNoteTone.info => AppColors.sand,
      InfoNoteTone.success => AppColors.money,
      InfoNoteTone.danger => AppColors.dangerText,
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: edge, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child:
          child ??
          Text(
            text!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
    );
  }
}

/// The filing line for Forms and Package.
///
/// A sand [InfoNote]. Other claim sections do not show it.
class FilingNote extends StatelessWidget {
  const FilingNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoNote(
      text: 'Nothing is automatically filed with the VA at any point.',
    );
  }
}

/// A tappable navigation or list row. Title, optional subtitle, a trailing
/// mark or chevron, and a selection wash. Replaces the one-off `ListTile`
/// chevron rows and private row widgets across the screens.
class AppNavRow extends StatelessWidget {
  const AppNavRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.showChevron = true,
    this.accent,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool showChevron;
  final VoidCallback? onTap;

  /// Extra content inside this card, under the title row.
  final Widget? footer;

  /// A left edge on this row. The fill stays the row color.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trailingWidget =
        trailing ??
        (showChevron
            ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
            : null);
    return Material(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleSmall),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailingWidget != null) ...[
                      const SizedBox(width: 8),
                      trailingWidget,
                    ],
                  ],
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
