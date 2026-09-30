---
name: color-scheme
description: Applies the Veteran Claims Buddy dark palette and button roles (primary, secondary, quiet, danger fill, danger text). Use when adding or changing buttons, colors, the Flutter theme, error text, or screen styling.
---

# Color scheme

Read `docs/color-scheme.md` and implement through `app/lib/app/app_theme.dart`.

- Primary action: `FilledButton`.
- Secondary choice: `OutlinedButton`.
- Quiet path: `TextButton`.
- Opens a dangerous step or removes one item: `TextButton` with `dangerTextStyle()`. Center it when it is the only control in that block.
- Commits the harm: `FilledButton` with `dangerFilledStyle()`.
- Error copy: `colorScheme.error`.

Do not add a hex color on a screen. Dialog buttons need a finite `minimumSize` because the theme height is full width.
