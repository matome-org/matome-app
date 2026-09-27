pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// Every usable command, filtered as you type: arrows move, Enter runs.
Overlay {
    id: sheet
    objectName: "commandSheet"

    property var commands: []
    signal chosen(string id)

    readonly property var shown: {
        const usable = sheet.commands.filter(function (cmd) { return cmd.usable })
        const needle = query.text.trim().toLowerCase()
        if (needle.length === 0)
            return usable
        return usable.filter(function (cmd) {
            return String(cmd.title).toLowerCase().indexOf(needle) >= 0
                || String(cmd.id).toLowerCase().indexOf(needle) >= 0
        })
    }

    function choose() {
        if (list.currentIndex >= 0 && list.currentIndex < sheet.shown.length)
            sheet.chosen(sheet.shown[list.currentIndex].id)
    }

    eyebrow: qsTr("Commands")
    high: true
    onVisibleChanged: if (sheet.visible)
        query.text = ""

    Field {
        id: query
        objectName: "sheetQuery"
        focus: true
        line: true
        horizontalAlignment: TextInput.AlignLeft
        font: Theme.bodyLarge
        placeholderText: qsTr("Run a command")
        Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
        Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
        Keys.onReturnPressed: sheet.choose()
        Keys.onEnterPressed: sheet.choose()
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: list.contentHeight
        clip: true
        model: sheet.shown
        currentIndex: 0
        onModelChanged: list.currentIndex = 0

        delegate: CommandRow {
            id: entry
            required property var modelData
            required property int index
            width: list.width
            height: Theme.controlM
            command: entry.modelData
            cursor: list.currentIndex === entry.index
            onActivated: sheet.chosen(entry.modelData.id)
        }
    }
}
