pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "Commands.js" as Commands

// Every command that has a key, with its keys as chips. Any key closes it.
Overlay {
    id: keymap
    objectName: "keymapSheet"

    property var commands: []

    eyebrow: qsTr("Keyboard")
    title: qsTr("Keys")
    anyKeyCloses: true

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: list.contentHeight
        clip: true
        interactive: list.contentHeight > list.height
        model: keymap.commands.filter(function (cmd) { return cmd.shortcut !== "" })

        delegate: RowLayout {
            id: entry
            required property var modelData
            width: list.width
            height: Theme.controlS
            spacing: Theme.gapXs

            Text {
                Layout.fillWidth: true
                text: entry.modelData.title
                color: entry.modelData.usable ? Theme.textPrimary : Theme.textMuted
                font: Theme.body
                elide: Text.ElideRight
            }
            Repeater {
                model: Commands.keys(entry.modelData)
                delegate: KeyChip {
                    id: chip
                    required property string modelData
                    text: chip.modelData
                }
            }
        }
    }
}
