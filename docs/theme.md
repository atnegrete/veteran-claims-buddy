# Theme

**Status:** Shared styling for the Flutter app and the static site.
**Updated:** 2026-10-05

This file is the palette, type, and control rules for both surfaces. [ui.md](ui.md) is the widget list. Screens take color from `appTheme()` in `app/lib/app/app_theme.dart`. The static site takes color from `marketing-site/styles/input.css`. Do not put a new hex color on a widget or in a page.

The app now carries sand, Fraunces, and Source Sans 3 in `appTheme()`. Take them from the theme, `AppColors`, and the shared widgets in [ui.md](ui.md). Do not set sand, a font family, or a weight on a screen by hand.

Vector files use the same values. See [brand-tokens.md](../brand/brand-tokens.md).

## Color

Dark theme only. One blue family, sand as a highlight, red only for danger and errors.

| Token | Value | App | Site CSS | Where |
| --- | --- | --- | --- | --- |
| Navy | `#1F4E79` | `AppColors.navy` | `--color-navy` | The mark. A control that adds a row. Step-number fill on the site. |
| Blue | `#3B82F6` | `AppColors.blue` | `--color-action` | Primary buttons, focus, checkbox accent |
| Blue wash | `#3B82F6` at 24% | Selected tab or rail item | Not used | Selection behind a nav row |
| Canvas | `#10151C` | `AppColors.canvas` | `--color-canvas` | Page background |
| Rail | `#171C26` | `AppColors.rail` | Not used | App bottom bar and navigation rail |
| Card | `#1A2332` | `AppColors.card` | `--color-card` | Cards, menus, dialogs |
| Line | `#2C3A50` | `AppColors.line` | `--color-line` | Borders and the quiet or secondary outline |
| Text | `#F8FAFC` | `AppColors.text` | `--color-ink` | Titles, body, labels on a button |
| Muted | `#94A3B8` | `AppColors.textMuted` | `--color-muted` | Hints, card body, a finished step, footer links on the site |
| Sand | `#E8C39E` | `AppColors.sand` | `--color-sand` | Eyebrows, prices, step numbers, a link in a paragraph, the `InfoNote` edge |
| Danger fill | `#B91C1C` | `AppColors.dangerFill` | Not used | The button that commits the harm. White label. |
| Danger text | `#F87171` | `AppColors.dangerText` | Not used | Error sentences. The button that opens a dangerous step uses the fill, not this color, for its letters. |
| Money | `#34D399` | `AppColors.money` | Not used | The estimated dollar amount on the VA Ratings Calculator only. Not a general success color. |

Sand is a highlight. It is not a button fill. A primary button stays blue with a white label. Do not paint a button label, a badge label, or a navigation-row label sand, blue, or red. Color sits on the fill behind those words.

A link inside a paragraph may be sand and underlined. Hover returns it to text white. That is not a button.

Warning and success are not status colors for a claim step. The current step uses the primary button. A finished step is muted text. Money `#34D399` is the estimated dollar amount on the calculator. On a condition, Pursue disability compensation keeps a quiet money wash and Not on this claim keeps a quiet sand wash. Both use the gray outline until one is chosen. The chosen card takes a 2px edge in that color and a white check on a filled mark. The letters stay white or gray.

### Washes

**Static site.** The canvas is not a flat fill.

- Every page: a navy wash, about 72% navy fading to transparent, from the top left.
- Home only: that wash, plus a blue wash at about 32% from the top right.
- A paid price card: a vertical fade from navy mixed at about 58% into the card color, down to the card color. Its border is sand mixed at about 38% into the line color.
- The draft notice: navy at 50% opacity, a line along the bottom, and a 4px sand edge on the left. The sentence is text white.

**App.** Selection on a tab or rail item is the blue wash at 24%. Claim screens stay a flat canvas. Do not copy the marketing washes onto a claim screen.

## Type

Both surfaces use two Open Font License faces. The app bundles them through `app/pubspec.yaml` and draws them from `appTheme()`: Fraunces on titles, Source Sans 3 on body and labels.

| Role | Family | File |
| --- | --- | --- |
| Display | Fraunces | `marketing-site/assets/fonts/fraunces-latin-wght-normal.woff2` |
| UI and body | Source Sans 3 | `marketing-site/assets/fonts/source-sans-3-latin-wght-normal.woff2` |

Both files are variable and Latin only. Fraunces runs from 100 to 900. Source Sans 3 runs from 200 to 900. Display falls back to `ui-serif, Georgia, serif`. UI falls back to `ui-sans-serif, system-ui, sans-serif`. The site serves the files itself. It does not request Google Fonts.

The SVG wordmark stays `ui-sans-serif, system-ui, sans-serif` so the file does not depend on a licensed font. The site header draws the name in Fraunces with CSS. The app draws the name with the Flutter theme.

### Weights

| Use | Weight |
| --- | --- |
| Display headlines, card titles, prices | 560 |
| Step numbers | 600 |
| Buttons, nav, labels, eyebrows | 650 |
| Body | 400 |

560 and 650 are the site cuts from the variable files. The app bundles a single Fraunces and Source Sans 3 asset and uses the nearest standard Flutter weights the variable axis maps: `w600` for titles, buttons, and labels, `w400` for body. Standard `fontWeight` is used so a screen's `.copyWith(fontWeight:)` still works.

### Scale

Sizes assume a 16px root. The app can use the same sizes in logical pixels.

| Role | Size | Line height | Tracking | Face | Color |
| --- | --- | --- | --- | --- | --- |
| Page title | `clamp(37.6px, 5vw, 66.4px)` | 1.05 | -0.03em | Fraunces 560 | Text |
| Price | 48px | 1 | -0.03em | Fraunces 560 | Sand |
| Section title | 26.4px | tight | -0.02em | Fraunces 560 | Text |
| Lead paragraph | 20px | 1.625 | normal | Source Sans 3 | Text |
| Body | 16.8px | 1.625 | normal | Source Sans 3 | Text. Muted when it is secondary or inside a card. |
| Eyebrow | 12px | normal | 0.14em, uppercase | Source Sans 3 650 | Sand |

A long reading column stays near 68 characters. The site uses that for legal pages.

## Space and shape

| Token | Value | Where |
| --- | --- | --- |
| Card radius | 16px | Cards, on both surfaces. |
| Control radius | 12px | Buttons and fields |
| Control height | 48px | Buttons and fields |
| Card padding | 20px | Cards |
| Mark corner | 14 on a 64 tile | `brand/logo-mark.svg`. The site header draws the tile at 40px. |

A button that is alone is the full width of its card. A button beside another button, including in a dialog, gets a finite width. In the app the theme height is full width, and that width has no size inside a row, so the finite width is set on the button.

## Controls

The same roles on both surfaces. The app widgets are the implementation. The site uses the CSS classes.

| Role | Fill | Label | App widget | Site class |
| --- | --- | --- | --- | --- |
| Primary | Blue | White | `FilledButton` | `.btn` |
| Secondary | None | White | `OutlinedButton`, line border | `.btn-quiet` |
| Add a row | Navy | White | `FilledButton` with `secondaryFilledStyle()` | Not used |
| Quiet | None | White | `TextButton` | A text link that leaves the main action |
| Danger text | Red | White | `TextButton` with `dangerTextStyle()` | Not used |
| Danger fill | `#B91C1C` | White | `FilledButton` with `dangerFilledStyle()` | Not used |

Primary continues the task. Secondary is a real choice that is not the main one: Back, Close, and Cancel. Those three are outlined buttons, so the edge shows they can be pressed. An icon-only close is that same outlined button, with a close icon and a Close tooltip. It is not a text button or a bare icon button. Adding a row uses the navy fill. Quiet text stays for an existing side path that is not Back, Close, or Cancel. Danger text opens a dangerous step or removes one item. Center it when it is the only control in that block. Danger fill commits the harm.

Error copy uses `colorScheme.error` (`#F87171`). That sentence is not a label on a control.

Focus is a 2px blue outline, 3px outside the control. On the site, a quiet button's border turns sand on hover and the label stays white. A primary hover only brightens the blue.

A form field is canvas fill, line border, 12px radius, 48px tall, and text white. A disabled field drops to about 45% opacity.

### Badges

`AppBadge` in `app/lib/app/app_badge.dart` is the only badge. The label is white or gray. `AppBadge.notFiled` has no icon. The site does not draw these badges.

| Widget | Fill | Label |
| --- | --- | --- |
| `AppBadge.primary` | Navy | White. In progress, or a count such as "3 added" |
| `AppBadge.secondary` | Dark surface, outline | White. A neutral notice |
| `AppBadge.quiet` | Dark surface, outline | Gray |
| `AppBadge.danger` | Red | White |
| `AppBadge.notFiled` | Same as secondary | "Nothing is automatically filed with the VA at any point." |

## Imagery

No VA seal, eagle, flag, department wordmark, camouflage, rank insignia, or tactical styling. No "VA" in the mark. The name stays Veteran Claims Buddy. The assistant is Vet Buddy.

**Static site.** Illustrations are a lamp, paper, and a checklist. They do not show a person, a uniform, or an insignia. The hero is `marketing-site/assets/hero.jpg` (1152 by 864). Link previews use `marketing-site/assets/og.jpg` (1280 by 720).

## Static site

These pieces belong to the public pages in `/marketing-site`. They are not claim-screen patterns.

The draft notice keeps the sentence `Draft. A lawyer has not reviewed this site.`

The header is sticky. It is canvas at 86% opacity with a 16px blur, not the rail color, with a line along the bottom. It holds the mark, the name, text links, and one blue Get started button. Under 1040px the links sit in a Menu control. Under 720px the name is hidden and the mark stays. A nav label is white. The current item and the hover state are sand. That sand label is a site exception. An app navigation row stays white or gray, and selection is the blue wash.

The footer is three columns from 720px up: the name and disclaimer, product links, legal links. Footer links are muted and turn sand on hover.

Other site-only layout:

| Width | What changes |
| --- | --- |
| 560px and under | The calculator Add row stacks |
| 720px | Footer becomes three columns. Below that, the header name is hidden. |
| 800px and up | Feature cards are three columns. Paid prices sit side by side. The calculator splits into inputs and a result. |
| 900px and up | The home hero is two columns |
| Page width | `min(1120px, 100% - 40px)` |
| Page padding | 40px top, 64px bottom |

Page patterns on the site:

- **Home.** Eyebrow, display title, lead, muted disclaimer, primary and quiet actions, hero image, three cards, then a pricing strip.
- **Steps.** A sand numeral in a navy circle, a line rule between steps, then a muted note with a 3px sand edge.
- **Prices.** One quiet card for the workspace. Two focus cards for the paid products, amount in sand at 48px. Print and Mail is a quiet card.
- **FAQ.** A question at 18px. The open mark is Fraunces in sand. The answer is muted, about 65 characters wide.
- **Support.** One card. The email is Fraunces, about 23px, sand, and not underlined.
- **Legal.** A 68-character column. Headings are Fraunces at 24px.
- **Redirect.** Sign-in and Get started center the mark, the title, and one primary button.

A closing note uses a 3px sand edge and muted text. A body link is sand and underlined.

## In the app

These are wired into `appTheme()`, `AppColors`, and `app/lib/app/app_ui.dart`. Use them from there, not by hand on a screen.

- Sand `#E8C39E` as `AppColors.sand`. Eyebrows, prices, and the `InfoNote` edge.
- Fraunces on titles and Source Sans 3 on body and labels, bundled in `app/pubspec.yaml`.
- Standard weights: `w600` for titles, buttons, and labels, `w400` for body.
- Card radius 16px. Controls stay 12px.
- `Eyebrow`, `LeadText`, `ScreenIntro`, `ErrorText`, `InfoNote`, and `AppNavRow` for intros, error lines, legal notes, and nav rows.

Leave the claim canvas flat. Leave danger red as it is. Keep button, badge, and navigation-row labels white or gray.
