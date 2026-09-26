pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome

// The one button: optional icon, optional label. A `primary` button is the
// landing's gold pill (the desktop's rounding on Omarchy); every other button
// is a quiet ghost whose ink brightens under the pointer. Icon-only buttons
// name themselves for screen readers and show `tip` (and its `key`) on hover
// or keyboard focus.
FocusableControl {
    id: button

    property string text
    property string icon
    property bool primary: false
    property bool showLabel: true
    property string tip
    property string key
    property font labelFont: button.primary ? Theme.button : Theme.body
    property real horizontalPadding: Theme.gapM

    readonly property color ink: button.primary
                                 ? Theme.onAccent
                                 : Qt.tint(Theme.textSecondary, Theme.fill(Theme.textPrimary, button.lit))

    implicitHeight: Theme.controlM
    implicitWidth: button.showLabel ? content.implicitWidth + 2 * button.horizontalPadding
                                    : button.implicitHeight
    radius: Theme.pill ? button.height / 2 : Theme.rounding
    color: button.primary ? Theme.accent : "transparent"
    hoverColor: button.primary ? Theme.accentDark : Theme.subtleFill
    opacity: button.usable ? 1 : 0.4
    scale: button.pressed ? 0.98 : 1

    Behavior on scale { Ease {} }

    Accessible.role: Accessible.Button
    Accessible.name: button.text

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.gapS

        Icon {
            visible: button.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: button.icon
            color: button.ink
        }
        Text {
            visible: button.showLabel && button.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: button.text
            color: button.ink
            font: button.labelFont
        }
    }

    C.ToolTip {
        parent: button
        visible: button.tip !== "" && (button.hovered || (button.activeFocus && Theme.focusVisible))
        delay: button.hovered ? 500 : 0
        y: button.height + Theme.gapXs
        padding: Theme.gapS
        contentItem: RowLayout {
            objectName: "toolTip"
            spacing: Theme.gapS

            Text {
                text: button.tip
                color: Theme.textPrimary
                font: Theme.caption
            }
            KeyChip {
                visible: button.key !== ""
                text: button.key
            }
        }
        background: Rectangle {
            radius: Theme.rounding
            color: Theme.surface
            border.color: Theme.border
        }
    }
}
