pragma ComponentBehavior: Bound

import QtQuick
import matome

// One key as a quiet chip: a hairline box around muted small type. Menus,
// the sheet, tooltips, and the keymap all spell keys with it.
Rectangle {
    id: chip

    property alias text: label.text

    implicitWidth: Math.max(chip.implicitHeight, label.implicitWidth + Theme.gapS)
    implicitHeight: label.implicitHeight + Theme.gapXs
    radius: Math.min(Theme.rounding, chip.height / 2)
    color: "transparent"
    border.width: 1
    border.color: Theme.border

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.textMuted
        font: Theme.caption
    }
}
