pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body for one tag's name (`tagId`), or a new tag when
// empty: its name and whether it restricts the documents that carry it,
// saved by Save. `created` names a tag just made.
PanelBody {
    id: editor

    property string tagId
    property bool sent: false
    property bool restricted: false
    readonly property var tag: Session.accessDirectory.tags.find(function (row) { return row.id === editor.tagId }) ?? null
    readonly property bool creating: editor.tagId === ""
    readonly property string name: nameField.text.trim()
    readonly property bool edited: editor.name !== "" && (editor.creating || editor.name !== editor.tag?.name)

    signal created(string id)

    title: editor.creating ? qsTr("New tag") : qsTr("Edit tag")
    subtitle: editor.creating ? "" : editor.tag?.name ?? ""
    saveText: editor.creating ? qsTr("Create tag") : qsTr("Save")
    saveUsable: !Session.accessDirectory.busy && editor.edited
    initialFocus: nameField
    objectName: "tagEditor"

    onSaveRequested: {
        editor.sent = true
        if (editor.creating)
            Session.accessDirectory.createTag(editor.name, editor.restricted)
        else
            Session.accessDirectory.updateTag(editor.tagId, editor.name, editor.tag?.access_controlled === true)
    }
    Component.onCompleted: nameField.text = editor.tag?.name ?? ""

    Connections {
        target: Session.accessDirectory
        function onSaved(notice, id) {
            if (!editor.sent)
                return
            editor.sent = false
            if (notice === "tag_created" && id !== "") editor.created(id)
            else editor.finished()
        }
    }

    Label {
        objectName: "tagEditorError"
        visible: Session.accessDirectory.errorCode !== ""
        text: Messages.accessFailure(Session.accessDirectory.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Label { text: qsTr("Name") }
    Field {
        id: nameField
        objectName: "tagNameField"
        placeholderText: qsTr("Name")
        maximumLength: 80
        onAccepted: if (editor.saveUsable) editor.saveRequested()
    }
    NavigationRow {
        objectName: "tagRestrictedSwitch"
        visible: editor.creating
        Layout.topMargin: Theme.gapS
        touch: editor.narrow
        text: qsTr("Restrict tagged documents")
        detail: qsTr("Only people with access to the tag see documents that carry it.")
        icon: editor.restricted ? "checkbox-checked" : "checkbox"
        checkable: true
        selected: editor.restricted
        usable: !Session.accessDirectory.busy
        onActivated: editor.restricted = !editor.restricted
    }
}
