pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that stops the folder or document
// `Session.accessGrants` has open from inheriting access, or switches one
// that stopped between the two ways: Restricted keeps only the access given
// here and below, Open also lets every member except guests read it. Core
// copies nothing down, so it says who keeps access (the access `rows` given
// here, and those that manage access from above) and who loses it.
PanelBody {
    id: panel

    required property var rows
    // How it stops inheriting now; empty while it inherits.
    readonly property string current: Session.accessGrants.summary.inheritance ?? ""
    property string choice: panel.current === "open" ? "open" : "restricted"
    property bool sent: false
    readonly property var kept: panel.rows.filter(function (row) { return !row.inherited || panel.manages(row) })
    readonly property var lost: panel.rows.filter(function (row) { return row.inherited && !panel.manages(row) })

    // Whether a role of `row` manages access, which a break leaves in force.
    function manages(row) {
        return row.roles.some(function (held) {
            const role = Session.accessDirectory.roles.find(function (listed) { return listed.id === held.id })
            return (role?.actions ?? []).some(function (action) {
                return action.startsWith("resource_grant.") || action === "access.configure"
            })
        })
    }
    function names(rows) {
        return rows.map(function (row) { return Messages.grantHolder(row) })
                   .filter(function (name, at, all) { return all.indexOf(name) === at }).join(", ")
    }

    title: panel.current === "" ? qsTr("Stop inheriting") : qsTr("Change inheritance")
    subtitle: Messages.placeName(Session.accessGrants.kind, Session.accessGrants.name, "")
    saveText: panel.current === "" ? qsTr("Stop inheriting") : qsTr("Save")
    saveUsable: !Session.accessGrants.busy && panel.choice !== panel.current
    objectName: "inheritancePanel"

    onSaveRequested: {
        panel.sent = true
        Session.accessGrants.setInheritance(panel.choice)
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
        objectName: "inheritanceError"
        visible: Session.accessGrants.errorCode !== ""
        text: Messages.refused(Session.accessGrants.errorCode, managing.answer, Messages.accessFailure)
        Gate { id: managing; action: "resource_grant.create"; spaceId: Session.accessGrants.spaceId }
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Repeater {
        model: [{ value: "restricted", label: qsTr("Restricted"), detail: qsTr("Only access given here and below") },
                { value: "open", label: qsTr("Open"), detail: qsTr("Every member except guests also reads it") }]
        delegate: NavigationRow {
            id: option
            required property var modelData
            objectName: "inheritance_" + option.modelData.value
            touch: panel.narrow
            text: option.modelData.label
            detail: option.modelData.detail
            icon: panel.choice === option.modelData.value ? "checkbox-checked" : "checkbox"
            checkable: true
            selected: panel.choice === option.modelData.value
            usable: !Session.accessGrants.busy
            onActivated: panel.choice = option.modelData.value
        }
    }
    Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapS; text: qsTr("Keeps access") }
    Label {
        objectName: "inheritanceKept"
        text: [panel.kept.length > 0 ? panel.names(panel.kept) : qsTr("Nobody given access here."),
               panel.choice === "open" ? qsTr("Every member except guests reads it.") : ""]
              .filter(function (part) { return part !== "" }).join(" ")
    }
    Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapS; text: qsTr("Loses access") }
    Label {
        objectName: "inheritanceLost"
        text: panel.lost.length > 0 ? panel.names(panel.lost) : qsTr("Nobody.")
    }
}
