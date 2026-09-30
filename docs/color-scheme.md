# Color scheme

Dark theme only. One blue family for the product. Red is only for danger and errors. Tokens live in `app/lib/app/app_theme.dart` as `AppColors`. Screens take color from `appTheme()`. Do not put a new hex color on a widget.

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
| Secondary | `OutlinedButton` | A real choice that is not the main one |
| Quiet | `TextButton` | Leave, cancel, or a side path |
| Danger text | `TextButton` with `dangerTextStyle()` | Opens a dangerous step, or removes one item. Center it when it is the only control in that block. |
| Danger fill | `FilledButton` with `dangerFilledStyle()` | Commits the harm |

Form buttons stay the full width of the card. Dialog buttons override `minimumSize` with a finite width so the row does not overflow.

Warning and success wait until a screen needs them.
