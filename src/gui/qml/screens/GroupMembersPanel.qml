pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that leaves group `groupId` with exactly the people
// checked, searchable once there are a few.
PanelBody {
    id: panel

    required property string groupId
    property bool tried: false
    property bool sent: false
    readonly property var group: Session.accessDirectory.groups.find(function (row) { return row.id === panel.groupId }) ?? null
    readonly property var held: (panel.group?.members ?? []).map(function (person) { return person.id })
    readonly property bool busy: Session.accessDirectory.busy

    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (Session.accessDirectory.errorCode === "")
            panel.finished()
    }

    title: qsTr("Manage members")
    subtitle: panel.group?.name ?? ""
    saveText: qsTr("Save")
    saveUsable: !panel.busy && people.differsFrom(panel.held)
    objectName: "groupMembersPanel"

    onSaveRequested: {
        panel.tried = true
        panel.sent = true
        Session.accessDirectory.setGroupMembers(panel.groupId, people.checked)
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)
    Component.onCompleted: people.checked = panel.held.slice()

    Label {
        objectName: "groupMembersError"
        visible: panel.tried && Session.accessDirectory.errorCode !== ""
        text: Messages.accessFailure(Session.accessDirectory.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Checklist {
        id: people
        prefix: "groupMember_"
        touch: panel.narrow
        searchFrom: 6
        searchLabel: qsTr("Search people")
        choices: Session.accessDirectory.members.map(function (row) { return { value: row.id, label: row.label } })
        emptyText: qsTr("No members yet.")
        usable: !panel.busy
    }
}
