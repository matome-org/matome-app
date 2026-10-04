pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome/Messages.js" as Messages

// The organization roles of the person or group `principal` as checkboxes,
// built-in ones first, from what `Session.principalAccess` read: `edited` once the
// ticked ones differ, and `save` makes them exactly the principal's. They
// tick again as read whenever what was read changes.
Checklist {
    id: roles

    required property string principal
    readonly property bool loaded: Session.principalAccess.principal === roles.principal
    readonly property var held: roles.loaded ? Session.principalAccess.roleIds : []
    readonly property bool edited: roles.differsFrom(roles.held)
    readonly property string stamp: roles.principal + "|" + roles.held.join(",")

    function save() {
        if (roles.edited) Session.principalAccess.setRoles(roles.checked)
    }

    onStampChanged: roles.checked = roles.held.slice()
    Component.onCompleted: roles.checked = roles.held.slice()
    searchFrom: 12
    searchLabel: qsTr("Search roles")
    choices: Messages.roleChoices(Session.accessDirectory.assignableRoles)
    emptyText: qsTr("No roles to give.")
}
