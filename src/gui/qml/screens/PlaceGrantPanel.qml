pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that grants the person or group open in
// `Session.principalAccess` roles on a place: first pick a space or a tag,
// then check roles, given there beside what they hold.
PanelBody {
    id: panel

    property string name
    property bool tried: false
    property bool sent: false
    readonly property bool busy: Session.principalAccess.busy

    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (Session.principalAccess.errorCode === "")
            panel.finished()
    }

    title: qsTr("Grant access")
    subtitle: panel.step === "" ? panel.name : Messages.placeName(place.place?.kind ?? "", place.place?.name ?? "", "")
    saveText: panel.step === "" ? qsTr("Next") : qsTr("Grant access")
    saveUsable: !panel.busy && (panel.step === "" ? place.place !== null : roles.checked.length > 0)
    objectName: "placeGrantPanel"

    onSaveRequested: {
        if (panel.step === "") {
            panel.step = "roles"
            return
        }
        panel.tried = true
        panel.sent = true
        Session.principalAccess.grant(place.place.kind, place.place.spaceId, place.place.id, roles.checked)
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)

    Label {
        objectName: "placeGrantError"
        visible: panel.tried && Session.principalAccess.errorCode !== ""
        text: Messages.accessFailure(Session.principalAccess.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    PlacePicker {
        id: place
        visible: panel.step === ""
        tags: true
        touch: panel.narrow
        usable: !panel.busy
    }
    Caption {
        visible: panel.step === "roles"
        Layout.fillWidth: true
        text: qsTr("Roles")
    }
    Checklist {
        id: roles
        visible: panel.step === "roles"
        prefix: "placeGrantRole_"
        touch: panel.narrow
        searchFrom: 6
        searchLabel: qsTr("Search roles")
        choices: Messages.roleChoices(Session.accessDirectory.grantableRoles)
        emptyText: qsTr("No roles to give yet.")
        usable: !panel.busy
    }
}
