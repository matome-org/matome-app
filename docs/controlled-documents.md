# Controlled documents

The app needs matome-core with the unified item contract (7e80231 or later)
and the controlled-document add-on's settings and approval policy.
The product key is `controlled_docs`; its entitlement capability is
`addon.controlled_docs`. Core keeps two states apart. **Installed** in the
organization, the add-on is available in every space, including spaces
created later, and active in none. **Active** in a space, it is that
space's review switch: only there do its actions, reviews and deliveries
work. Installation alone does not put any document under control.

## Configure

1. In Settings, expand the organization and select Add-ons, then open
   Controlled documents. Not installed, its command bar offers **Install**,
   which opens a side panel with its settings, the defaults every space
   uses, and **Install**. The form follows the catalog's `settings_schema`,
   so a setting Core adds appears without an app change:
   - **Require pinned versions** (`require_version_references`): every
     image and linked file of a managed document must pin a version, so an
     approved document shows exactly what was reviewed.
   - **Authors may approve their own proposals** (`allow_author_approval`):
     the author's approval counts toward the required approvals. Only
     another reviewer can reject.
   - **Required approvals** (`required_approvals`, 1 to 10): how many
     different reviewers must approve a proposal before it is published.

   **Install** sends `PUT …/add-ons/controlled_docs/installation` with the
   settings alone: there is no space and no responsible member to pick, as
   Core makes the installer the responsible member. Installed, the page
   shows the settings read only; **Settings** changes them in a panel and
   sends only the changed values. **Plan and usage** shows the SKU, its
   version, the purchased and assigned quantities and any allowance.
2. The add-on's page lists the roles it adds, with what each allows, on
   its **Roles** tab; **Open** opens one under Settings › Roles. They
   are the roles Core provisions, also listed under Settings › Roles, and
   given on a space's access like any other role:
   - **Controlled documents reviewer**: `addon.controlled_docs.review_read`.
   - **Controlled documents approver**: `addon.controlled_docs.review_read`
     and `addon.controlled_docs.approve`.
   - **Controlled documents manager**: `addon.controlled_docs.review_read`
     and `addon.controlled_docs.document_manage`.

   Owners and administrators do not receive these actions: a member needs a
   grant. Pausing archives the roles; their grants stop giving access until
   the add-on is resumed, and Core no longer lists them on spaces, folders,
   or documents. Uninstalling archives them the same way and keeps their
   grants for a reinstall.
3. Turn it on per space. Under Settings › Spaces, a space's page lists
   on its **Add-ons** tab every installed add-on that works per space,
   active or inactive there; the add-on's page lists the same on its
   **Spaces** tab. **Activate** (or **Settings**), either tab's command,
   opens the same side panel: **Active in this space** activates
   the add-on in the space (`PUT …/spaces/:id/add-ons/controlled_docs`) or
   deactivates it (`DELETE` on the same path, keeping the space's settings),
   each with the activation's revision once it has one; active, **Space
   settings** holds the space's own values of the add-on settings, each
   following the organization until **Set for this space** overrides it.
   **Save** sends the change. Reading and changing it needs
   `add_on.space_activate` in the space (Add-on manager, Space operator,
   Space administrator, and organization owners and administrators);
   otherwise the panel shows Core's refusal. While the add-on is paused,
   the row and the panel say so. Core refuses while any document of the
   space has an open review (`review_open`), and refuses activation while
   incompatible readiness automations or trusted processing subscriptions
   remain.
4. Give access on the same page: **Grant access**, pick the member or
   group, then check **Controlled documents manager** for who manages
   documents, **Controlled documents approver**, or **Controlled documents
   reviewer** for someone who only reads reviews. Check **Content reader**
   or **Content contributor** beside it so they also see the space's
   content.
5. Open a Markdown document and choose **Manage with reviews** in its
   command bar, or from the document's menu in the explorer, which opens the
   document first. It asks Core at once
   (`PUT …/items/:id/controlled-docs` with the document's revision).
   The command shows its state in the bar before that: usable when the
   space's action catalog grants `addon.controlled_docs.document_manage`;
   otherwise unusable, saying what is missing, as
   [Refusals](organization-administration.md#refusals) works it out: the
   role (**You need Controlled documents manager in this space.**), the
   add-on off in the space, paused or not installed in the organization, or
   not in the plan. Beside it, for whoever may fix it from Settings,
   **Grant access** opens the space's Grant access panel with Controlled
   documents manager ticked, **Activate** the add-on's activation panel in
   the space, **Resume** or **Install** the add-on's page, and **Open plan**
   Plan and billing; back on the document, it is usable. A managed
   document's **Manage with reviews** says it is managed already, and
   **Stop managing** says when it is not. A refusal Core still gives is
   said the same way, Core's own text last. The explorer shows "Managed"
   beside a managed document. **Stop managing**, in the document's bar or the
   explorer menu, asks for a reason and cancels open reviews.
   Core requires a published Markdown version, valid UTF-8 without NUL
   characters, of at most 1 MiB.
6. Or manage Markdown files as they are uploaded. Core grants
   `addon.controlled_docs.document_manage` in a space only where the add-on
   is active there, so when the space's action catalog grants it, dropping
   `.md` files on the explorer, **Upload file** (U), or the picker on the
   web asks **Manage N Markdown files with reviews?** in a side panel,
   every time. Managing is opt-in: **Manage with reviews** starts off, and
   the files upload unmanaged unless the user turns it on. Turned on, each file is managed
   once it lands, as the document's own **Manage with reviews** does (the
   app reads the document's revision back, then sends
   `PUT …/items/:id/controlled-docs` with it). Cancel or Escape drops
   them. Other files upload at once. A file that landed but that Core
   refused to manage is named in the status line with Core's reason, the
   way a failed upload is.

**Manage with reviews** shows on every Markdown document where Core's
catalog lists the add-on's managing action, and on a managed document. A removal's reason (document, installation)
travels in the DELETE body; Core refuses undeclared query parameters.

Revoking a space grant requires confirmation.
Other grants and controlled-tag restrictions still apply. Organization roles
do not substitute for the dedicated resource grants. Core remains the
authorization authority for every action.

The shipped Core catalog contains a local `controlled-docs-poc` SKU and no paid
packages. An operator must grant that SKU, or deploy a commercial catalog that
includes the entitlement, before installation is available. The app does not
grant commercial allowances.

## Propose and review

The screens use one term: a **review** holds a **proposal**. "Candidate"
is Core's name for the proposal's version (`candidate_version_id`) and
stays out of the screens; "publish" only names what an approval does. The
document page has one **Edit** command, which opens the editor.

A managed document opens in the same document screen as any other file (see
[Documents](documents.md)). Editing it and choosing **Propose change** (its
**Save**) asks in a side panel for a comment and uploads the text as the
review's proposal; the comment is the review's summary. The
published version stays available until approval. Each submission opens its own review, so
several can be open at once and each is decided, or cancelled, on its own.
The upload names the published version the edit started from, so approving
it can never silently undo a change published meanwhile.

The Reviews tab lists the document's reviews in one table, open ones first
and then the closed ones, newest first: Review (its summary), Author, State,
and, for an open one, Approvals ("0/1"). Select one and choose **Open**, or
press Enter, double-click, or double-tap it. While a review is open, the
document shows **Review open** beside its name and a line under the top
("Review open · 0/1 approvals"); **Open review** in its bar opens the first
open review from any tab.

Core reports how an open review relates to the published version:

- **Ready to approve** (`clean`): based on the published version. Only such a
  review can be approved.
- **Behind the published version** (`behind`): another review was approved
  since, but the changes combine without conflicts. Its author chooses
  **Update review**: the app asks Core to merge the proposal over the
  published version (`GET …/reviews/:id/merge`) and submits the result as
  the review's next revision,
  keeping its summary. It can then be approved.
- **Conflicts with the published version** (`dirty`): the proposal and the
  published version change the same lines. Its author chooses **Resolve
  conflicts**; the editor opens the merged text, with each conflict between
  `<<<<<<< published`, `=======` and `>>>>>>> review` lines. Saving is
  refused while a marker remains; once they are all resolved, **Update
  review** submits it as the review's next revision.

Reviewers can reject a review in any state but cannot approve one that is
behind or has conflicts; **Approve** says the author must update it first.
The author can also choose **Edit proposal** on a review without conflicts
to rework its text in the editor, then **Update review**.
Discarding the edit returns to the published text without touching the
review. Each update keeps the review, its summary and its history; the
previous proposal is replaced.

### Review page

An opened review takes the screen one level below the document
(`src/gui/qml/controlled_docs/ReviewPage.qml`). The top holds the way back, named after
the document (Escape), the review's summary, and its state as chips: Open,
Approved, Rejected, or Cancelled and, while open, **Current**, **Behind**,
or **Conflicts** and its approvals ("0/1 approvals"). Under it: who
submitted it, when, and the version it changes; once it is decided, who
decided it, when, and the decision comment; and what an open review that is
behind or conflicts asks of its author.

One command bar holds **Approve**, **Reject**, **Update review**, **Resolve
conflicts**, **Edit proposal**, **Cancel review**, and **Download
proposal**. Every one shows whether it applies or not; one that does not is
unusable and says why: the review is closed, only another reviewer approves
or rejects it, it was approved already, its author must update it first,
only its author updates it, it has no conflicts, it is based on the
published version, or review permission is missing. **Approve**,
**Reject**, and **Cancel review** ask in a side panel, with a comment Core
recorded as the decision comment (optional for Approve and Reject, required
to cancel).

The tabs are:

- **Changes** (the default): the review's base version against its
  proposal; see [Changes](#changes).
- **Document**: the proposal rendered, images included.
- **References**: one table, Reference and Change (Added, Removed,
  Changed), of the links and images the proposal adds, removes, or repins.
  A reference is named by the text that links it, else its path, else its
  document. **Open**, Enter, or a double click opens it.

### Changes

The Changes tab (`src/gui/qml/documents/ChangesTab.qml`) compares two Markdown texts.
Its summary counts the lines added and removed and the sections (headings)
the changes touch: "+12 −4 · 3 sections". Its bar holds **Previous change**
(P), **Next change** (N), and the **Rendered** / **Source** switch, the view
shown filled and outlined; Left and Right move between the two once it
has the keyboard. Next and Previous glide to each change in turn, frame
it, and put the keyboard on the view.

- **Rendered** shows the later document block by block with the same
  blocks as the preview. A block added sits on a green wash with a green
  bar; a removed one on a red wash, struck through, with a red bar; a
  changed one keeps a bar and marks the words removed (red, struck) and
  added (green) inside it, a table row by row and code word by word.
  Unchanged runs fold into "⋯ 8 unchanged blocks", which a click or Enter
  opens; one block of context stays on each side of a change.
- **Source** shows both texts side by side, base on the left, proposal on
  the right, each line with its number and aligned with its counterpart.
  Removed lines sit on a red wash, added ones on a green wash, and a
  changed line marks the words that changed; a side without the line stays
  blank. Unchanged runs fold, three lines of context kept, and a click or
  Enter opens them. Both sides are one row each, so they scroll together.

Both views build only the rows in sight and scroll like the preview.

The comparison runs in the app (`MarkdownDiff` in
`src/gui/documents/MarkdownDiff.h`). Each text is parsed into blocks
(`parseMarkdown`); the blocks are aligned with Myers' shortest edit script
on their kind and content, and within each run of removals and additions a
removed block is paired with an added one of the same kind that keeps
enough of its words (a quarter when the run is one-for-one, else half), a
table that keeps its columns, or an image. Paired blocks are compared word
by word; ideographs count as a word each. The source view aligns lines the
same way.

The texts come from routes Core exposes: the proposal from
`GET …/reviews/:id/candidate/download`, the base version from
`GET …/items/:id/download?version_id=<base_version_id>`, both through their
signed links. `GET …/reviews/:id/diff` supplies the
reference changes for References; its unified diff is not used.

A review keeps the settings in effect when it was submitted. An approval
short of the count keeps the review open, and **Approve** then says that
reviewer approved it already; the approval that reaches it publishes that
exact proposal. Updating the review replaces its proposal,
so earlier approvals no longer count. The author can never reject, and can
approve only when the review's settings let authors approve. Reject and
cancel keep the published version.

For links, whoever may turn the add-on on in the space reads its effective
settings from the activation (`GET …/spaces/:id/add-ons`). Anyone else pins
links when an open review's settings or the organization's require it; a
pinned link is always accepted.

A decision is `POST …/reviews/:id/approve`, `…/reject`, or `…/cancel`. Its
body carries the proposal's `candidate_version_id` and the `comment`; its
`If-Match` header carries the review's revision, with an `Idempotency-Key`.
The review itself holds the outcome: `status`,
`closed_at`, `deciding_membership_id`, and `decision_comment`, and the
approvals are its `approvals` list. After a decision the review stays open
on screen with its new status. Conflicts refresh the records and keep the
explanation; an approval refused because the published version moved on
shows the review as behind, ready for its author to update. Once a decision publishes a
version, the document shows it. Leaving the Reviews tab closes the review.

## Pause, resume and uninstall

**Pause** and **Uninstall** first count, from the grants on every space of
the organization, how many people and groups hold one of its roles, in how
many spaces, and how many hold each role. Their side panel states that,
with the spaces where it is active, before it can be confirmed. Pause temporarily blocks controlled proposals and
approvals everywhere: open reviews wait until it resumes, and published
reads, space activations and their settings, reviews and commercial
allowances remain. **Resume** sends the saved settings back unchanged; the
spaces that had turned it on have it active again. Changes on another
client are read on refresh or when the window regains focus, and Core
rejects operations if availability changes during a request.

Uninstall asks for a reason and sends the installation revision. It cancels every open review and removes document gates
without publishing proposals or cancelling billing; Core keeps the space
activations with their settings, and after reinstalling each document must
be managed again. Core then marks the installation `uninstalled`: the
add-on's page and row, a space's **Add-ons**, and a document's controls
treat it as not installed, and the add-on's page offers
**Install** again.
Pausing an uninstalled add-on leaves it uninstalled. The grants of the
add-on's roles stay and give their access back once it is installed again.

Removing control from one document also requires a reason and current revision.
It cancels its open reviews. Turning the add-on on or off in a space
conflicts with open reviews in the space; turning it off leaves existing
document gates blocked. Open reviews also prevent the document and
containing folders from moving, being trashed or being purged.

## Screen review

Start the desktop app with `mise run studio`. Inspect the install steps
under Settings › Add-ons, the activation panel from a space's page under
Settings › Spaces, the upload question in a space that requires reviews,
and a managed document's Reviews tab and review page at
desktop and narrow window widths. Use distinct author and reviewer accounts
for the publication workflow. Validate pause/resume, missing grants,
cancelled reviews and conflicts before the final `mise run verify` and
platform e2e cycle.
