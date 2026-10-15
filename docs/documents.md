# Documents

## Select and open

In the explorer, a click, a tap, or the arrow keys select a document; they
never open it. Double-click, double-tap, Enter, or **Open** in the context
menu opens the document screen. Opening a folder in the sidebar lists it
without opening any of its files. The context menu lists the commands that
act on the selected item first, then the commands for the folder under a
divider.

**Manage access** (A, or the context menu) on a selected folder or document
opens its access page in place of the list; see
[Resource access](organization-administration.md#resource-access). **Back
to files** or Escape returns to the entry.

## Trash

Del moves the selected document to the trash at once. Del on a folder asks
first in a side panel, "Move folder … to the trash?", and moves the folder
and everything in it. Each move is one `PATCH …/items/:id` with
`state: trashed` and the item's revision. The status bar then says it was
moved to the trash.

Ctrl+Z (**Restore last trash**) sets the last trashed item back to
`state: active`. **Purge last trash**, in the command sheet and without a
key, removes it for good with `DELETE …/items/:id`. A restore, a purge, or
a revision conflict leaves nothing to undo. Open reviews keep a document
and its containing folders from being trashed or purged (see
[Controlled documents](controlled-documents.md#pause-resume-and-uninstall)).

## Document screen

Every document opens on the same detail page as an item in Settings. The
top shows the way back, labelled with the space and folder path
(**Inbox › Guides**; Escape does the same), the document's name, and its
state: the version shown, **Earlier version** when it is not the current
one, **Managed**, and **Review open**. One command bar follows:

- **Edit** (E), the primary command, opens the editor on a Markdown or text
  document's current version; for any other version or file it stays in
  the bar, unusable, and says why.
- **Download** (D) saves the version shown.
- **Details** opens a side panel with the author, the number of versions,
  the tags, and the path.
- With the controlled-documents add-on, after a hairline: **Manage with
  reviews**, **Stop managing**, and **Open review** (see
  [Controlled documents](controlled-documents.md)).

The tabs are Preview (1), Versions (2), Related (3) and, while the document
is managed, Reviews (4). Each list tab holds one table; select a row, then
choose the tab's command beside the document's own.

- **Preview** renders Markdown (see [Preview](#preview)), images, and plain
  text up to 1 MiB. Any other file shows that it has no preview.
- **Versions** lists the published versions, newest first: Version, Date,
  Author. **Open**, Enter, or a double click shows that version on Preview;
  only the current version can be edited. Ctrl and a click, or Shift,
  select two versions; **Compare** opens them on a page of their own, the
  earlier against the later, or one earlier version against the current
  one (see [Compare versions](#compare-versions)).
- **Related** lists, in one table, the documents linked with this one
  through Core references: Document, Direction (**Linked from** for the
  active documents whose current version links this one, **Links to** for
  what the current version links, in order), and State (**By path**,
  **Pinned version**, or why a target does not open: nothing is at its
  path, it is in the trash, it was deleted, or the reader cannot open it).
  Sources the reader cannot open are counted under the
  table. **Open**, Enter, or a double click opens the selected document;
  **Show more** lists the next 50. The tab asks Core only when it is opened,
  and again on refresh. A `/` link appears only once the document is saved
  with it (see [Links to files](#links-to-files)).

Add-ons extend the screen but do not replace it. Space management lives in
Settings, not on the document: a command the space refuses, such as
**Manage with reviews**, stays in the bar, says what is missing, and, for
whoever may fix it, offers the command that opens Settings where it is
fixed (see [Refusals](organization-administration.md#refusals)); closing
Settings returns to the document.

## Compare versions

Two versions compared take the screen one level below the document, on a
page titled "Version 2 → version 5"; the way back, named after the
document, or Escape returns to Versions. The page has one tab, Changes,
the same as a review's (see
[Controlled documents](controlled-documents.md#changes)), and no review
commands. Each text is read through
`GET …/items/:id/download?version_id=<id>`. While two versions are
compared, the document's tabs and **Edit** wait.

After a save or an approval publishes a version, the screen shows the new
current version; an earlier version picked on Versions stays shown.

## Editing

Editing is a mode, not a tab: the editor takes the screen, under **Back to
preview** and the document's name. Its bar holds a switch of three modes,
the current one filled and outlined, then **Insert image**, **Discard**,
and **Save** (Ctrl+S or Ctrl+Enter). **Save** stays unusable, saying why,
while nothing has changed, a conflict marker remains, or an image is still
uploading.

- **Write** (Ctrl+1) shows the text alone: the editor's fixed-width font
  at 15 px, lines at 1.6 times their height, padded, in the same centred
  760 px column as the preview.
- **Preview** (Ctrl+2) shows the rendered draft in place of the text.
- **Split** (Ctrl+3) shows the text on the left and the rendered draft on
  the right, each on half the width. Scrolling either side brings the
  other to the same source line: the side under the pointer, or holding
  the keyboard, leads. Split needs a window at least 600 px wide.
- Preview and Split render the draft a quarter second after typing
  stops; only the blocks that changed are built again. Text documents
  have Write only; the other modes stay visible and say why.
- Left and Right move between the modes once the switch has the keyboard.

- A plain document saves at once: the text becomes its next version and
  the screen returns to Preview.
- A managed document's **Save** reads **Propose change** and opens a side
  panel for the comment the review starts with; see
  [Controlled documents](controlled-documents.md#propose-and-review).
- Leaving with unsaved changes, by Escape, **Back to preview**, or
  **Discard**, opens the **Unsaved changes** side panel: **Save** (with the
  comment a managed document needs), **Discard**, or **Continue editing**,
  which Escape also chooses. Leaving an unchanged editor asks nothing.

A dropped local `.md` file replaces the draft.

## Preview

Markdown renders block by block: headings on a scale, paragraphs at a 1.6
line height, lists (nested, ordered, and task items), quotes, tables with a
border and alternating rows, code in a monospace face on a fill, images,
and rules, in a centred column no wider than 760 px. Links are styled; a
click or a tap opens them. Raw HTML stays text, and HTML comments are left
out.

The app parses the Markdown itself (`parseMarkdown` in
`src/gui/documents/MarkdownBlocks.h`): CommonMark with GitHub's tables,
strikethrough, task items, and bare links, as a flat list of leaf blocks.
Each block has a kind, its text as rich text and plain text, a level, how
deep it sits in quotes and lists, its list marker, its table rows, and the
source lines it comes from. Only the blocks in sight are built.

- The wheel scrolls a constant three lines per notch and glides there; a
  touchpad scrolls by its own distance; touch drags the list.
- Up and Down, PageUp and PageDown, and Space scroll by a line or a page;
  Home and End jump to either end.
- When the width changes, the blocks are laid out again once it stops
  changing, and the block at the top stays there.
- An image keeps its space while it loads.
- A table wider than the column grows, centred on it, up to the width of
  the page, then scrolls across: Shift with the wheel, a touchpad's
  horizontal scroll, a drag of its thin scroll bar (a drag on touch), and
  Left, Right, Home, and End once Tab has put the keyboard on it. Each
  column is at least as wide as its longest word and as wide as its
  longest cell when there is room, so cells wrap between words only.
- A drag selects text across blocks, Shift and a click extend the
  selection, Ctrl+A selects the whole document, and Ctrl+C copies the
  selection as text, blocks apart by a blank line. A table, an image, or a
  rule is selected whole.

## Images

Pasting, dropping, or choosing an image while editing Markdown uploads it to
the `assets` folder at the space root. The app creates that folder on first
use. An image already stored with the same checksum is reused, and a name
already taken gets a short random suffix. The editor writes a link that pins the
uploaded version:

```markdown
![logo.png](matome:asset/<item UUID>?version=<version UUID>)
```

On save, every pinned image and every linked file is declared to Core as a
reference of the new version. Images from other sites stay blocked until the
reader chooses **Load external images**.

## Links to files

While editing Markdown:

| Typed | Suggests | Writes |
| --- | --- | --- |
| `@` and part of a name | files of the space | `[name](matome:doc/<uuid>)`, or `![name](matome:asset/<uuid>?version=<uuid>)` for an image; a Core reference |
| `/` and part of a name | files of the space, with their paths | `[name](/folder/name)`, a Core path reference |
| `#` at a line's start | Link a file, Link a file by path, Insert image | the chosen action |

`@` and `/` work at a line's start or after a space. Suggestions list files
in the document's folder first, then names starting with the typed text. The
arrows move, Enter or Tab inserts, and Escape closes; a click or tap also
inserts. A `#` followed by a space stays a heading.

The `<uuid>` in a `matome:` link is the item's or the version's UUID, in
either letter case. An old integer link (`matome:doc/<n>`) is not read.

An `@` link to an image embeds it at its current version. An `@` link to a
document follows its current version, and adds `?version=<uuid>` when the
space's controlled documents settings require pinned versions. A `/` link,
typed or suggested, is declared to Core by its path. Path references match
exactly, case included: `/Guides/Intro.md` and `/guides/intro.md` name two
different paths. A link follows whatever file is at that path, so renaming
or moving the file breaks it, and an image linked this way appears as a
link, not embedded. A link to another site (`//host`) or ending in `/` is
not declared. A managed
document whose settings require pinned versions does not declare its `/`
links, because Core refuses path references there, so they stay out of the
Related tab.

In Preview, a click on a linked file opens it. The Related tab lists the
same files in a table that the keyboard and touch reach. A path that no
longer leads to a file shows a notice.

Suggestions use the items list's `q` filter on names.

## Core requests

Paths are relative to the organization, `/api/v1/organizations/:org/`,
shown here as `…`. Changes to an item send `If-Match` with the item's
revision and an `Idempotency-Key`.

| Use | Request |
| --- | --- |
| List the folders or documents of a space | `GET …/items?space_id=<id>&kind=folder` or `kind=document` |
| Read one item | `GET …/items/:id` (a document's `tag_assignments` sit in its `document` object) |
| Create a folder or document | `POST …/items` with `kind`, `space_id`, `name`, and `parent_id` |
| Rename or move | `PATCH …/items/:id` with `name`, or `destination` |
| Trash or restore | `PATCH …/items/:id` with `state`: `trashed` or `active` |
| Purge | `DELETE …/items/:id` |
| Versions | `GET …/items/:id/versions` |
| Download a version | `GET …/items/:id/download?version_id=<id>`, which returns a signed URL the app then reads |
| Download several files | `POST …/items/download-urls` with `space_id` and `items` |
| References | `GET …/items/:id/references?direction=…` |
| Manage with reviews | `PUT` or `DELETE …/items/:id/controlled-docs` (see [Controlled documents](controlled-documents.md)) |
| Reviews of a document | `GET …/items/:id/reviews`, then `…/reviews/:id` and its sub-routes |
| Access and grants | `GET …/items/:id/access`; grants are written on `…/items/:id/grants` |

Upload is a separate flow: `POST …/uploads`, the signed transfer, then
completion.
