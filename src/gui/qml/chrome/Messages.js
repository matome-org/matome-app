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
                 unauthenticated: qsTr("That email, username, or password is wrong."), empty: "" }
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
    if (code === "invalid_setup_code")
        return qsTr("That username or setup code is wrong, or the code was used or expired.")
    if (code === "managed_account")
        return qsTr("An account an organization manages cannot do this.")
    if (code === "rate_limited")
        return qsTr("Too many attempts. Wait a moment and try again.")
    if (code === "forbidden")
        return qsTr("You no longer have access here. Ask someone who manages it.")
    if (code === "not_found")
        return qsTr("This is no longer available to you. Go back and refresh.")
    const words = perKind(kind)
    if (code === "unauthenticated")
        return words.unauthenticated
    if (code === "invalid_request")
        return words.name
    return words.failed
}

// Why Core refused to create a space.
function spaceFailure(code) {
    if (code === "limit_exceeded")
        return qsTr("This organization has reached its plan’s space limit.")
    const said = failure(code, "space")
    return said === perKind("space").failed ? qsTr("Could not create the space.") : said
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

// Why one uploaded file did not land, by name, or, when it `landed`, why
// it is not managed with reviews.
function uploadFailure(code, name, landed) {
    if (code === "")
        return ""
    if (landed)
        return qsTr("Uploaded “%1”, but it is not managed with reviews: %2").arg(name).arg(controlledFailure(code))
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
    case "unknown_parameter": return qsTr("Core refused a request this version of the app sends. Update the app and try again.")
    case "not_found": return qsTr("That is no longer available. Refresh and try again.")
    case "network":
    case "server":
    case "session_expired":
    case "unauthenticated":
    case "rate_limited": return failure(code, "org")
    default: return qsTr("Core refused that request (%1).").arg(code)
    }
}

// Why Core refused an invitation, including the access it offers.
function inviteFailure(code) {
    switch (code) {
    case "not_found": return qsTr("A chosen space or role is no longer available. Refresh and choose again.")
    case "forbidden": return qsTr("You cannot invite people, or cannot give access to one of the chosen spaces.")
    case "limit_exceeded": return qsTr("A chosen space has no room for more access under the plan.")
    case "invalid_request": return qsTr("Check the email and the access chosen for each space.")
    default: return adminFailure(code)
    }
}

// Why Core refused to create a user or to give one a setup code.
function memberFailure(code) {
    switch (code) {
    case "invalid_username": return qsTr("Use 2 to 64 lowercase letters, digits, dots, hyphens, or underscores.")
    case "username_taken": return qsTr("That username is taken in this organization.")
    case "not_managed": return qsTr("This account signs in with its email; it has no setup code.")
    case "invalid_role": return qsTr("Choose at least one role.")
    case "invalid_request": return qsTr("Check the username, name, and password.")
    case "quota_exceeded": return accessFailure(code)
    case "capability_missing": return accessFailure(code)
    default: return adminFailure(code)
    }
}

function adminNotice(value) {
    switch (value) {
    case "member_created": return qsTr("User created.")
    case "setup_code_issued": return qsTr("Setup code issued.")
    case "renamed": return qsTr("Organization updated.")
    case "invited": return qsTr("Invitation sent by email.")
    case "removed": return qsTr("Member removed.")
    case "canceled": return qsTr("Invitation canceled.")
    default: return ""
    }
}

function accessFailure(code) {
    switch (code) {
    case "": return ""
    case "forbidden": return qsTr("You do not have permission to manage this access.")
    case "already_exists": return qsTr("Something with this name already exists.")
    case "system_role": return qsTr("Built-in roles cannot be changed.")
    case "add_on_role": return qsTr("Add-on roles follow their add-on and cannot be changed.")
    case "reserved_role_key": return qsTr("This role key is reserved for add-ons.")
    case "limit_exceeded": return qsTr("The organization has reached its plan limit for this.")
    case "invalid_action": return qsTr("Choose at least one permission.")
    case "system_action": return qsTr("Some permissions are reserved for owners.")
    case "invalid_principal": return qsTr("Choose a person or group.")
    case "last_owner": return qsTr("The organization must keep at least one owner.")
    case "capability_missing": return qsTr("The plan has no guest seats.")
    case "quota_exceeded": return qsTr("The plan has no free seat for this role.")
    case "invalid_request": return qsTr("Check the required fields.")
    case "not_found": return qsTr("It no longer exists. Refresh to see the current access.")
    case "archived_read_only": return qsTr("It is archived.")
    case "network":
    case "server":
    case "session_expired":
    case "unauthenticated":
    case "rate_limited": return failure(code, "org")
    default: return qsTr("Could not complete the access request.")
    }
}

function accessNotice(code) {
    switch (code) {
    case "access_saved": return qsTr("Roles saved.")
    case "access_added": return qsTr("Access given.")
    case "access_removed": return qsTr("Access removed here. Access through groups or other places stays.")
    case "inheritance_stopped": return qsTr("Inheritance stopped.")
    case "inheritance_restored": return qsTr("Inheritance restored.")
    case "inheritance_opened": return qsTr("Open: every member except guests reads it now.")
    case "inheritance_restricted": return qsTr("Restricted: only access given here and below reaches it now.")
    case "role_created": return qsTr("Role created.")
    case "role_saved": return qsTr("Role saved. Everyone who holds it has the new permissions now.")
    case "role_archived": return qsTr("Role archived. Its grants no longer give access.")
    case "roles_saved": return qsTr("Roles saved.")
    case "group_created": return qsTr("Group created.")
    case "group_saved": return qsTr("Group renamed.")
    case "group_archived": return qsTr("Group archived. Its grants no longer give access.")
    case "group_members_saved": return qsTr("Members saved.")
    case "holders_added": return qsTr("Role given.")
    case "holders_removed": return qsTr("Role taken back.")
    case "groups_saved": return qsTr("Groups saved.")
    case "tag_created": return qsTr("Tag created.")
    case "tag_saved": return qsTr("Tag saved.")
    case "tag_restricted": return qsTr("Tag restricted.")
    case "tag_opened": return qsTr("Tag no longer restricts.")
    case "tag_archived": return qsTr("Tag archived.")
    case "space_renamed": return qsTr("Space renamed.")
    case "space_archived": return qsTr("Space archived. It stays readable.")
    default: return ""
    }
}

// A role as people read it: built-in roles in the reader's language.
function roleName(key, name) {
    switch (key) {
    case "owner": return qsTr("Owner")
    case "admin": return qsTr("Administrator")
    case "member": return qsTr("Member")
    case "billing": return qsTr("Billing")
    case "guest": return qsTr("Guest")
    case "content_reader": return qsTr("Content reader")
    case "content_contributor": return qsTr("Content contributor")
    case "content_purger": return qsTr("Content purger")
    case "content_sharer": return qsTr("Content sharer")
    case "access_manager": return qsTr("Access manager")
    case "space_maintainer": return qsTr("Space maintainer")
    case "add_on_manager": return qsTr("Add-on manager")
    case "automation_manager": return qsTr("Automation manager")
    case "content_manager": return qsTr("Content manager")
    case "space_operator": return qsTr("Space operator")
    case "space_admin": return qsTr("Space administrator")
    case "addon.controlled_docs.reviewer": return qsTr("Controlled documents reviewer")
    case "addon.controlled_docs.approver": return qsTr("Controlled documents approver")
    case "addon.controlled_docs.manager": return qsTr("Controlled documents manager")
    default: return name
    }
}

// An add-on by its product key, in the reader's language where it is known,
// else by `name`, else by its key.
function productName(key, name) {
    switch (key) {
    case "controlled_docs": return qsTr("Controlled documents")
    default: return name || key
    }
}

// Why the person may not do something, from Permissions' `explain`, with
// what is missing; empty while nothing refuses it.
function refusal(answer) {
    if (!answer || answer.known !== true || answer.allowed === true || answer.reason === undefined)
        return ""
    const product = productName(answer.product ?? "", answer.productName ?? "")
    switch (answer.reason) {
    case "plan": return qsTr("The plan does not include %1.").arg(product)
    case "uninstalled": return qsTr("%1 is not installed in the organization.").arg(product)
    case "paused": return qsTr("%1 is paused in the organization.").arg(product)
    case "inactive": return qsTr("%1 is not active in this space.").arg(product)
    }
    const roles = (answer.roles ?? []).map(function (role) { return roleName(role.key, role.name) })
    const named = roles.length > 1 ? qsTr("%1 or %2").arg(roles[0]).arg(roles[1]) : roles[0] ?? ""
    if (answer.spaceId === "")
        return named === "" ? qsTr("Your roles do not allow this.") : qsTr("You need %1 in the organization.").arg(named)
    if (named === "")
        return qsTr("Your access in this space does not allow this.")
    return answer.unsure === true ? qsTr("You need %1 in this space, with %2 active here.").arg(named).arg(product)
                                  : qsTr("You need %1 in this space.").arg(named)
}

// The command that fixes a refusal, by Permissions' `explain` `fix`.
function fixName(fix) {
    switch (fix) {
    case "grant": return qsTr("Grant access")
    case "activate": return qsTr("Activate")
    case "plan": return qsTr("Open plan")
    case "resume": return qsTr("Resume")
    case "install": return qsTr("Install")
    default: return ""
    }
}

// Core refused with `code` what `answer` (Permissions' `explain` of the
// action asked) explains: why, from the answer, for a refusal; else
// `fallback`'s words for the code.
function refused(code, answer, fallback) {
    const why = code === "forbidden" ? refusal(answer) : ""
    return why !== "" ? why : fallback(code)
}

// What kind of role `role` (an `AccessDirectory.roles` row) is.
function roleKind(role) {
    return role.origin === "system" ? qsTr("Built-in") : role.origin === "add_on" ? qsTr("Add-on") : qsTr("Custom")
}

// Where a role applies (`AccessDirectory.roles`' `appliesTo`).
function roleScope(appliesTo) {
    return appliesTo === "organization" ? qsTr("Organization") : qsTr("Spaces")
}

// Built-in organization role keys, by name, in the order Core lists them.
function roleNames(keys) {
    return keys.map(function (key) { return roleName(key, key) }).join(", ")
}

// The roles a holder (`{roles, archived}`) holds, by name, then the archived
// roles whose grants Core lists only on tags, where they still grant the tag.
function heldRoles(holder) {
    const said = []
    const names = (holder?.roles ?? []).map(function (role) { return roleName(role.key, role.name) })
    if (names.length > 0) said.push(names.join(", "))
    const archived = (holder?.archived ?? []).map(function (key) { return roleName(key, qsTr("Custom role")) })
    if (archived.length > 0) said.push(qsTr("Still granted through archived roles: %1").arg(archived.join(", ")))
    return said.join(" · ")
}

// What removing a member takes away: the places granted to them directly
// (among PrincipalAccess's `rows`), their groups (`{name}`), and the custom
// and add-on roles among their organization roles (PrincipalAccess's `roles`).
function memberImpact(rows, groups, assigned) {
    const said = [qsTr("They lose access to the organization.")]
    const roles = assigned.filter(function (role) { return role.origin !== "system" })
    const direct = rows.filter(function (row) { return row.kind === "grant" && row.direct })
                       .map(function (row) { return row.placeKind + ":" + row.placeId })
                       .filter(function (place, at, places) { return places.indexOf(place) === at }).length
    if (direct > 0)
        said.push(qsTr("Access given to them directly ends in %n place(s).", "", direct))
    if (groups.length > 0)
        said.push(qsTr("Groups they leave: %1.").arg(groups.map(function (group) { return group.name }).join(", ")))
    if (roles.length > 0)
        said.push(qsTr("Organization roles they lose: %1.")
                  .arg(roles.map(function (role) { return roleName(role.roleKey, role.roleName) }).join(", ")))
    return said.join(" ")
}

// A place access lists, by its `kind` and `name`, in `spaceName` when it
// is below a space.
function placeName(kind, name, spaceName) {
    const named = name !== "" ? name
                : kind === "space" ? qsTr("A space")
                : kind === "folder" ? qsTr("A folder")
                : kind === "document" ? qsTr("A document") : qsTr("A tag")
    return (kind === "folder" || kind === "document") && spaceName !== "" ? qsTr("%1 in %2").arg(named).arg(spaceName) : named
}

// How a folder or document inherits access, by AccessGrants' `summary`.
function inheritance(summary) {
    if (summary.inheritance === "restricted")
        return qsTr("Stopped: restricted")
    if (summary.inheritance === "open")
        return qsTr("Stopped: open to members")
    if ((summary.breakName ?? "") !== "")
        return qsTr("From %1, which stopped inheriting").arg(summary.breakName)
    return summary.visibility === undefined ? "" : qsTr("From the space")
}

// Where a PrincipalAccess row holds: the organization, or its place. A
// place-only role given across the organization (`idle`) does nothing there.
function accessWhere(row) {
    if (row.placeKind === "organization")
        return row.idle === true ? qsTr("Organization · no effect there") : qsTr("Organization")
    return placeName(row.placeKind, row.name, row.spaceName)
}

// How a PrincipalAccess row reaches its person or group: given to them,
// through a group or a role, or open to every member except guests.
function accessVia(row) {
    return row.kind === "open" ? qsTr("Open to members") : row.direct ? qsTr("Direct") : heldThrough(row)
}

// Where held roles come from: the person or group itself, a group, or a
// role whose holders a tag grant names.
function heldThrough(place) {
    if (place.direct)
        return ""
    if (place.viaKind === "role")
        return qsTr("Through the role %1").arg(roleName(place.viaKey, place.viaName))
    return qsTr("Through the group %1").arg(place.viaName || qsTr("a former group"))
}

// Where an access row (AccessView's) comes from: given here, or the space
// or folder it inherits from, saying when it only manages access here.
function accessSource(row) {
    if (!row.inherited)
        return qsTr("Given here")
    const from = row.sourceKind === "space" ? qsTr("From the space %1").arg(placeName("space", row.sourceName, ""))
                                            : qsTr("From the folder %1").arg(placeName("folder", row.sourceName, ""))
    return row.scope === "manage" ? qsTr("%1 · manages access only").arg(from) : from
}

// Why a member may act on a place, as AccessGrants' `explain` gives it.
function accessReason(reason) {
    switch (reason.kind) {
    case "tag":
        return reason.held ? qsTr("They hold the restricted tag %1.").arg(reason.sourceName)
                           : qsTr("The restricted tag %1 hides it from them.").arg(reason.sourceName)
    case "open":
        return reason.sourceKind === "space" ? qsTr("Every member except guests reads the space %1.").arg(placeName("space", reason.sourceName, ""))
                                             : qsTr("Every member except guests reads %1, which is open.").arg(placeName(reason.sourceKind, reason.sourceName, ""))
    case "organization":
        return reason.via !== ""
                ? qsTr("As %1 of the organization, through the group %2, they manage access everywhere.")
                  .arg(roleName(reason.roleKey, reason.roleKey)).arg(reason.via)
                : qsTr("As %1 of the organization, they manage access everywhere.").arg(roleName(reason.roleKey, reason.roleKey))
    default: {
        const role = roleName(reason.roleKey, reason.roleName)
        const place = placeName(reason.sourceKind, reason.sourceName, "")
        const said = reason.via !== "" ? qsTr("%1 on %2, through the group %3.").arg(role).arg(place).arg(reason.via)
                                       : qsTr("%1 on %2.").arg(role).arg(place)
        return reason.scope === "manage" ? said + " " + qsTr("Only its access management reaches here.") : said
    }
    }
}

// Who holds a grant: a person, a group, or everyone with a role on a tag.
function grantHolder(grant) {
    if (!grant)
        return ""
    if (grant.principalKind === "role")
        return qsTr("Everyone with %1").arg(roleName(grant.principalKey, grant.principalName))
    return grant.principalName || qsTr("Unknown holder")
}

// Roles (`AccessDirectory.roles` rows) as checklist choices: the role's id,
// its name as people read it, and what it allows.
function roleChoices(roles) {
    return roles.map(function (role) {
        return { value: role.id, label: roleName(role.key, role.name), detail: roleSummary(role.actions) }
    })
}

// What a set of actions lets its holder do, in a few words each.
function roleSummary(actions) {
    const has = function (action) { return actions.includes(action) }
    const said = []
    if (has("document.create") || has("document.new_version")) said.push(qsTr("Edit files"))
    else if (has("content.download") || has("content.read_metadata")) said.push(qsTr("Read files"))
    if (has("addon.controlled_docs.approve")) said.push(qsTr("Approve reviews"))
    else if (has("addon.controlled_docs.review_read")) said.push(qsTr("Read reviews"))
    if (has("addon.controlled_docs.document_manage")) said.push(qsTr("Manage document control"))
    if (has("document.purge")) said.push(qsTr("Purge files"))
    if (has("share.create")) said.push(qsTr("Share links"))
    if (has("resource_grant.create")) said.push(qsTr("Manage access"))
    if (has("space.update_metadata")) said.push(qsTr("Manage spaces"))
    if (has("add_on.space_activate")) said.push(qsTr("Turn on add-ons"))
    if (has("space_rule.create")) said.push(qsTr("Manage automations"))
    if (has("membership.invite") || has("principal_role.grant")) said.push(qsTr("Manage members"))
    if (has("role.create") || has("group.create")) said.push(qsTr("Manage roles and groups"))
    if (has("billing.manage")) said.push(qsTr("Manage billing"))
    if (has("add_on.install")) said.push(qsTr("Manage add-ons"))
    return said.length > 0 ? said.join(" · ") : qsTr("%n permission(s)", "", actions.length)
}

// Why a personal API token could not be listed, made, or revoked.
function tokenFailure(code) {
    switch (code) {
    case "password_required": return qsTr("Confirm your password to make a token.")
    case "invalid_credentials": return qsTr("That password is not correct.")
    case "invalid_scope": return qsTr("You no longer hold one of these actions there. Review the token’s access and try again.")
    case "invalid_expiry": return qsTr("Choose an expiry within 90 days.")
    case "name_required": return qsTr("Give the token a name.")
    case "not_found": return qsTr("This token no longer exists. Refresh the list.")
    default: return adminFailure(code)
    }
}

// A catalog action `{key, area}` as people read it; an action this app does
// not name yet by what follows its area.
function actionLabel(action) {
    switch (action.key) {
    case "organization.list": return qsTr("List organizations")
    case "organization.read": return qsTr("Read the organization")
    case "organization.update_policy": return qsTr("Change the organization policy")
    case "organization.transfer_ownership": return qsTr("Transfer ownership")
    case "organization.request_close": return qsTr("Request closing the organization")
    case "membership.list": return qsTr("List members")
    case "membership.create": return qsTr("Create users")
    case "membership.invite": return qsTr("Invite people")
    case "membership.invite_cancel": return qsTr("Cancel invitations")
    case "membership.invite_accept": return qsTr("Accept invitations")
    case "membership.revoke": return qsTr("Remove members")
    case "audit.read": return qsTr("Read the audit log")
    case "plan.read": return qsTr("Read the plan")
    case "usage.read": return qsTr("Read usage")
    case "billing.read": return qsTr("Read billing")
    case "billing.manage": return qsTr("Manage billing")
    case "add_on.read": return qsTr("Read add-ons")
    case "add_on.install": return qsTr("Install add-ons")
    case "add_on.run": return qsTr("Run add-ons")
    case "add_on.space_activate": return qsTr("Turn add-ons on in spaces")
    case "webhook.read": return qsTr("Read webhooks")
    case "webhook.manage": return qsTr("Manage webhooks")
    case "automation.create": return qsTr("Create automations")
    case "automation.read": return qsTr("Read automations")
    case "automation.update": return qsTr("Change automations")
    case "automation_version.create": return qsTr("Create automation versions")
    case "automation_version.read": return qsTr("Read automation versions")
    case "automation_version.update": return qsTr("Change automation versions")
    case "automation_credential.create": return qsTr("Create automation credentials")
    case "automation_credential.list": return qsTr("List automation credentials")
    case "automation_credential.revoke": return qsTr("Revoke automation credentials")
    case "automation_run.list": return qsTr("List automation runs")
    case "automation_run.read": return qsTr("Read automation runs")
    case "automation_run.cancel": return qsTr("Cancel automation runs")
    case "automation_run.retry": return qsTr("Retry automation runs")
    case "rule.read": return qsTr("Read rules")
    case "rule.preview": return qsTr("Preview rules")
    case "organization_rule.create": return qsTr("Create organization rules")
    case "organization_rule.update": return qsTr("Change organization rules")
    case "rule_version.update": return qsTr("Change rule versions")
    case "space.create": return qsTr("Create spaces")
    case "space.list": return qsTr("List spaces")
    case "space.delete": return qsTr("Delete spaces")
    case "space.read_metadata": return qsTr("Read space details")
    case "space.update_metadata": return qsTr("Change space details")
    case "space.archive": return qsTr("Archive spaces")
    case "space.reactivate": return qsTr("Reactivate spaces")
    case "space_rule.create": return qsTr("Create space rules")
    case "space_rule.read": return qsTr("Read space rules")
    case "space_rule.update": return qsTr("Change space rules")
    case "space_rule.activate": return qsTr("Turn on space rules")
    case "space_rule.pause": return qsTr("Pause space rules")
    case "space_rule.archive": return qsTr("Archive space rules")
    case "role.read": return qsTr("Read roles")
    case "role.create": return qsTr("Create roles")
    case "role.update": return qsTr("Change roles")
    case "role.archive": return qsTr("Archive roles")
    case "group.read": return qsTr("Read groups")
    case "group.create": return qsTr("Create groups")
    case "group.update": return qsTr("Rename groups")
    case "group.archive": return qsTr("Archive groups")
    case "group.membership_change": return qsTr("Change group members")
    case "principal_role.grant": return qsTr("Give organization roles")
    case "principal_role.revoke": return qsTr("Take back organization roles")
    case "tag.read": return qsTr("Read tags")
    case "tag.create": return qsTr("Create tags")
    case "tag.update": return qsTr("Change tags")
    case "tag.archive": return qsTr("Archive tags")
    case "resource_grant.read": return qsTr("See who has access")
    case "resource_grant.create": return qsTr("Give access")
    case "resource_grant.revoke": return qsTr("Remove access")
    case "access.configure": return qsTr("Change inheritance and visibility")
    case "event_history.read": return qsTr("Read activity")
    case "share.create": return qsTr("Create public links")
    case "share.list": return qsTr("List public links")
    case "share.revoke": return qsTr("Revoke public links")
    case "content.list": return qsTr("List files")
    case "content.search": return qsTr("Search files")
    case "content.read_metadata": return qsTr("Read file details")
    case "content.download": return qsTr("Download files")
    case "content.history.read": return qsTr("Read file history")
    case "content.version.list": return qsTr("List file versions")
    case "folder.create": return qsTr("Create folders")
    case "folder.rename": return qsTr("Rename folders")
    case "folder.move": return qsTr("Move folders")
    case "folder.delete": return qsTr("Delete folders")
    case "document.create": return qsTr("Create documents")
    case "document.rename": return qsTr("Rename documents")
    case "document.metadata_update": return qsTr("Change document details")
    case "document.add_tag": return qsTr("Tag documents")
    case "document.remove_tag": return qsTr("Remove tags from documents")
    case "document.new_version": return qsTr("Upload new versions")
    case "document.move": return qsTr("Move documents")
    case "document.move_in": return qsTr("Move documents in")
    case "document.move_out": return qsTr("Move documents out")
    case "document.trash": return qsTr("Trash documents")
    case "document.restore": return qsTr("Restore documents")
    case "document.purge": return qsTr("Purge documents")
    case "upload.create": return qsTr("Start uploads")
    case "upload.inspect": return qsTr("Inspect uploads")
    case "upload.presign": return qsTr("Sign upload parts")
    case "upload.complete": return qsTr("Complete uploads")
    case "upload.abort": return qsTr("Abort uploads")
    case "addon.controlled_docs.approve": return qsTr("Approve reviews")
    case "addon.controlled_docs.review_read": return qsTr("Read reviews")
    case "addon.controlled_docs.document_manage": return qsTr("Manage document control")
    default: return action.key.slice(action.area.length + 1).replace(/[._]/g, " ")
    }
}

// Action keys as catalog rows (`{key, area}`), an add-on's under its product.
function actionRows(keys) {
    return keys.map(function (key) {
        const parts = key.split(".")
        return { key: key, area: parts[0] === "addon" ? parts.slice(0, 2).join(".") : parts[0] }
    })
}

// Catalog actions (`{key, area}`) by the heading of their area, each heading
// once in the order it first comes: `{heading, actions}`.
function permissionGroups(actions) {
    const groups = []
    actions.forEach(function (action) {
        const heading = actionArea(action.area)
        let group = groups.find(function (found) { return found.heading === heading })
        if (!group) {
            group = { heading: heading, actions: [] }
            groups.push(group)
        }
        group.actions.push(action)
    })
    return groups
}

// The heading of a group of actions in the role editor, by key prefix.
function actionArea(area) {
    switch (area) {
    case "content": return qsTr("Files")
    case "folder": return qsTr("Folders")
    case "document": return qsTr("Documents")
    case "upload": return qsTr("Uploads")
    case "space": return qsTr("Spaces")
    case "space_rule": return qsTr("Space rules")
    case "access":
    case "resource_grant": return qsTr("Access grants")
    case "role": return qsTr("Roles")
    case "group": return qsTr("Groups")
    case "principal_role": return qsTr("Role assignments")
    case "tag": return qsTr("Tags")
    case "membership": return qsTr("Members")
    case "organization": return qsTr("Organization")
    case "share": return qsTr("Public links")
    case "billing": return qsTr("Billing")
    case "plan": return qsTr("Plan")
    case "usage": return qsTr("Usage")
    case "add_on": return qsTr("Add-ons")
    case "webhook": return qsTr("Webhooks")
    case "audit": return qsTr("Audit")
    case "event_history": return qsTr("Activity")
    case "automation":
    case "automation_version":
    case "automation_run":
    case "automation_credential": return qsTr("Automations")
    case "rule":
    case "organization_rule":
    case "rule_version": return qsTr("Rules")
    case "addon.controlled_docs": return qsTr("Document control")
    case "addon.classifier": return qsTr("Classifier")
    default: return area
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

// The spaces an invitation offers access to, by name; `names` holds an
// empty string for a space the space list does not name.
function invitationAccess(names) {
    if (names.length === 0)
        return ""
    return names.includes("") ? qsTr("Access to %n space(s)", "", names.length) : qsTr("Access to %1").arg(names.join(", "))
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

// An add-on's state in the organization, by its installation `{status}`.
function addOnStatus(installation) {
    if (installation?.status === "active")
        return qsTr("Installed")
    return installation?.status === "paused" ? qsTr("Paused") : qsTr("Not installed")
}

// An add-on's state in one space, by its AddOnActivations row.
function activationState(row) {
    if (row.installation_status === "paused")
        return qsTr("Paused in the organization")
    return row.status === "active" ? qsTr("Active") : qsTr("Inactive")
}

// What pausing or uninstalling (`action`) the add-on `key` takes away:
// who holds the roles it adds, from AddOnAccess's `impact` when it adds
// roles (`addsRoles`), the `spaces` where it is active, then what happens to
// its work and billing.
function addOnImpact(impact, action, key, addsRoles, spaces) {
    const said = []
    if (!addsRoles)
        said.push("")
    else if (impact?.known !== true)
        said.push(impact?.holders === undefined ? qsTr("Counting who holds roles from this add-on…")
                                                : qsTr("Could not count who holds roles from this add-on."))
    else if (impact.holders === 0)
        said.push(qsTr("Nobody holds a role from this add-on."))
    else
        said.push(qsTr("%n person(s) or group(s) lose the roles this add-on adds: %1.", "", impact.holders)
                  .arg(Object.keys(impact.roles).sort().map(function (key) {
                      return qsTr("%1: %2").arg(roleName(key, key)).arg(impact.roles[key])
                  }).join(" · ")) + " "
                  + qsTr("They hold them in %n space(s).", "", impact.spaces))
    said.push(qsTr("It stops in %n space(s) where it is active.", "", spaces))
    if (key === "controlled_docs" && action === "pause")
        said.push(qsTr("Open reviews wait until you resume. Published documents stay readable. Billing is unchanged."))
    else if (key === "controlled_docs")
        said.push(qsTr("All open reviews are cancelled and document control is removed from every document. After reinstalling, each document must be managed with reviews again. Published versions and billing remain. To stop for a while, pause instead."))
    else
        said.push(qsTr("Its space activations, space settings, and grants are kept. Billing is unchanged."))
    return said.filter(function (part) { return part !== "" }).join("\n\n")
}

// A metered add-on's usage against its allowance, in the meter's unit.
function allowance(product) {
    const dimension = product?.meter_dimension
    return qsTr("Used: %1 · Reserved: %2 · Allowance: %3")
            .arg(usageAmount(product?.usage?.confirmed ?? 0, dimension))
            .arg(usageAmount(product?.usage?.reserved ?? 0, dimension))
            .arg(usageAmount(product?.allowance?.limit, dimension))
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
    case "invalid_settings": return qsTr("The server refused these add-on settings.")
    case "invalid_responsible_membership": return qsTr("That member is no longer active in this organization. Choose another.")
    case "billing_provider_error": return qsTr("The payment provider is unavailable. Try again later.")
    default: return adminFailure(code)
    }
}

function controlledFailure(code) {
    switch (code) {
    case "forbidden": return qsTr("You do not have permission for this document, review, or space operation.")
    case "not_found": return qsTr("This document or review is no longer available to you. Refresh the current space.")
    case "controlled_docs_unavailable": return qsTr("Controlled documents is not active in this space.")
    case "add_on_unavailable": return qsTr("The add-on is not installed and active in the organization.")
    case "review_closed": return qsTr("This review was already decided. Refresh to see the result.")
    case "stale_base": return qsTr("This review is not based on the published version. Its author must update it before it can be approved.")
    case "merge_too_large": return qsTr("This review is too large to merge here. Download the proposal, apply your changes to the published version, and submit it again.")
    case "stale_activation": return qsTr("Controlled documents changed in this space since the review was submitted.")
    case "already_approved": return qsTr("You already approved this version. Another reviewer must approve it too.")
    case "invalid_settings": return qsTr("The server refused these settings. Check the allowed values and try again.")
    case "revision_conflict": return qsTr("The document, review, or space settings changed. Refresh and inspect the current state before trying again.")
    case "revision_required": return qsTr("Refresh to obtain the current revision before saving.")
    case "published_version_required": return qsTr("Upload a Markdown version before managing this document with reviews.")
    case "diff_too_large": return qsTr("This diff exceeds the server limit. Download the proposal to inspect it.")
    case "candidate_unavailable": return qsTr("The proposal is unavailable. Refresh this review.")
    case "invalid_comment": return qsTr("Use a decision comment of at most 2,000 characters without NUL characters.")
    case "incompatible_publication_subscriptions": return qsTr("Pause incompatible readiness automations or processing subscriptions before enabling control.")
    default: return documentFailure(code)
    }
}

// Why turning controlled documents on or off in a space, or changing its
// settings there, failed: Core refuses while the space has open reviews.
function ruleFailure(code) {
    switch (code) {
    case "review_open": return qsTr("This space has open reviews. Decide or cancel them before changing whether reviews are required or the space’s settings.")
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
    case "rerun_on_new_version": return qsTr("Classify every new version")
    case "labels": return qsTr("Tags")
    default: {
        const words = String(key).replace(/_/g, " ")
        return words.charAt(0).toUpperCase() + words.slice(1)
    }
    }
}

// An add-on setting's value as people read it, by its `settings_schema` spec.
function settingValue(spec, value) {
    if (spec?.type === "boolean") return value === true ? qsTr("On") : qsTr("Off")
    if (Array.isArray(value)) return value.length === 0 ? qsTr("Not set") : value.join(", ")
    return value === null || value === undefined || value === "" ? qsTr("Not set") : String(value)
}

function settingDetail(key) {
    switch (key) {
    case "require_version_references": return qsTr("Images and linked files must pin a version, so an approved document shows exactly what was reviewed.")
    case "allow_author_approval": return qsTr("The author’s approval counts toward the required approvals. Only another reviewer can reject.")
    case "required_approvals": return qsTr("How many different reviewers must approve a proposal before it is published.")
    case "rerun_on_new_version": return qsTr("Classify a document again each time a new version is published, not only its first.")
    case "labels": return qsTr("The tags the classifier may apply to a document. Each is up to 80 characters and appears once.")
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

// What turning an add-on on or off in a space did (AddOnActivations' notice).
function activationNotice(code) {
    switch (code) {
    case "activated": return qsTr("Active in the space.")
    case "deactivated": return qsTr("Off in the space. Its space settings are kept.")
    case "activation_saved": return qsTr("Space settings saved.")
    default: return ""
    }
}

function controlledNotice(code) {
    switch (code) {
    case "control_enabled": return qsTr("Document control enabled.")
    case "control_removed": return qsTr("Document control removed. Open reviews were cancelled.")
    case "review_approve": return qsTr("Proposal approved and published.")
    case "review_approval_added": return qsTr("Approval recorded. The proposal is published once enough reviewers approve it.")
    case "review_reject": return qsTr("Proposal rejected. The published version remains available.")
    case "review_cancel": return qsTr("Review cancelled. The published version remains available.")
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
    default: return qsTr("Up to date with the published version")
    }
}

// What an open review's `merge_state` asks of its author or its reviewers.
function mergeAdvice(value, author) {
    switch (value) {
    case "behind": return author
            ? qsTr("Another review was approved after yours. Your changes merge without conflicts: choose Update review to base it on the published version.")
            : qsTr("Another review was approved after this one. Its author must update it before it can be approved; it can still be rejected.")
    case "dirty": return author
            ? qsTr("Another review changed the same lines after yours. Choose Resolve conflicts to settle them in the editor.")
            : qsTr("This review conflicts with the published version. Its author must resolve the conflicts before it can be approved; it can still be rejected.")
    default: return ""
    }
}
