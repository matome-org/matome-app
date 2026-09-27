pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome

// A text field. Boxed by default; `line` is the landing's form field: one
// hairline underneath, text centred, gold easing in under focus, `failed`
// when invalid.
// The placeholder stays while the field is focused and empty, as on the web
// (Basic hides a centred one on focus).
C.TextField {
    id: field

    property color fill: Theme.surface
    property bool line: false
    property bool invalid: false

    readonly property color edge: field.invalid ? Theme.failed
                                : field.activeFocus ? Theme.accentLine : Theme.border
    // The focused line fades in over the resting one, so no colour eases
    // against the theme's own crossfade.
    property real lit: field.activeFocus && !field.invalid ? 1 : 0

    Behavior on lit { Ease {} }

    Layout.fillWidth: true
    implicitHeight: field.line ? Theme.controlXl : Theme.controlL
    leftPadding: field.line ? Theme.gapXs : Theme.gapM
    rightPadding: field.line ? Theme.gapXs : Theme.gapM
    horizontalAlignment: field.line ? TextInput.AlignHCenter : TextInput.AlignLeft
    font: field.line ? Theme.bodyLarge : Theme.body
    color: Theme.textPrimary
    placeholderTextColor: "transparent"
    selectionColor: Theme.accentSoft
    selectedTextColor: Theme.textPrimary
    activeFocusOnTab: true
    selectByMouse: true
    Accessible.name: field.placeholderText
    Accessible.role: Accessible.EditableText

    background: Rectangle {
        radius: field.line ? 0 : Theme.rounding
        color: field.line ? "transparent" : field.fill
        border.width: field.line ? 0 : 1
        border.color: field.edge

        Text {
            anchors.fill: parent
            leftPadding: field.leftPadding
            rightPadding: field.rightPadding
            visible: field.length === 0 && field.preeditText === ""
            text: field.placeholderText
            color: Theme.textMuted
            font: field.font
            horizontalAlignment: field.horizontalAlignment
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Rectangle {
            visible: field.line
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: field.invalid ? Theme.failed : Theme.border

            Rectangle {
                anchors.fill: parent
                color: Theme.accentLine
                opacity: field.lit
            }
        }
    }
}
