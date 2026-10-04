pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that grants access to what `Session.accessGrants` has
// open, the same for a space, folder, document, or tag: first pick people
// and groups (and roles, on a tag), then check roles; each one picked gets
// them beside what it already holds here, `presetRoles` checked at first.
PanelBody {
    id: panel

    property var presetRoles: []
    property bool sent: false
    readonly property bool tag: Session.accessGrants.kind === "tag"

    title: qsTr("Grant access")
    subtitle: panel.step === "" ? Messages.placeName(Session.accessGrants.kind, Session.accessGrants.name, "")
                                : qsTr("%n picked", "", people.checked.length)
    saveText: panel.step === "" ? qsTr("Next") : qsTr("Grant access")
    saveUsable: !Session.accessGrants.busy && (panel.step === "" ? people.checked.length > 0 : roles.checked.length > 0)
    objectName: "grantPanel"

    Component.onCompleted: roles.checked = panel.presetRoles.slice()
    onSaveRequested: {
        if (panel.step === "") {
            panel.step = "roles"
            return
        }
        panel.sent = true
        Session.accessGrants.add(people.checked, roles.checked)
    }

    Connections {
        target: Session.accessGrants
        function onChanged() {
            if (panel.sent && !Session.accessGrants.busy) {
                panel.sent = false
                if (Session.accessGrants.errorCode === "") panel.finished()
            }
        }
    }

    Label {
        objectName: "grantPanelError"
        visible: Session.accessGrants.errorCode !== ""
        text: Messages.refused(Session.accessGrants.errorCode, managing.answer, Messages.accessFailure)
        Gate { id: managing; action: "resource_grant.create"; spaceId: Session.accessGrants.spaceId }
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Caption {
        Layout.fillWidth: true
        text: panel.step === "" ? (panel.tag ? qsTr("People, groups, and roles") : qsTr("People and groups")) : qsTr("Roles")
    }
    Checklist {
        id: people
        visible: panel.step === ""
        prefix: "grantPrincipal_"
        touch: panel.narrow
        searchFrom: 6
        searchLabel: panel.tag ? qsTr("Search people, groups, and roles") : qsTr("Search people and groups")
        choices: Session.accessGrants.principals.map(function (row) {
            return { value: row.value,
                     label: row.kind === "role" ? qsTr("Everyone with %1").arg(Messages.roleName(row.key, row.label)) : row.label,
                     detail: row.kind === "group" ? qsTr("Group") : row.kind === "role" ? qsTr("Role") : "" }
        })
        usable: !Session.accessGrants.busy
    }
    Checklist {
        id: roles
        visible: panel.step === "roles"
        prefix: "grantRole_"
        touch: panel.narrow
        searchFrom: 6
        searchLabel: qsTr("Search roles")
        choices: Messages.roleChoices(Session.accessDirectory.grantableRoles)
        emptyText: qsTr("No roles to give yet.")
        usable: !Session.accessGrants.busy
    }
}
