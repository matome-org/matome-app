pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The access page of the folder or document `Session.accessGrants` has
// open, opening on its Access tab: its own commands, which its Access tab
// adds, change how it inherits or check someone's access; its tabs are how
// it inherits, and who has access, whose commands open the side panels that
// change it (`panelRequested`); an inherited row's place opens through
// `sourceRequested`.
DetailPage {
    id: page

    property alias view: access
    readonly property var summary: Session.accessGrants.summary

    signal panelRequested(string kind, Item from)
    signal sourceRequested(string kind, string id, string name)

    objectName: "placePage"
    name: "place"
    backText: qsTr("Back")
    start: "access"
    subject: Session.accessGrants.kind + ":" + Session.accessGrants.targetId

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: [{ name: "placeInheritance", label: qsTr("Inheritance"), value: Messages.inheritance(page.summary) },
                    { name: "placeOpen", label: qsTr("Members"),
                      value: page.summary.openToMembers === true ? qsTr("Every member except guests reads it") : "" }]
        }
    }

    AccessView {
        id: access
        touch: page.narrow
        onPanelRequested: function (kind, from) { page.panelRequested(kind, from) }
        onSourceRequested: function (kind, id, name) { page.sourceRequested(kind, id, name) }
    }
}
