# UI components

**Very important.** Read this before adding a badge, a button, a form footer, or a page layout.

Screens do not invent their own pills, button rows, or split panes. Use the widgets below. Less is more. If a screen needs a new look, extend one of these widgets. Do not copy a private version into the screen.

## Labels

**Very important.** Text on a badge, a button, or a navigation row is a neutral shade: `onSurface` (near white) or `onSurfaceVariant` (gray).

Color belongs on the fill behind the words. A blue or red letter is not a status. On a navy or red fill, the label is white. On a dark surface, the label is white or gray.

Do not set a label, an icon in a badge, or a sidebar row to `primary`, `error`, or any other hue.

A form error sentence can use `colorScheme.error` through `ErrorText`. That sentence is not a label on a control.

## Text and intros

`app/lib/app/app_ui.dart` holds the shared text pieces. A screen does not hand-style a title paragraph, an error line, or a legal note.

| Widget | What it is |
| --- | --- |
| `Eyebrow` | A sand, uppercase label above a title. |
| `LeadText` | The muted lead paragraph under a title. `bodyLarge` in `onSurfaceVariant`. |
| `ScreenIntro` | An eyebrow, a display title, and an optional lead, stacked. Top of a card or an auth and onboarding screen. |
| `ErrorText` | A short error sentence. The one way to show `colorScheme.error` text. |
| `InfoNote` | A quiet note with a colored left edge. Holds a legal or safety line, such as the SSN, 988, or deletion lines. Pass `text` for a sentence or `child` for richer content. `tone` picks the edge: `info` is sand, `success` is money green, `danger` is red. The label stays `onSurfaceVariant`; color sits on the edge, never the letters. |
| `FilingNote` | The one way to show "Nothing is automatically filed with the VA at any point." A sand `InfoNote`. Use it on Forms and Package only. |

Keep legal and safety copy and tighten it. Cut implementation, vendor, and future-feature prose from the UI.

## Tooltips

A short explanation that floats over the page is Flutter's `Tooltip`. The star on an Intent to File row and the VA file number note both use it. Do not build a hover card, an overlay, or a note that opens in the column under the icon.

A mouse hover shows it. Set `triggerMode` to `TooltipTriggerMode.tap` when a phone tap should show it too. Without that, a phone uses a long press.

`message` is plain text. A long message sets `constraints` so the bubble wraps, and `showDuration` when a tap should leave it up long enough to read. The bubble keeps Flutter's tooltip colors. Do not paint a custom card behind the words.

`InfoNote` stays on the page. It is not a tooltip.

## Badges

`AppBadge` in `app/lib/app/app_badge.dart` is the only badge.

| Widget | Fill | Label | Use |
| --- | --- | --- | --- |
| `AppBadge.primary` | Navy | White | In progress, or a count such as "3 added" |
| `AppBadge.secondary` | Dark surface, outline | White | A neutral notice |
| `AppBadge.quiet` | Dark surface, outline | Gray | Not started, or a small check with no words |
| `AppBadge.danger` | Red | White | Something is wrong |

The filing line is not a badge. It is `FilingNote` in `app/lib/app/app_ui.dart`, and it appears on Forms and Package only. Do not add a decorative icon to a badge. A check is allowed only on a finished status, and the check uses the same neutral color as the label.

`ProgressMark` is the status badge for a claim part. It calls `AppBadge`. Do not draw a separate check or count.

## Buttons

Defined once in `appTheme()`.

| Role | Widget | Label |
| --- | --- | --- |
| Primary | `FilledButton` | White on blue |
| Secondary | `OutlinedButton` | White |
| Quiet | `TextButton` | White |
| Danger | `TextButton` with `dangerTextStyle()`, or `FilledButton` with `dangerFilledStyle()` | White on red |

Back, Close, and Cancel are outlined buttons. The edge shows they can be pressed. An icon-only close is `NestedCloseButton`: that same outlined button, a close icon, and a Close tooltip. Do not use a `TextButton` or a bare `IconButton` for those.

`FormActions` in `app/lib/forms/form_actions.dart` is the Back and primary pair. Do not build that row again.

## Layout

| Widget | Where | What it does |
| --- | --- | --- |
| `ShellPage` | `app/lib/screens/shell/shell_pages.dart` | Optional eyebrow, title, then one card. The page fills the pane. Padding stays 24 on each side, and a phone stacks inside that width. |
| `AppNavRow` | `app/lib/app/app_ui.dart` | A tappable navigation or list row. Title, optional subtitle, leading widget, a trailing mark or chevron, a selection wash, an optional left edge, and an optional note inside the card. Replaces one-off `ListTile` chevron rows and private row widgets. |
| `AppTabs` | `app/lib/app/app_tabs.dart` | The one tabbed view. A row of equal-width tabs over a divider; the active tab is washed in the selection blue and underlined in blue, its label white, the rest gray. Renders only the strip; place the selected panel directly under it and swap it on `selected`. Use this anywhere two or more views share one space. Do not hand-build a row of buttons as tabs. |
| `NestedSplit` | `app/lib/forms/nested_split.dart` | List and the form that opens from it. Wide pane shows both. Narrow pane hides the list. A condition passes `steps` and shows `NestedStepBar` above the form. A form leaves `steps` empty and shows only the form. |
| `StepRail` | `app/lib/forms/step_rail.dart` | The one step indicator. Numbered circles joined by a line. A finished step has a check. The current step is a filled circle. A locked step is muted and does not open. The rail scrolls, centers the current step, and shows outlined chevrons only when more steps sit past the edge. |
| `NestedStepBar` | `app/lib/forms/nested_split.dart` | A condition's narrow header. A "Step n of m" caption and the full current part name sit above a `StepRail`. The rail uses a short label under each circle. The form under it drops its own title so the part is named once. |
| `NestedCloseButton` | same file | Outlined close icon with a Close tooltip. Top right of a `NestedForm` when the form list is hidden. |
| `NestedForm` | same file | The card. Title stays put. Body scrolls. Optional notice, header action, and footer. |
| `SelectRow` | same file | One tappable row in that list. Selection is a wash behind the row. The title stays white. Optional leading mark and left edge. |
| `RepeatableEntries` | `app/lib/forms/repeatable_entries.dart` | Empty list shows the form. Saved items are cards. Add Another opens the form again. |
| `StepForm` | `app/lib/forms/step_form.dart` | Onboarding steps. A "Step n of m" caption, then a `StepRail`. Back and Continue stay in `FormActions`. |
| `showFileUpload` | `app/lib/forms/file_upload.dart` | Blocks the screen while a file uploads. Shows progress. A failure offers Retry. |
| `ClaimFileSection` | `app/lib/forms/claim_file_section.dart` | A filing's drop target and the files stored in that filing. Tap or drop a PDF, JPEG, or PNG. The list shows a file icon, the name, and remove. Case Info uses it for Supplemental Claim. My Uploads uses it for each filing that is on screen. |
| `TextInputChain` | `app/lib/forms/text_input_chain.dart` | A form with more than one text field. Next moves to the next text field. The last single-line field is Done. The last multiline field keeps Return. |
| `PdfPreviewPane` | `app/lib/forms/pdf_preview_pane.dart` | The one read-only PDF viewer. Shows passed bytes in a bordered frame, a spinner while they load, or an error with a retry. Never prints, shares, or changes the page. The form preview and the Nexus Letters both use it. |
| `AiChatInput` | `app/lib/ai/ai_chat_input.dart` | The one control for sending text to the assistant. A chat-style box with a round send button built into its bottom-right corner, so there is no separate Update, Next, or Send button beside it. The parent owns the controller, `busy`, and errors; `onSend` fires with the trimmed text. `maxLength` is per use and the count stays hidden until the text nears it. `allowEmptySend` keeps send active with an empty field where the action advances a flow (the gap interview). Vet Buddy, Ask for a change, and the Nexus interview all use it. |
| `AiRefinePanel` | `app/lib/ai/ai_refine_panel.dart` | The reusable "iterate with the AI" control. Shows an artifact (`child`), then an `AiChatInput` to ask for a change in plain words, and the list of changes already applied. `onSubmit` applies the change. Use it anywhere a generated artifact is refined by chatting with the model. |
| `secondaryFilledStyle()` | `app/lib/app/app_theme.dart` | Navy fill, white label. Adds one row to a list. The gray outline stays on Back, Close, and Cancel. |

On a condition, Back on Questions about this returns to the conditions list. Back on a later part returns to the previous open part. On a narrow form, the outlined close button returns to the forms list.
