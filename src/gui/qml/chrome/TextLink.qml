pragma ComponentBehavior: Bound

import QtQuick
import matome

// A quiet action: muted, letter-spaced words (and an optional icon) that
// ease to text colour under the pointer, like the landing's bar tools. A
// `checkable` link is one of a group of choices; the chosen one is gold.
FocusableControl {
    id: link

    property string text
    property string icon
    property bool checkable: false
    property bool checked: false

    readonly property color ink: link.checked
                                 ? Theme.accentText
                                 : Qt.tint(Theme.textMuted, Theme.fill(Theme.textPrimary, link.lit))

    implicitWidth: content.implicitWidth + 2 * Theme.gapS
    implicitHeight: Theme.controlM
    hoverColor: "transparent"
    Accessible.role: Accessible.Button
    Accessible.name: link.text
    Accessible.checkable: link.checkable
    Accessible.checked: link.checked

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.gapS

        Icon {
            visible: link.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: link.icon
            color: link.ink
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: link.text
            color: link.ink
            font: Theme.link
        }
    }
}
