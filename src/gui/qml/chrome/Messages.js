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
    if (code === "invalid_reset_token")
        return qsTr("That reset token is wrong or has expired.")
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
