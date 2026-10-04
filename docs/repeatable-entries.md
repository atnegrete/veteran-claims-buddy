# Adding more than one

When a screen lets someone add several of the same thing, use `RepeatableEntries` and `EntryCard` from `app/lib/forms/repeatable_entries.dart`. Service periods, deployments, and exposures already do.

## Empty

Show the form immediately. The first item can be added without another tap. There is no Add Another button yet.

## After one or more are saved

Each saved item is an `EntryCard`. Every fact is an `EntryField` with the same label the form uses, then the value. Leave off a field that has no value. On a wide card the label sits beside the value. On a narrow card the label sits above it so a long value can wrap. Remove stays at the top corner of the card.

The form is hidden. Under the cards, a navy **Add Another** button opens it. The form stays closed until that button is tapped. While the form is open, Add Another is hidden. **Cancel** is a `TextButton` and closes the form without saving.

Continue stays available. An open extra form does not have to be filled.

Removing the last item shows the form again.

## Buttons

| Action | Control |
| --- | --- |
| Continue | Primary `FilledButton` |
| Save the open form, and Add Another | `FilledButton` with `secondaryFilledStyle()` |
| Cancel the extra form | `TextButton` |
| Remove one saved item | `TextButton` with `dangerTextStyle()` on the card |

Remove stays on the card with the item. It is not centered.

Colors come from `appTheme()`. The card uses the higher surface so it stands apart from the page. Do not add a hex color.
