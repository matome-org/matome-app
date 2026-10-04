pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// Picks one place to grant on: a space, or, with `tags`, a tag. `place` is
// the one picked, `{kind, spaceId, id, name}`, null before. A click, tap,
// Enter, or Space picks one; the arrows move between them.
ColumnLayout {
    id: picker

    property bool tags: false
    property var place: null
    property bool touch: false
    property bool usable: true

    function pick(kind, spaceId, id, name) {
        picker.place = { kind: kind, spaceId: spaceId, id: id, name: name }
    }

    component Choice: NavigationRow {
        id: choice
        property string kind
        property string choiceId
        readonly property bool picked: picker.place !== null && picker.place.kind === choice.kind && picker.place.id === choice.choiceId
        objectName: "pickPlace_" + choice.kind + ":" + choice.choiceId
        touch: picker.touch
        icon: choice.picked ? "checkbox-checked" : "checkbox"
        checkable: true
        selected: choice.picked
        usable: picker.usable
        Keys.onDownPressed: choice.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
        Keys.onUpPressed: choice.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
    }

    Layout.fillWidth: true
    spacing: Theme.gapXs

    Caption { Layout.fillWidth: true; text: qsTr("Spaces") }
    Repeater {
        model: Session.spaces
        delegate: Choice {
            id: space
            required property string spaceId
            required property string name
            kind: "space"
            choiceId: space.spaceId
            text: space.name
            onActivated: picker.pick("space", space.spaceId, space.spaceId, space.name)
        }
    }
    Caption {
        visible: picker.tags && Session.accessDirectory.tags.length > 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.gapS
        text: qsTr("Tags")
    }
    Repeater {
        model: picker.tags ? Session.accessDirectory.tags : []
        delegate: Choice {
            id: tag
            required property var modelData
            kind: "tag"
            choiceId: tag.modelData.id
            text: tag.modelData.name
            onActivated: picker.pick("tag", "", tag.modelData.id, tag.modelData.name)
        }
    }
}
