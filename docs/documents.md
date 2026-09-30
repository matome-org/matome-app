# Documents

## Select and open

In the explorer, a click, a tap, or the arrow keys select a document; they
never open it. Double-click, double-tap, Enter, or **Open** in the context
menu opens the document screen. Opening a folder in the sidebar lists it
without opening any of its files. The context menu lists the commands that
act on the selected item first, then the commands for the folder under a
divider.

## Document screen

Every document opens in the same screen. The header shows the space and
folder path above the title; **Back to files** or Escape returns to the
explorer. The tabs are Preview (1), Edit (2), Versions (3) and, when the
controlled-documents add-on applies, Reviews (4). Each tab has its own command
bar: select what to act on, then choose the command.

- **Preview** renders Markdown, images, and plain text up to 1 MiB. Any
  other file shows that it has no preview; **Download** (D) saves the version
  shown.
- **Edit** opens the current version of a Markdown or text document. Ctrl+S
  or Ctrl+Enter saves. Saving publishes the text as the next version, or
  opens a review when the document is managed. Leaving with unsaved changes
  asks first. A dropped local `.md` file replaces the draft.
- **Versions** lists the published versions, newest first. **Show this
  version** previews an earlier one; only the current version can be edited.

Add-ons extend the screen but do not replace it. Space management lives in
Settings, not on the document.

## Images

Pasting, dropping, or choosing an image while editing Markdown uploads it to
the `assets` folder at the space root. The app creates that folder on first
use. An image already stored with the same checksum is reused, and a name
already taken gets a short random suffix. The editor writes a link that pins the
uploaded version:

```markdown
![logo.png](matome:asset/42?version=<version id>)
```

On save, every pinned image and every linked file is declared to Core as a
reference of the new version. Images from other sites stay blocked until the
reader chooses **Load external images**.

## Links to files

While editing Markdown:

| Typed | Suggests | Writes |
| --- | --- | --- |
| `@` and part of a name | files of the space | `[name](matome:doc/<id>)`, a Core reference |
| `/` and part of a name | files of the space, with their paths | `[name](/folder/name)`, plain Markdown |
| `#` at a line's start | Link a file, Link a file by path, Insert image | the chosen action |

`@` and `/` work at a line's start or after a space. Suggestions list files
in the document's folder first, then titles starting with the typed text. The
arrows move, Enter or Tab inserts, and Escape closes; a click or tap also
inserts. A `#` followed by a space stays a heading.

An `@` link to an image embeds it at its current version. An `@` link to a
document follows its current version, unless the space rule requires pinned
versions. A `/` link is not a reference: renaming or moving the file breaks
it, and an image linked this way appears as a link, not embedded.

In Preview, a click on a linked file opens it. The **Linked files** row
under the text repeats those links as buttons that Tab, Enter, and touch
reach. A path that no longer leads to a file shows a notice.

Suggestions use the documents list `q` title filter. Core implements it,
but `docs/api.md` in matome-core does not yet document it.
