pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that leaves the access row `holder` exactly the roles
// checked here, every role a grant may carry as a checkbox.
PanelBody {
    id: panel

    required property var holder
    property bool sent: false
    readonly property var held: panel.holder?.roleIds ?? []

    title: qsTr("Manage roles")
    subtitle: Messages.grantHolder(panel.holder)
    saveText: qsTr("Save")
    saveUsable: !Session.accessGrants.busy && panel.holder !== null && roles.differsFrom(panel.held)
    objectName: "holderRolesPanel"

    Component.onCompleted: roles.checked = panel.held.slice()
    onSaveRequested: {
        panel.sent = true
        Session.accessGrants.setRoles(panel.holder.principal, roles.checked)
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
        objectName: "holderRolesError"
        visible: Session.accessGrants.errorCode !== ""
        text: Messages.refused(Session.accessGrants.errorCode, managing.answer, Messages.accessFailure)
        Gate { id: managing; action: "resource_grant.create"; spaceId: Session.accessGrants.spaceId }
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Checklist {
        id: roles
        prefix: "grantRole_"
        touch: panel.narrow
        searchFrom: 6
        searchLabel: qsTr("Search roles")
        choices: Messages.roleChoices(Session.accessDirectory.grantableRoles)
        emptyText: qsTr("No roles to give yet.")
        usable: !Session.accessGrants.busy
    }
    Label {
        visible: (panel.holder?.archived ?? []).length > 0
        text: qsTr("Grants through archived roles stay as they are.")
    }
}
