pragma ComponentBehavior: Bound

import QtQuick
import matome
import "Messages.js" as Messages

// Whether the signed-in person holds `action` across the current
// organization or, with `spaceId`, in that space, as Session.permissions
// judges it: a command binds `allowed` into its `usable` and `reason` into
// its own. Unread, it allows, and Core decides.
QtObject {
    id: gate

    property string action
    property string spaceId
    readonly property var answer: Session.permissions.revision >= 0 && gate.action !== ""
                                  ? Session.permissions.explain(gate.action, gate.spaceId) : ({})
    readonly property bool allowed: gate.answer.known !== true || gate.answer.allowed === true
    readonly property string reason: gate.allowed ? "" : Messages.refusal(gate.answer)
}
