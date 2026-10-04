pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that says what one member may do in what
// `Session.accessGrants` has open, and why: pick the member, then, once the
// organization roles of their groups are read, their permissions here by
// area and the access each comes from.
PanelBody {
    id: panel

    property string memberId
    readonly property var member: Session.accessDirectory.members.find(function (row) { return row.id === panel.memberId }) ?? null
    readonly property var answer: panel.memberId === "" || Session.accessGrants.busy ? ({})
                                                                                      : Session.accessGrants.explain(panel.memberId)
    readonly property string needle: search.text.trim().toLowerCase()

    title: qsTr("Check access")
    subtitle: panel.step === "" ? Messages.placeName(Session.accessGrants.kind, Session.accessGrants.name, "")
                                : panel.member?.label ?? ""
    initialFocus: search
    objectName: "checkAccessPanel"

    Field {
        id: search
        objectName: "checkAccessSearch"
        visible: panel.step === ""
        placeholderText: qsTr("Search people")
    }
    Repeater {
        model: panel.step === "" ? Session.accessDirectory.members.filter(function (row) {
            return panel.needle === "" || row.label.toLowerCase().includes(panel.needle)
        }) : []
        delegate: NavigationRow {
            id: person
            required property var modelData
            objectName: "checkAccess_" + person.modelData.id
            touch: panel.narrow
            text: person.modelData.label
            icon: "user"
            onActivated: {
                panel.memberId = person.modelData.id
                Session.accessGrants.check(person.modelData.id)
                panel.step = "result"
            }
            Keys.onDownPressed: person.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
            Keys.onUpPressed: person.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
        }
    }
    ColumnLayout {
        visible: panel.step === "result"
        Layout.fillWidth: true
        spacing: Theme.gapS
        Label {
            visible: Session.accessGrants.busy
            text: qsTr("Working…")
        }
        Label {
            objectName: "checkAccessNone"
            visible: !Session.accessGrants.busy && (panel.answer.actions ?? []).length === 0
            text: qsTr("No access here.")
        }
        Caption {
            visible: (panel.answer.actions ?? []).length > 0
            Layout.fillWidth: true
            text: qsTr("Can")
        }
        Repeater {
            model: Messages.permissionGroups(Messages.actionRows(panel.answer.actions ?? []))
            delegate: Label {
                id: area
                required property var modelData
                objectName: "checkAccessArea_" + area.modelData.heading
                text: area.modelData.heading + ": "
                      + area.modelData.actions.map(function (action) { return Messages.actionLabel(action) }).join(", ")
            }
        }
        Caption {
            visible: (panel.answer.reasons ?? []).length > 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.gapS
            text: qsTr("Why")
        }
        Repeater {
            model: panel.answer.reasons ?? []
            delegate: Label {
                id: reason
                required property var modelData
                required property int index
                objectName: "checkAccessReason_" + reason.index
                text: Messages.accessReason(reason.modelData)
            }
        }
    }
}
