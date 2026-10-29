---
name: color-scheme
description: Applies the Veteran Claims Buddy dark palette and button roles (primary, secondary, quiet, danger fill, danger text). Use when adding or changing buttons, colors, the Flutter theme, error text, or screen styling.
---

# Color scheme

Read `docs/theme.md` and implement through `app/lib/app/app_theme.dart`.

- Primary action: `FilledButton`.
- Secondary choice: `OutlinedButton`. Gray outline. Back, Close, and Cancel. The edge shows they can be pressed.
- Icon-only close: that same outlined button, a close icon, and a Close tooltip. Not a `TextButton` or a bare `IconButton`.
- Adding a row: `FilledButton` with `secondaryFilledStyle()`. Navy fill, white label.
- Quiet path: `TextButton` only for an existing side path that is not Back, Close, or Cancel. White label.
- Opens a dangerous step or removes one item: `TextButton` with `dangerTextStyle()`. White label on red. Center it when it is the only control in that block.
- Commits the harm: `FilledButton` with `dangerFilledStyle()`. White label on red.
- Error copy: `ErrorText` from `app/lib/app/app_ui.dart`, the one way to show `colorScheme.error`. That is a sentence, not a label on a control.
- The current claim step uses the primary button. A finished step uses secondary text. Do not add a progress color.

Do not add a hex color on a screen. A button beside another button needs a finite `minimumSize`. The theme height is full width, and that width has no size inside a row.

**Very important.** Read `docs/ui.md`. Text on a badge, a button, or a navigation row is white or gray. Color sits on the fill. `AppBadge` is the only badge. `AppBadge.notFiled` has no icon.

Sand, Fraunces, and Source Sans 3 are in `appTheme()`. Use `Eyebrow`, `LeadText`, `ScreenIntro`, `ErrorText`, `InfoNote`, and `AppNavRow` from `app/lib/app/app_ui.dart`. Keep legal and safety copy and tighten it. Cut dev-note, vendor, and future-feature prose from the UI.
