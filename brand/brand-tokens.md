# Brand tokens

The app colors live in `app/lib/app/app_theme.dart` as `AppColors`. This page records the same values for the vector files. Do not add a second palette on a screen.

The shared theme for the app and the static site is [docs/theme.md](../docs/theme.md). Screens still take color from `AppColors` until that file's missing tokens are added there.

| Token | Value | Use |
| --- | --- | --- |
| Navy | `#1F4E79` | Mark fill |
| Blue | `#3B82F6` | Primary actions |
| Canvas | `#10151C` | Page background, icon backdrop |
| Rail | `#171C26` | Navigation |
| Card | `#1A2332` | Cards |
| Line | `#2C3A50` | Borders |
| Text | `#F8FAFC` | The V stroke and the name |
| Muted text | `#94A3B8` | Secondary copy |
| Danger fill | `#B91C1C` | A button that commits harm |
| Danger text | `#F87171` | Errors |
| Success | `#047857` | A finished part. Green fill, white label and check |

Warning is not defined yet.

Type is the platform sans. The SVG wordmark names `ui-sans-serif, system-ui, sans-serif` so it can be replaced without a licensed font file. The app draws the name with the Flutter theme, not the SVG text.

Spacing in the wide sign-in panel is 16 between the mark and the description, and 48 between that panel and the form. The mark corner radius is 14 on a 64-point tile. The app icon source uses the same proportion on a 1024 canvas.

## Do not make it look official

- No VA seal, eagle, flag, or department wordmark.
- No "VA" in the logo.
- No camouflage, rank insignia, or tactical styling.
- The name stays Veteran Claims Buddy. The assistant is Vet Buddy.
