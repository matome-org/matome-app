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

function failure(code, kind) {
    if (code === "")
        return ""
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
