# Controlled documents

The app consumes the controlled-document API merged in matome-core PR #1.
The product key is `controlled_docs`; its entitlement capability is
`addon.controlled_docs`. Availability requires an entitled, active
installation covering the space. Installation alone does not put every
document under control.

## Configure

1. In Settings, expand the organization and select Add-ons. Select Controlled
   documents, then install or resume it from the command bar and choose its
   spaces. No selection covers all spaces.
2. In Settings, select Spaces and pick the space. **Add review roles** creates
   the reviewer and manager roles when the organization lacks them. An
   organization administrator still needs an explicit grant: **Grant me
   management access** adds it. Management grants
   `space.controlled_docs_manage`, `document.controlled_docs_manage` and
   `document.review_read`.
3. In the Controlled documents card, activate the space rule. **Require pinned
   versions** makes every image and linked file of a managed document pin a
   version, so an approved document shows exactly what was reviewed. Existing
   incompatible readiness automations and trusted processing subscriptions
   must be paused or configured for publication before Core accepts the rule.
4. Grant reviewer access under Access with **Grant access**, choosing the
   member and the role. The reviewer role grants `document.review_read` and
   `document.approve` for the space. Use normal space membership or resource
   grants to provide their explorer visibility.
5. Open a Markdown document of the space and choose **Manage with reviews**
   on its Preview tab. The explorer shows "Managed" beside it. **Stop
   managing** asks for a reason and cancels open reviews. Core requires a
   published Markdown version, valid UTF-8 without NUL characters, of at most
   1 MiB.

Management and reviewer profiles reuse an existing role with the exact action
set, or create one through Core. Revoking a space grant requires confirmation.
Other grants and controlled-tag restrictions still apply. Organization roles
do not substitute for the dedicated resource grants, and authors cannot approve
their own proposals. Core remains the authorization authority for every action.

The shipped Core catalog contains a local `controlled-docs-poc` SKU and no paid
packages. An operator must grant that SKU, or deploy a commercial catalog that
includes the entitlement, before installation is available. The app does not
grant commercial allowances.

## Propose and review

A managed document opens in the same document screen as any other file (see
[Documents](documents.md)). Editing it and choosing **Submit for review**
asks for a summary and uploads the text as a candidate. The published version
stays available until approval, and a second proposal waits until the open
review is decided or cancelled.

The Reviews tab lists the document's reviews, newest first, with their
summary, status, author and date. It only lists them: select one and choose
**Open review**, or press Enter, double-click, or double-tap it.

An opened review takes the screen one level below the document. The header
reads `space › document › Reviews` over the review's summary, and **Back to
reviews** or Escape returns to the list. The page shows who submitted it,
when, the version it changes, and any decision with its comment. Document
renders the candidate, images included; Changes shows the server's unified
diff and the images and linked files it adds, removes, or changes. The
command bar offers **Download candidate** and, while the review is open,
**Cancel review**, **Reject** and **Approve**. The page explains when the
reader cannot decide, for example on their own proposal.

Approve publishes that exact candidate; reject and cancel keep the published
version. Decisions carry the expected review revision, candidate identifier
and an idempotency key. After a decision the review stays open on screen with
its new status. Conflicts refresh the records and keep the explanation.
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
It cancels its open reviews. Removing a space rule conflicts with open reviews
and leaves existing document gates blocked. Open reviews also prevent the
document and containing folders from moving, being trashed or being purged.

## Screen review

Start the desktop app with `mise run studio`. Inspect Settings › Add-ons,
Settings › Spaces, and a managed document's Reviews tab and review page at
desktop and narrow window widths. Use distinct author and reviewer accounts
for the publication workflow. Validate pause/resume, missing grants,
cancelled reviews and conflicts before the final `mise run verify` and
platform e2e cycle.
