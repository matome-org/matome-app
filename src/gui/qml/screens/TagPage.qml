pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"

// A tag's page (`tagId`): its own commands open the side panels that
// rename it, restrict it or stop restricting it, or archive it; its tabs
// are whether it restricts the documents that carry it, and who may see
// them, its Access tab (`panelRequested`).
DetailPage {
    id: page

    required property string tagId
    readonly property var tag: Session.accessDirectory.tags.find(function (row) { return row.id === page.tagId }) ?? null
    readonly property bool restricted: page.tag?.access_controlled === true
    readonly property bool busy: Session.accessDirectory.busy
    property alias view: access

    signal panelRequested(string kind, Item from)

    objectName: "tagPage"
    name: "tag"
    backText: qsTr("Tags")
    title: page.tag?.name ?? ""
    subject: page.tagId

    commands: [
        ActionButton {
            id: edit
            objectName: "editTagButton"
            text: qsTr("Edit")
            icon: "rename"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && updating.allowed
            reason: updating.reason
            onActivated: page.panelRequested("editTag", edit)
        },
        ActionButton {
            id: restrict
            objectName: "restrictTagButton"
            text: page.restricted ? qsTr("Stop restricting") : qsTr("Restrict")
            icon: "access"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && page.tag !== null && updating.allowed
            reason: updating.reason
            onActivated: page.panelRequested("restrictTag", restrict)
        },
        ActionButton {
            id: archive
            objectName: "archiveTagButton"
            text: qsTr("Archive")
            icon: "trash"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && page.tag !== null && archiving.allowed
            reason: archiving.reason
            onActivated: page.panelRequested("archiveTag", archive)
            Gate { id: updating; action: "tag.update" }
            Gate { id: archiving; action: "tag.archive" }
        }
    ]

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: [{ name: "tagName", label: qsTr("Name"), value: page.tag?.name ?? "" },
                    { name: "tagControl", label: qsTr("Documents"),
                      value: page.tag === null ? "" : page.restricted ? qsTr("Restricted") : qsTr("Open") }]
        }
    }

    AccessView {
        id: access
        touch: page.narrow
        onPanelRequested: function (kind, from) { page.panelRequested(kind, from) }
    }
}
