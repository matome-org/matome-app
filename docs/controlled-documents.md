# Controlled documents

The app consumes the controlled-document API merged in matome-core PR #1,
with the add-on settings and approval policy of PR #4.
The product key is `controlled_docs`; its entitlement capability is
`addon.controlled_docs`. Availability requires an entitled, active
installation covering the space. Installation alone does not put every
document under control.

## Configure

1. In Settings, expand the organization and select Add-ons, then open
   Controlled documents. Its page shows what the organization has of it and
   where it runs. Under **Where it runs**, choose all spaces or only some,
   then **Install**, **Resume** or **Save spaces**. **Pause installation** and
   **Uninstall** are on the same page.
2. Under **Organization settings**, set the defaults every space uses. The
   form follows the catalog's `settings_schema`, so a setting Core adds
   appears without an app change:
   - **Require pinned versions** (`require_version_references`): every image
     and linked file of a managed document must pin a version, so an
     approved document shows exactly what was reviewed.
   - **Authors may approve their own proposals** (`allow_author_approval`):
     the author's approval counts toward the required approvals. Only
     another reviewer can reject.
   - **Required approvals** (`required_approvals`, 1 to 10): how many
     different reviewers must approve a proposal before it is published.

   **Save settings** sends only the changed values. Settings chosen before
   installing are sent with **Install**.
3. In Settings, select Spaces and pick the space. **Add review roles** creates
   the reviewer and manager roles when the organization lacks them. An
   organization administrator still needs an explicit grant: **Grant me
   management access** adds it. Management grants
   `space.controlled_docs_manage`, `document.controlled_docs_manage` and
   `document.review_read`. The Controlled documents card summarizes the
   space's settings; **Configure document control** opens the add-on's page
   on that space.
4. Under **Space settings** on the add-on's page, pick the space and activate
   its rule. Each setting follows the organization, or **Set for this space**
   overrides it; choosing the organization again removes the override. Core
   refuses rule changes while any document of the space has an open review.
   Existing incompatible readiness automations and trusted processing
   subscriptions must be paused or configured for publication before Core
   accepts the rule. Removing the rule asks for a reason.
5. Grant reviewer access under Access with **Grant access**, choosing the
   member and the role. The reviewer role grants `document.review_read` and
   `document.approve` for the space. Use normal space membership or resource
   grants to provide their explorer visibility.
6. Open a Markdown document of the space and choose **Manage with reviews**
   on its Preview tab. The explorer shows "Managed" beside it. **Stop
   managing** asks for a reason and cancels open reviews. Core requires a
   published Markdown version, valid UTF-8 without NUL characters, of at most
   1 MiB.

Management and reviewer profiles reuse an existing role with the exact action
set, or create one through Core. Revoking a space grant requires confirmation.
Other grants and controlled-tag restrictions still apply. Organization roles
do not substitute for the dedicated resource grants. Core remains the
authorization authority for every action.

The shipped Core catalog contains a local `controlled-docs-poc` SKU and no paid
packages. An operator must grant that SKU, or deploy a commercial catalog that
includes the entitlement, before installation is available. The app does not
grant commercial allowances.

## Propose and review

A managed document opens in the same document screen as any other file (see
[Documents](documents.md)). Editing it and choosing **Submit for review**
asks for a summary and uploads the text as a candidate. The published version
stays available until approval. Each submission opens its own review, so
several can be open at once and each is decided, or cancelled, on its own.
The upload names the published version the edit started from, so approving
it can never silently undo a change published meanwhile.

The Reviews tab lists the document's reviews, open ones first and then the
closed ones, newest first, with their summary, status, author, date and the
version they were based on. The caption beside the document counts its open
reviews. The list only shows the reviews: select one and choose **Open
review**, or press Enter, double-click, or double-tap it.

Core reports how an open review relates to the published version:

- **Ready to approve** (`clean`): based on the published version. Only such a
  review can be approved.
- **Behind the published version** (`behind`): another review was published
  since, but the changes combine without conflicts. Its author chooses
  **Update review**: the app asks Core to merge the proposal over the
  published version and submits the result as the review's next revision,
  keeping its summary. It can then be approved.
- **Conflicts with the published version** (`dirty`): the proposal and the
  published version change the same lines. Its author chooses **Resolve
  conflicts**; the editor opens the merged text, with each conflict between
  `<<<<<<< published`, `=======` and `>>>>>>> review` lines. Saving is
  refused while a marker remains; once they are all resolved, **Update
  review** submits it as the review's next revision.

Reviewers can reject a review in any state but cannot approve one that is
behind or has conflicts; the page tells them the author must update it
first. The author can also choose **Edit proposal** on a review without
conflicts to rework its text in the editor, then **Update review**.
Discarding the edit returns to the published text without touching the
review. Each update keeps the review, its summary and its history; the
previous candidate becomes replaced.

An opened review takes the screen one level below the document. The header
reads `space › document › Reviews` over the review's summary, and **Back to
reviews** or Escape returns to the list. The page shows who submitted it,
when, the version it changes, and any decision with its comment. Document
renders the candidate, images included; Changes shows the server's unified
diff and the images and linked files it adds, removes, or changes. The
command bar offers **Download candidate** and, while the review is open,
**Cancel review**, **Reject** and **Approve**. The page explains when the
reader cannot decide, for example on their own proposal.

A review keeps the settings in effect when it was submitted. When it needs
more than one approval, the page shows "Approvals: 1 of 2" and who approved
the current candidate. An approval short of the count keeps the review open
and hides **Approve** from that reviewer; the approval that reaches it
publishes that exact candidate. Updating the review replaces its candidate,
so earlier approvals no longer count. The author can never reject, and can
approve only when the review's settings let authors approve. Reject and
cancel keep the published version.

For links, a manager reads the space's effective settings from its rule.
Anyone else pins links when an open review's settings or the organization's
require it; a pinned link is always accepted.

Decisions carry the expected review revision, candidate identifier
and an idempotency key. After a decision the review stays open on screen with
its new status. Conflicts refresh the records and keep the explanation; an
approval refused because the published version moved on shows the review as
behind, ready for its author to update.
Leaving the Reviews tab closes the review.

## Disable, resume and remove

Pause installation temporarily blocks controlled proposals and approvals. It
preserves published reads, rules, reviews and commercial allowances. Resume
restores processing when the entitlement and space coverage permit it.
Changes on another client are read on refresh or when the window regains
focus, and Core rejects operations if availability changes during a request.

Uninstall document control is a separate confirmed action with a reason and
installation revision. It cancels organization reviews and removes document
gates without publishing candidates or cancelling billing. Resuming after
uninstall requires reactivating rules and explicitly opting documents in again.

Removing control from one document also requires a reason and current revision.
It cancels its open reviews. Changing or removing a space rule conflicts with
open reviews in the space; removing it leaves existing document gates blocked. Open reviews also prevent the
document and containing folders from moving, being trashed or being purged.

## Screen review

Start the desktop app with `mise run studio`. Inspect Settings › Add-ons,
Settings › Spaces, and a managed document's Reviews tab and review page at
desktop and narrow window widths. Use distinct author and reviewer accounts
for the publication workflow. Validate pause/resume, missing grants,
cancelled reviews and conflicts before the final `mise run verify` and
platform e2e cycle.
