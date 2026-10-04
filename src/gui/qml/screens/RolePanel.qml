pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that makes a custom role, or edits custom role
// `roleId`: its name and the catalog's actions it holds, by area. A new
// role applies to the organization or to spaces; `source` names a role a
// new one copies. `created` names a role just made.
PanelBody {
    id: panel

    property string roleId
    property string source
    property bool tried: false
    property bool sent: false
    property var chosen: []
    property string axis: "space"
    readonly property bool creating: panel.roleId === ""
    readonly property var role: Session.accessDirectory.roles.find(function (row) { return row.id === panel.roleId }) ?? null
    readonly property var from: Session.accessDirectory.roles.find(function (row) {
        return row.id === (panel.creating ? panel.source : panel.roleId)
    }) ?? null
    readonly property string name: nameField.text.trim()
    readonly property var catalog: Session.accessDirectory.catalog
    // An organization role picks among every action, its space actions
    // holding in every space; a space role only among space actions.
    readonly property var axes: panel.axis === "organization" ? ["organization", "space"] : ["space"]
    readonly property var kept: panel.chosen.filter(function (key) {
        return panel.catalog.some(function (action) { return action.key === key && panel.axes.includes(action.axis) })
    })
    // A role archived meanwhile is not edited.
    readonly property bool edited: panel.name !== "" && panel.kept.length > 0
                                   && (panel.creating || panel.role !== null && (panel.name !== panel.role.name
                                       || panel.kept.length !== panel.role.actions.length
                                       || panel.kept.some(function (key) { return !panel.role.actions.includes(key) })))
    readonly property bool busy: Session.accessDirectory.busy

    signal created(string id)

    function toggle(key) {
        panel.chosen = panel.chosen.includes(key) ? panel.chosen.filter(function (held) { return held !== key })
                                                  : panel.chosen.concat([key])
    }
    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (Session.accessDirectory.errorCode === "" && !panel.creating)
            panel.finished()
    }

    title: panel.creating ? qsTr("New role") : qsTr("Edit permissions")
    subtitle: panel.creating ? "" : panel.role?.name ?? ""
    saveText: panel.creating ? qsTr("Create role") : qsTr("Save")
    saveUsable: !panel.busy && panel.edited
    initialFocus: nameField
    objectName: "rolePanel"

    onSaveRequested: {
        panel.tried = true
        panel.sent = true
        if (panel.creating) Session.accessDirectory.createRole(panel.name, panel.kept)
        else Session.accessDirectory.updateRole(panel.roleId, panel.name, panel.kept)
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)
    Component.onCompleted: {
        panel.axis = panel.from?.appliesTo ?? "space"
        panel.chosen = (panel.from?.actions ?? []).slice()
        nameField.text = panel.from === null ? "" : panel.creating ? qsTr("Copy of %1").arg(Messages.roleName(panel.from.key, panel.from.name))
                                                                    : panel.from.name
    }

    Connections {
        target: Session.accessDirectory
        function onSaved(notice, id) {
            if (panel.creating && panel.sent && notice === "role_created" && id !== "") panel.created(id)
        }
    }

    Label {
        objectName: "rolePanelError"
        visible: panel.tried && Session.accessDirectory.errorCode !== ""
        text: Messages.accessFailure(Session.accessDirectory.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Label { text: qsTr("Name") }
    Field {
        id: nameField
        objectName: "roleNameField"
        placeholderText: qsTr("For example: Contract reviewers")
        maximumLength: 80
        Accessible.name: qsTr("Name")
        onTextChanged: panel.tried = false
        onAccepted: if (panel.saveUsable) panel.saveRequested()
    }
    Label {
        visible: panel.creating
        Layout.topMargin: Theme.gapS
        text: qsTr("Applies to")
    }
    Picker {
        id: axisPicker
        objectName: "roleAxis"
        visible: panel.creating
        Layout.fillWidth: true
        model: [{ value: "organization", label: Messages.roleScope("organization") },
                { value: "space", label: Messages.roleScope("space") }]
        value: panel.axis
        Accessible.name: qsTr("Applies to")
        onActivated: panel.axis = axisPicker.currentValue
    }
    Repeater {
        model: Messages.permissionGroups(panel.catalog.filter(function (action) { return panel.axes.includes(action.axis) }))
        delegate: ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: Theme.gapS
            spacing: Theme.gapXs
            Caption { Layout.fillWidth: true; text: group.modelData.heading }
            Repeater {
                model: group.modelData.actions
                delegate: NavigationRow {
                    id: permission
                    required property var modelData
                    readonly property bool held: panel.chosen.includes(permission.modelData.key)
                    objectName: "permission_" + permission.modelData.key
                    touch: panel.narrow
                    text: Messages.actionLabel(permission.modelData)
                    icon: permission.held ? "checkbox-checked" : "checkbox"
                    checkable: true
                    selected: permission.held
                    usable: !panel.busy
                    onActivated: panel.toggle(permission.modelData.key)
                }
            }
        }
    }
}
