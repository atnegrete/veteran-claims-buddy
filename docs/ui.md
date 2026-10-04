# UI components

**Very important.** Read this before adding a badge, a button, a form footer, or a page layout.

Screens do not invent their own pills, button rows, or split panes. Use the widgets below. Less is more. If a screen needs a new look, extend one of these widgets. Do not copy a private version into the screen.

## Labels

**Very important.** Text on a badge, a button, or a navigation row is a neutral shade: `onSurface` (near white) or `onSurfaceVariant` (gray).

Color belongs on the fill behind the words. A blue or red letter is not a status. On a navy or red fill, the label is white. On a dark surface, the label is white or gray.

Do not set a label, an icon in a badge, or a sidebar row to `primary`, `error`, or any other hue.

A form error sentence can use `colorScheme.error`. That sentence is not a label on a control.

## Badges

`AppBadge` in `app/lib/app/app_badge.dart` is the only badge.

| Widget | Fill | Label | Use |
| --- | --- | --- | --- |
| `AppBadge.primary` | Navy | White | In progress, or a count such as "3 added" |
| `AppBadge.secondary` | Dark surface, outline | White | A neutral notice |
| `AppBadge.quiet` | Dark surface, outline | Gray | Not started, or a small check with no words |
| `AppBadge.danger` | Red | White | Something is wrong |
| `AppBadge.notFiled` | Same as secondary | White | "Nothing is filed with the VA at this step." |

`AppBadge.notFiled` has no icon. Do not add a decorative icon to a notice. A check is allowed only on a finished status, and the check uses the same neutral color as the label.

`ProgressMark` is the status badge for a claim part. It calls `AppBadge`. Do not draw a separate check or count.

## Buttons

Defined once in `appTheme()`.

| Role | Widget | Label |
| --- | --- | --- |
| Primary | `FilledButton` | White on blue |
| Secondary | `OutlinedButton` | White |
| Quiet | `TextButton` | White |
| Danger | `TextButton` with `dangerTextStyle()`, or `FilledButton` with `dangerFilledStyle()` | White on red |

`FormActions` in `app/lib/forms/form_actions.dart` is the Back and primary pair. Do not build that row again.

## Layout

| Widget | Where | What it does |
| --- | --- | --- |
| `ShellPage` | `app/lib/screens/shell/shell_pages.dart` | Title, then one card. Pass `maxWidth: double.infinity` when the page should fill the pane. |
| `NestedSplit` | `app/lib/forms/nested_split.dart` | List and the form that opens from it. Wide pane shows both. Narrow pane shows the form and hides the list. |
| `NestedForm` | same file | The card. Title stays put. Body scrolls. Optional notice badge and footer. |
| `SelectRow` | same file | One tappable row in that list. Selection is a wash behind the row. The title stays white. |
| `RepeatableEntries` | `app/lib/forms/repeatable_entries.dart` | Empty list shows the form. Saved items are cards. Add Another opens the form again. |
| `StepForm` | `app/lib/forms/step_form.dart` | Onboarding steps. The current step is a filled circle with a white number. |
| `showFileUpload` | `app/lib/forms/file_upload.dart` | Blocks the screen while a file uploads. Shows progress. A failure offers Retry. |
| `TextInputChain` | `app/lib/forms/text_input_chain.dart` | A form with more than one text field. Next moves to the next text field. The last single-line field is Done. The last multiline field keeps Return. |
| `secondaryFilledStyle()` | `app/lib/app/app_theme.dart` | Navy fill, white label. Adds one row to a list. The gray outline stays on Back, Close, and Cancel. |

Back closes a nested form. On a narrow pane that returns to the list.
