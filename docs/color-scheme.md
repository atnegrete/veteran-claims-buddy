# Color scheme

Dark theme only. One blue family for the product. Red is only for danger and errors. Tokens live in `app/lib/app/app_theme.dart` as `AppColors`. Screens take color from `appTheme()`. Do not put a new hex color on a widget.

**Very important.** A label on a badge, a button, or a navigation row is white or gray. The fill carries blue or red. Do not paint those letters with `primary` or `error`. See `docs/ui.md`.

## Blue

| Token | Color | Where |
| --- | --- | --- |
| Navy | `#1F4E79` | Seed color, the V mark |
| Blue | `#3B82F6` | Primary buttons, links, focus, selected nav |
| Blue wash | `#3B82F6` at 24% | Selected tab or rail item |

## Surfaces

Same blue, darker.

| Token | Color | Where |
| --- | --- | --- |
| Canvas | `#10151C` | Page background |
| Rail | `#171C26` | Bottom bar and navigation rail |
| Card | `#1A2332` | Cards, menus, and dialogs |
| Line | `#2C3A50` | Borders and the secondary button outline |

## Text

| Token | Color | Where |
| --- | --- | --- |
| Primary text | `#F8FAFC` | Titles and body |
| Secondary text | `#94A3B8` | Hints, status, helper lines |

## Red

| Token | Color | Where |
| --- | --- | --- |
| Danger fill | `#B91C1C` | The button that commits the harm. White label. |
| Danger text | `#F87171` | A button that opens the dangerous step or removes one item, and error messages |

## Buttons

| Role | Widget | When |
| --- | --- | --- |
| Primary | `FilledButton` | The action that continues |
| Secondary | `OutlinedButton` | A real choice that is not the main one. Gray outline. Back, Close, and Cancel. |
| Add a row | `FilledButton` with `secondaryFilledStyle()` | Adds one item to a list. Navy fill, white label. |
| Quiet | `TextButton` | Leave, cancel, or a side path. White label. |
| Danger text | `TextButton` with `dangerTextStyle()` | Opens a dangerous step, or removes one item. White label on red. Center it when it is the only control in that block. |
| Danger fill | `FilledButton` with `dangerFilledStyle()` | Commits the harm. White label on red. |

A button that is alone stays the full width of the card. A button beside another button, including in a dialog, overrides `minimumSize` with a finite width. The theme height is full width, and that width has no size inside a row.

The current step of a claim uses the primary blue button. A finished step is secondary text, `#94A3B8`. Do not add a separate progress color. Warning and success wait until a screen needs them.

## Badges

**Very important.** `AppBadge` in `app/lib/app/app_badge.dart` is the only badge. The label is white or gray. See `docs/ui.md`.

| Widget | Fill | Label |
| --- | --- | --- |
| `AppBadge.primary` | Navy | White. In progress, or a count such as "3 added" |
| `AppBadge.secondary` | Dark surface, outline | White. A neutral notice |
| `AppBadge.quiet` | Dark surface, outline | Gray |
| `AppBadge.danger` | Red | White |
| `AppBadge.notFiled` | Same as secondary | "Nothing is filed with the VA at this step." No icon. |
