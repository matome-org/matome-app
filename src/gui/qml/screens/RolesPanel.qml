pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that leaves the person or group `principal` exactly
// the organization roles checked, built-in ones first; Core's refusal, such
// as removing the last owner, shows here.
PanelBody {
    id: panel

    required property string principal
    property string name
    property bool tried: false
    property bool sent: false
    readonly property bool busy: Session.principalAccess.busy || Session.accessDirectory.busy

    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (Session.principalAccess.errorCode === "")
            panel.finished()
    }

    title: qsTr("Manage roles")
    subtitle: panel.name
    saveText: qsTr("Save")
    saveUsable: !panel.busy && roles.loaded && roles.edited
    objectName: "rolesPanel"

    onSaveRequested: {
        panel.tried = true
        panel.sent = true
        roles.save()
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)

    Label {
        objectName: "rolesPanelError"
        visible: panel.tried && Session.principalAccess.errorCode !== ""
        text: Messages.refused(Session.principalAccess.errorCode, granting.answer, Messages.accessFailure)
        Gate { id: granting; action: "principal_role.grant" }
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    PrincipalRoles {
        id: roles
        principal: panel.principal
        prefix: "manageRole_"
        touch: panel.narrow
        usable: !panel.busy && roles.loaded
    }
}
