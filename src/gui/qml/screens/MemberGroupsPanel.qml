pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that leaves member `memberId` in exactly the groups
// checked.
PanelBody {
    id: panel

    required property string memberId
    property string name
    property bool tried: false
    property bool sent: false
    readonly property bool busy: Session.accessDirectory.busy
    readonly property var held: Session.accessDirectory.groups.filter(function (group) {
        return group.members.some(function (person) { return person.id === panel.memberId })
    }).map(function (group) { return group.id })

    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (Session.accessDirectory.errorCode === "")
            panel.finished()
    }

    title: qsTr("Manage groups")
    subtitle: panel.name
    saveText: qsTr("Save")
    saveUsable: !panel.busy && groups.differsFrom(panel.held)
    objectName: "memberGroupsPanel"

    onSaveRequested: {
        panel.tried = true
        panel.sent = true
        Session.accessDirectory.setMemberGroups(panel.memberId, groups.checked)
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)
    Component.onCompleted: groups.checked = panel.held.slice()

    Label {
        objectName: "memberGroupsError"
        visible: panel.tried && Session.accessDirectory.errorCode !== ""
        text: Messages.accessFailure(Session.accessDirectory.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Checklist {
        id: groups
        prefix: "memberGroup_"
        touch: panel.narrow
        searchLabel: qsTr("Search groups")
        choices: Session.accessDirectory.groups.map(function (group) { return { value: group.id, label: group.name } })
        emptyText: qsTr("No groups yet.")
        usable: !panel.busy
    }
}
