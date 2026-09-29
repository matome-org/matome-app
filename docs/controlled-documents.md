# Controlled documents

The app consumes the controlled-document API merged in matome-core PR #1.
The product key is `controlled_docs`; its entitlement capability is
`addon.controlled_docs`. Availability requires an entitled, active
installation covering the space. Installation alone does not put every
document under control.

## Configure

1. In Settings, expand the organization and select Add-ons. Install or resume
   Controlled documents and select its spaces. No selection covers all spaces.
2. Open a space and choose Document reviews in the toolbar or command sheet.
   On a phone, the floating menu includes the command.
3. In Control, use Review access for this space to grant management access
   explicitly, including to an organization administrator who needs it.
   The profile grants `space.controlled_docs_manage`,
   `document.controlled_docs_manage` and `document.review_read`.
4. Activate the space rule. Existing incompatible readiness automations and
   trusted processing subscriptions must be paused or configured for publication
   before Core accepts the rule.
5. Upload a `.md` document. The app labels it `text/markdown`. The explorer
   shows "Not managed" beside it. Choose "Manage document" in that document's
   menu, then use the Control tab to opt it in. The row changes to "Managed".
   "Unmanage document" in the same menu opens the Control tab to request a
   reason and confirm opt-out. Core requires a published
   Markdown version, valid UTF-8 without NUL characters, of at most 1 MiB.
6. Grant reviewer access to another member of the organization. This profile
   grants `document.review_read` and `document.approve` for the space. Use normal
   space membership or resource grants to provide their explorer visibility.

Management and reviewer profiles reuse an existing role with the exact action
set, or create one through Core. Space grant revocation requires confirmation.
Other grants and controlled-tag restrictions still apply. Organization roles
do not substitute for the dedicated resource grants, and authors cannot approve
their own proposals. Core remains the authorization authority for every action.

The shipped Core catalog contains a local `controlled-docs-poc` SKU and no paid
packages. An operator must grant that SKU, or deploy a commercial catalog that
includes the entitlement, before installation is available. The app does not
grant commercial allowances.

## Propose and review

Controlled documents carry a Controlled label in the explorer. Opening one
shows its review screen. For ordinary documents, select the document and choose
Document reviews to configure its control.

Propose changes loads the published Markdown into the editor after checking its
checksum. Enter a reason and submit the proposal. The upload targets the
existing document and keeps its published version available. Unsent text stays
in the editor through errors and refreshes; leaving the screen asks before
discarding changes. Drafts are held in memory, not persisted across sign-out
or application shutdown.
A refresh that finds a different published base blocks submission of a loaded
draft. Copy the edits before confirming a reload of the published Markdown.

Reviews shows the paginated authorized history, reason, outcome and decision
comment. Select a review to fetch the server's unified diff or download its
exact candidate. Approve publishes that candidate; reject and cancel retain
the published base. Decisions carry the expected review revision, candidate
identifier and an idempotency key. Conflicts refresh the records and preserve
the explanation. Large diffs use a separate bounded JSON response allowance;
other API responses retain their ordinary limit.

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

Start the desktop app with `mise run studio`. Inspect Add-ons and the Reviews,
Propose changes and Control tabs at desktop and narrow window widths. Use
distinct author and reviewer accounts for the publication workflow. Validate
pause/resume, missing grants, cancelled reviews and conflicts before the final
`mise run verify` and platform e2e cycle.
