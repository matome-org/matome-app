pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A sheet over the window: a scrim that closes on a click and one surface
// panel, headed, when set, by the landing's gold eyebrow and a serif title.
// Esc closes it, and so does any key when `anyKeyCloses`. The panel sits
// near the top when `high` (it grows downward as it fills), else centred.
Rectangle {
    id: overlay

    property string eyebrow
    property string title
    property bool high: false
    property bool anyKeyCloses: false
    default property alias content: column.data

    function open() {
        overlay.visible = true
        scope.forceActiveFocus()
    }

    function close() {
        overlay.visible = false
    }

    visible: false
    z: 90
    color: Theme.fill(Theme.background, 0.72)
    Accessible.ignored: true

    MouseArea {
        anchors.fill: parent
        onClicked: overlay.close()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: overlay.visible

        Keys.onPressed: function (event) {
            if (overlay.anyKeyCloses || event.key === Qt.Key_Escape) {
                overlay.close()
                event.accepted = true
            }
        }

        Rectangle {
            width: Math.min(Theme.measure + 2 * Theme.gapXxl, parent.width - 2 * Theme.gapXl)
            height: Math.min(column.implicitHeight + 2 * Theme.gapL, parent.height - 2 * Theme.gapXxl)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: overlay.high ? undefined : parent.verticalCenter
            y: 2 * Theme.gapXxl
            radius: Theme.rounding
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
            Accessible.role: Accessible.Dialog
            Accessible.name: overlay.title !== "" ? overlay.title : overlay.eyebrow

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.gapL
                spacing: Theme.gapS

                Caption {
                    visible: overlay.eyebrow !== ""
                    Layout.fillWidth: true
                    text: overlay.eyebrow
                    color: Theme.accentText
                }
                Text {
                    objectName: "overlayTitle"
                    visible: overlay.title !== ""
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.gapS
                    text: overlay.title
                    color: Theme.textPrimary
                    font: Theme.title
                    Accessible.role: Accessible.Heading
                    Accessible.name: overlay.title
                }
            }
        }
    }
}
