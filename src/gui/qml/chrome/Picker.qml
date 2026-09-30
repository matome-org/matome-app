pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome

// A drop-down choice in the app's surface, border, and focus line. It
// selects `value`, when set, once its model is in and again when either
// changes.
C.ComboBox {
    id: picker

    property var value

    function sync() {
        if (picker.value !== undefined)
            picker.currentIndex = picker.indexOfValue(picker.value)
    }

    valueRole: "value"
    textRole: "label"
    Component.onCompleted: picker.sync()
    onValueChanged: picker.sync()
    onModelChanged: Qt.callLater(picker.sync)

    implicitHeight: Theme.controlL
    implicitWidth: Theme.column
    font: Theme.body
    palette.text: Theme.textPrimary
    palette.buttonText: Theme.textPrimary
    palette.base: Theme.surface
    palette.button: Theme.surface
    palette.window: Theme.surface
    palette.highlight: Theme.accentSoft
    palette.highlightedText: Theme.textPrimary
    palette.light: Theme.accentSoft
    palette.midlight: Theme.subtleFillStrong

    background: Rectangle {
        color: Theme.surface
        radius: Theme.rounding
        border.color: picker.activeFocus ? Theme.accentLine : Theme.border
    }
}
