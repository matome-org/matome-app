.pragma library

// The one place Core error codes and empty lists become words. `kind` is
// "auth" on the sign-in form, else what the list holds: org, space, folder.
// An empty list says what is missing, then what to do, on a line each.

function lines(first, second) {
    return first + "\n" + second
}

function perKind(kind) {
    switch (kind) {
    case "auth":
        return { name: qsTr("Fill every required field."), failed: qsTr("That request failed."),
                 unauthenticated: qsTr("That email or password is wrong."), empty: "" }
    case "org":
        return { name: qsTr("Name the organization."), failed: qsTr("Could not load organizations."),
                 unauthenticated: qsTr("Sign in again."),
                 empty: lines(qsTr("No organizations yet."),
                               qsTr("Create one to continue.", "an organization")) }
    case "space":
        return { name: qsTr("Name the space."), failed: qsTr("Could not load spaces."),
                 unauthenticated: qsTr("Sign in again."),
                 empty: lines(qsTr("No spaces yet."), qsTr("Create one to continue.", "a space")) }
    default:
        return { name: qsTr("Name the folder."), failed: qsTr("Could not load files."),
                 unauthenticated: qsTr("Sign in again."),
                 empty: lines(qsTr("This folder is empty."), qsTr("Create a folder or drop files here.")) }
    }
}

function failure(code, kind, details) {
    if (code === "")
        return ""
    if (code === "reference_in_use") {
        const titles = (details?.sources ?? []).map(function (source) { return "“" + source.title + "”" }).join(", ")
        const hidden = details?.hidden_count ?? 0
        const users = titles === "" ? qsTr("%n document(s) you cannot see", "", hidden)
                    : hidden > 0 ? qsTr("%1 and %n more", "", hidden).arg(titles) : titles
        return qsTr("This file is shown by %1. Remove it from those documents before deleting or moving it to another space.").arg(users)
    }
    if (code === "network")
        return qsTr("Could not reach Core at that URL.")
    if (code === "server")
        return qsTr("Core could not complete that request.")
    if (code === "folder_cycle")
        return qsTr("A folder cannot move into itself.")
    if (code === "invalid_name")
        return qsTr("Names cannot be “.” or “..”, or contain slashes, backslashes or control characters.")
    if (code === "name_conflict")
        return qsTr("Something here already has that name.")
    if (code === "non_empty_resource")
        return qsTr("Only an empty folder can be deleted.")
    if (code === "revision_conflict")
        return qsTr("That changed on Core first. The list is current now; try again.")
    if (code === "session_expired")
        return qsTr("Your session ended. Sign in again.")
    if (code === "email_not_confirmed")
        return qsTr("Confirm your email before continuing.")
    if (code === "rate_limited")
        return qsTr("Too many attempts. Wait a moment and try again.")
    const words = perKind(kind)
    if (code === "unauthenticated")
        return words.unauthenticated
    if (code === "invalid_request")
        return words.name
    return words.failed
}

// What to fix in the auth fields Core refused, a line each; empty when it
// named none of them.
function rejected(fields) {
    const said = []
    if (fields.includes("email"))
        said.push(qsTr("Use a valid email address with no account yet."))
    if (fields.includes("password"))
        said.push(qsTr("Use a password of 8 to 72 characters."))
    return said.join("\n")
}

function empty(kind, filter) {
    return filter === "" ? perKind(kind).empty : qsTr("Nothing here matches “%1”.").arg(filter)
}

// Why one uploaded file did not land, by name.
function uploadFailure(code, name) {
    if (code === "")
        return ""
    if (code === "unreadable")
        return qsTr("Could not read “%1”.").arg(name)
    if (code === "network")
        return qsTr("Could not upload “%1”: Core or storage could not be reached.").arg(name)
    if (code === "server")
        return qsTr("Could not upload “%1”: Core could not complete that request.").arg(name)
    if (code === "invalid_name")
        return qsTr("Could not upload “%1”: names cannot be “.” or “..”, or contain slashes, backslashes or control characters.").arg(name)
    if (code === "name_conflict")
        return qsTr("Could not upload “%1”: something here already has that name.").arg(name)
    return qsTr("Could not upload “%1”: Core refused it.").arg(name)
}


function adminFailure(code) {
    switch (code) {
    case "": return ""
    case "forbidden":
    case "organization_access_denied": return qsTr("You do not have permission for this action.")
    case "invalid_email": return qsTr("Enter a valid email address.")
    case "invalid_request": return qsTr("Check the required fields.")
    case "last_owner": return qsTr("The organization must keep at least one owner.")
    case "last_membership": return qsTr("Your account must keep at least one organization membership.")
    case "already_member": return qsTr("This person already belongs to the organization.")
    case "already_invited": return qsTr("There is already a pending invitation for this email.")
    case "invitation_delivery_failed": return qsTr("The invitation email could not be sent. Try again.")
    case "expired": return qsTr("This invitation has expired. Send a new invitation.")
    case "limit_exceeded": return qsTr("The organization has reached its plan limit.")
    case "capability_missing": return qsTr("This feature is not available on the current plan.")
    case "revision_conflict": return qsTr("The organization changed. Review the updated details and try again.")
    case "network":
    case "server":
    case "session_expired":
    case "unauthenticated":
    case "rate_limited": return failure(code, "org")
    default: return qsTr("Could not complete the organization request.")
    }
}

function adminNotice(value) {
    switch (value) {
    case "renamed": return qsTr("Organization updated.")
    case "invited": return qsTr("Invitation sent by email.")
    case "role_changed": return qsTr("Member role updated.")
    case "removed": return qsTr("Member removed.")
    case "canceled": return qsTr("Invitation canceled.")
    default: return ""
    }
}

function invitationState(value) {
    switch (value) {
    case "pending": return qsTr("Pending")
    case "accepted": return qsTr("Accepted")
    case "canceled": return qsTr("Canceled")
    case "expired": return qsTr("Expired")
    default: return ""
    }
}

function usageName(value) {
    switch (value) {
    case "storage_bytes": return qsTr("Storage")
    case "members": return qsTr("Members")
    case "guests": return qsTr("Guests")
    case "spaces": return qsTr("Spaces")
    default: return value
    }
}

function usageAmount(value, dimension) {
    if (value === null || value === undefined)
        return qsTr("Unlimited")
    if (dimension !== "storage_bytes")
        return Number(value).toLocaleString(Qt.locale(), 'f', 0)
    const units = [qsTr("B"), qsTr("KiB"), qsTr("MiB"), qsTr("GiB"), qsTr("TiB")]
    const index = value > 0 ? Math.min(units.length - 1, Math.floor(Math.log(value) / Math.log(1024))) : 0
    return Number(value / Math.pow(1024, index)).toLocaleString(Qt.locale(), 'f', index === 0 ? 0 : 1)
           + " " + units[index]
}

function subscriptionStatus(value) {
    switch (value) {
    case "active": return qsTr("Active subscription")
    case "trialing": return qsTr("Trial subscription")
    case "past_due": return qsTr("Payment overdue")
    case "unpaid": return qsTr("Payment required")
    case "incomplete": return qsTr("Payment incomplete")
    case "incomplete_expired": return qsTr("Payment expired")
    case "canceled": return qsTr("Subscription canceled")
    case "paused": return qsTr("Subscription paused")
    default: return qsTr("Unknown subscription status")
    }
}

function billingFailure(code) {
    switch (code) {
    case "checkout_expired": return qsTr("This checkout session has expired. Select the package again to continue.")
    case "billing_disabled": return qsTr("Billing is disabled on this server. Your current plan and allowances remain available.")
    case "no_customer": return qsTr("This organization has no billing account yet.")
    case "no_subscription": return qsTr("This organization has no active paid subscription.")
    case "invalid_return_url": return qsTr("The server does not allow this app address as a billing return destination.")
    case "unknown_package": return qsTr("This package is no longer available. Refresh and choose another package.")
    case "package_unavailable": return qsTr("One of this package’s components is unavailable. Choose another package.")
    case "subscription_exists": return qsTr("The organization already has a subscription. Refresh before changing its package.")
    case "unknown_plan": return qsTr("This plan is not available for purchase.")
    case "unknown_add_on": return qsTr("This add-on is not available for purchase.")
    case "invalid_quantity": return qsTr("Enter a valid quantity for this add-on.")
    case "invalid_space": return qsTr("One of the selected spaces is no longer available. Refresh and try again.")
    case "invalid_settings": return qsTr("The server refused these add-on settings.")
    case "billing_provider_error": return qsTr("The payment provider is unavailable. Try again later.")
    default: return adminFailure(code)
    }
}

function controlledFailure(code) {
    switch (code) {
    case "forbidden": return qsTr("You do not have permission for this document, review, or space operation.")
    case "not_found": return qsTr("This document, review, or rule is no longer available to you. Refresh the current space.")
    case "controlled_docs_unavailable": return qsTr("Document control is unavailable. Refresh after the administrator resumes the add-on or restores access.")
    case "review_closed": return qsTr("This review was already decided. Refresh to see the result.")
    case "stale_base": return qsTr("This review is not based on the published version. Its author must update it before it can be approved.")
    case "merge_too_large": return qsTr("This review is too large to merge here. Download the candidate, apply your changes to the published version, and submit it again.")
    case "stale_rule": return qsTr("The space rule changed. Refresh before deciding again.")
    case "already_approved": return qsTr("You already approved this version. Another reviewer must approve it too.")
    case "invalid_settings": return qsTr("The server refused these settings. Check the allowed values and try again.")
    case "revision_conflict": return qsTr("The document, rule, or review changed. Refresh and inspect the current state before trying again.")
    case "revision_required": return qsTr("Refresh to obtain the current revision before saving.")
    case "published_version_required": return qsTr("Upload and publish a Markdown version before enabling document control.")
    case "diff_too_large": return qsTr("This diff exceeds the server limit. Download the candidate to inspect it.")
    case "candidate_unavailable": return qsTr("The candidate is unavailable. Refresh this review.")
    case "invalid_comment": return qsTr("Use a decision comment of at most 2,000 characters without NUL characters.")
    case "incompatible_publication_subscriptions": return qsTr("Pause incompatible readiness automations or processing subscriptions before enabling control.")
    default: return documentFailure(code)
    }
}

// A space rule's failure: Core refuses rule changes while any document of
// the space has an open review.
function ruleFailure(code) {
    switch (code) {
    case "review_open": return qsTr("This space has open reviews. Decide or cancel them before changing its rule or settings.")
    default: return controlledFailure(code)
    }
}

// An add-on setting's name and what it does, by its `settings_schema` key;
// a key this app does not know reads as itself.
function settingName(key) {
    switch (key) {
    case "require_version_references": return qsTr("Require pinned versions")
    case "allow_author_approval": return qsTr("Authors may approve their own proposals")
    case "required_approvals": return qsTr("Required approvals")
    default: {
        const words = String(key).replace(/_/g, " ")
        return words.charAt(0).toUpperCase() + words.slice(1)
    }
    }
}

function settingDetail(key) {
    switch (key) {
    case "require_version_references": return qsTr("Images and linked files must pin a version, so an approved document shows exactly what was reviewed.")
    case "allow_author_approval": return qsTr("The author’s approval counts toward the required approvals. Only another reviewer can reject.")
    case "required_approvals": return qsTr("How many different reviewers must approve a proposal before it is published.")
    default: return ""
    }
}

function documentFailure(code) {
    switch (code) {
    case "invalid_markdown":
    case "invalid_encoding": return qsTr("This file is not valid UTF-8 text, so it cannot be shown or edited here.")
    case "unsupported_media_type":
    case "invalid_media_type":
    case "media_too_large": return qsTr("A managed document must stay valid UTF-8 Markdown of at most 1 MiB.")
    case "review_open": return qsTr("This document has open reviews. Decide or cancel them before moving, deleting, or changing its rule.")
    case "review_closed": return qsTr("This review was decided or cancelled while you edited it. Discard and submit your text as a new proposal.")
    case "invalid_base_version": return qsTr("The version you edited is no longer published. Refresh and edit the current version.")
    case "reason_required":
    case "invalid_reason": return qsTr("Enter a reason of up to 500 characters.")
    case "invalid_references": return qsTr("The selected image link is malformed. Remove it or insert the image again.")
    case "invalid_reference_path": return qsTr("The selected path link names no valid place in this space. Fix or remove it.")
    case "reference_not_found": return qsTr("The selected image was removed or its version is no longer published. Insert it again.")
    case "reference_forbidden": return qsTr("You cannot read the selected image. Insert one you have access to.")
    case "reference_cross_space": return qsTr("The selected image belongs to another space. Insert a copy in this one.")
    case "reference_self": return qsTr("A document cannot link to itself.")
    case "too_many_references": return qsTr("A document can link at most 200 images and files.")
    case "reference_mode_not_allowed": return qsTr("This space requires links that pin a version. Insert the selected image again.")
    default: return adminFailure(code)
    }
}

function documentNotice(code) {
    switch (code) {
    case "version_published": return qsTr("New version saved.")
    case "review_requested": return qsTr("Changes submitted for review. The published version stays available until approval.")
    case "review_updated": return qsTr("Review updated. Reviewers now see your new proposal.")
    default: return controlledNotice(code)
    }
}

// A linked file that no longer opens, by Core's reference `state`.
function referenceState(state) {
    switch (state) {
    case "broken": return qsTr("Nothing is at this path any more")
    case "trashed": return qsTr("In the trash")
    case "purged": return qsTr("Deleted")
    case "forbidden": return qsTr("You cannot open this file")
    default: return ""
    }
}

function assetFailure(code) {
    switch (code) {
    case "unsupported_image": return qsTr("Only PNG, JPEG, GIF, and WebP images can be inserted.")
    case "unreadable": return qsTr("The image could not be read from this device.")
    case "assets_unavailable": return qsTr("The space's assets folder could not be created. Another file may already be named assets.")
    case "forbidden": return qsTr("You cannot add files to this space.")
    case "name_conflict": return qsTr("The assets folder already holds a file with this name. Rename the image and try again.")
    default: return adminFailure(code)
    }
}

function controlledNotice(code) {
    switch (code) {
    case "rule_saved": return qsTr("Space rule saved.")
    case "rule_removed": return qsTr("Space rule removed. Existing document gates remain.")
    case "control_enabled": return qsTr("Document control enabled.")
    case "control_removed": return qsTr("Document control removed. Open reviews were cancelled.")
    case "review_approve": return qsTr("Proposal approved and published.")
    case "review_approval_added": return qsTr("Approval recorded. The proposal is published once enough reviewers approve it.")
    case "review_reject": return qsTr("Proposal rejected. The published version remains available.")
    case "review_cancel": return qsTr("Review cancelled. The published version remains available.")
    case "access_saved": return qsTr("Space access granted.")
    case "access_removed": return qsTr("Space access grant revoked.")
    case "roles_added": return qsTr("Review roles added. Grant them under Access.")
    default: return ""
    }
}

function reviewStatus(value) {
    switch (value) {
    case "open": return qsTr("Open")
    case "approved": return qsTr("Approved")
    case "rejected": return qsTr("Rejected")
    case "cancelled": return qsTr("Cancelled")
    default: return value
    }
}

// How an open review stands against the published version, by Core's
// `merge_state`; a review recorded before merge states is `clean`.
function mergeState(value) {
    switch (value) {
    case "behind": return qsTr("Behind the published version")
    case "dirty": return qsTr("Conflicts with the published version")
    default: return qsTr("Ready to approve")
    }
}

// What an open review's `merge_state` asks of its author or its reviewers.
function mergeAdvice(value, author) {
    switch (value) {
    case "behind": return author
            ? qsTr("Another review was published after yours. Your changes merge without conflicts: choose Update review to base it on the published version.")
            : qsTr("Another review was published after this one. Its author must update it before it can be approved; it can still be rejected.")
    case "dirty": return author
            ? qsTr("Another review changed the same lines after yours. Choose Resolve conflicts to settle them in the editor.")
            : qsTr("This review conflicts with the published version. Its author must resolve the conflicts before it can be approved; it can still be rejected.")
    default: return ""
    }
}
