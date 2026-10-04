pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The Roles tab of the person or group `principal`: the organization roles
// `Session.principalAccess` read for them, each with where it holds. Its
// commands ask for the panel that takes back the rows selected
// (`panelRequested`) and open the role of the one selected.
DetailTab {
    id: tab

    required property string principal
    property bool touch: false
    readonly property bool loaded: Session.principalAccess.principal === tab.principal
    // What Remove takes back: the keys of the rows selected, and a line
    // naming each.
    readonly property var removal: ({ keys: table.selectedKeys, lines: table.selectedRows.map(function (row) {
        return Messages.roleName(row.roleKey, row.roleName) + " · " + Messages.accessWhere(row)
    }) })

    signal panelRequested(string kind, Item from)
    signal entryRequested(string section, string id, string name)

    function open(row) {
        tab.entryRequested("roles", row.roleId, Messages.roleName(row.roleKey, row.roleName))
    }

    view: "roles"
    title: qsTr("Roles")

    commands: [
        ActionButton {
            id: remove
            objectName: "heldRoleRemoveButton"
            text: qsTr("Remove")
            icon: "trash"
            showLabel: !tab.compact
            tip: tab.compact ? text : ""
            usable: tab.loaded && !Session.principalAccess.busy && table.selectedRows.length > 0
            reason: table.selectedRows.length === 0 ? qsTr("Select what to remove.") : ""
            onActivated: tab.panelRequested("removeHeld", remove)
        },
        ActionButton {
            objectName: "heldRoleOpenButton"
            text: qsTr("Open")
            icon: "forward"
            showLabel: !tab.compact
            tip: tab.compact ? text : ""
            usable: table.selectedRow !== null
            reason: qsTr("Select one row.")
            onActivated: tab.open(table.selectedRow)
        }
    ]

    Table {
        id: table
        objectName: "heldRoles"
        label: qsTr("Roles")
        prefix: "heldRole_"
        multiSelect: true
        touch: tab.touch
        columns: [{ title: qsTr("Role"), share: 3 }, { title: qsTr("Where"), share: 2 }]
        model: tab.loaded ? Session.principalAccess.rows.filter(function (row) { return row.kind === "assignment" }) : []
        keyOf: function (row) { return row.key }
        cells: function (row) { return [Messages.roleName(row.roleKey, row.roleName), Messages.accessWhere(row)] }
        emptyText: tab.loaded && !Session.principalAccess.busy && Session.principalAccess.errorCode === "" ? qsTr("None.") : ""
        onOpened: function (row) { tab.open(row) }
    }
}
