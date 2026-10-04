pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that gives the role open in `Session.roleHolders` to
// the people and groups checked: across the organization, among those not
// holding it yet, or, for a role that applies in spaces (`inSpace`), in the
// space picked next.
PanelBody {
    id: panel

    property string name
    property bool inSpace: false
    property bool tried: false
    property bool sent: false
    readonly property bool busy: Session.roleHolders.busy
    readonly property var choices: Session.accessDirectory.members.map(function (row) {
        return { value: "user:" + row.id, label: row.label }
    }).concat(Session.accessDirectory.groups.map(function (row) {
        return { value: "group:" + row.id, label: row.name, detail: qsTr("Group") }
    })).filter(function (choice) { return panel.inSpace || !Session.roleHolders.assigned.includes(choice.value) })

    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (Session.roleHolders.errorCode === "")
            panel.finished()
    }

    title: qsTr("Add people")
    subtitle: panel.step === "" ? panel.name : qsTr("%n picked", "", principals.checked.length)
    saveText: panel.inSpace && panel.step === "" ? qsTr("Next") : qsTr("Add")
    saveUsable: !panel.busy && principals.checked.length > 0 && (panel.step === "" || place.place !== null)
    objectName: "addPeoplePanel"

    onSaveRequested: {
        if (panel.inSpace && panel.step === "") {
            panel.step = "place"
            return
        }
        panel.tried = true
        panel.sent = true
        if (panel.inSpace)
            Session.roleHolders.grant(principals.checked, place.place.spaceId)
        else
            Session.roleHolders.add(principals.checked)
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)

    Label {
        objectName: "addPeopleError"
        visible: panel.tried && Session.roleHolders.errorCode !== ""
        text: Messages.accessFailure(Session.roleHolders.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Checklist {
        id: principals
        visible: panel.step === ""
        prefix: "addHolder_"
        touch: panel.narrow
        searchFrom: 6
        searchLabel: qsTr("Search people and groups")
        choices: panel.choices
        emptyText: qsTr("Everyone holds this role.")
        usable: !panel.busy
    }
    PlacePicker {
        id: place
        visible: panel.step === "place"
        touch: panel.narrow
        usable: !panel.busy
    }
}
