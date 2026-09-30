pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A screen's head over a hairline: the navigation button when narrow, the
// way back, the gold caption over the title, then refresh. Buttons show
// their label only when there is room; each names itself in a tooltip.
Rectangle {
    id: head

    property bool narrow: false
    property string caption
    property string title
    property string backText
    property bool refreshUsable: true
    property string refreshKey
    property alias navigationName: navigation.objectName
    property alias backName: back.objectName
    property alias refreshName: refresh.objectName
    readonly property alias navigationButton: navigation
    readonly property alias backButton: back

    signal navigationRequested()
    signal backRequested()
    signal refreshRequested()

    implicitHeight: row.implicitHeight + 2 * Theme.gapM + 1
    color: Theme.background

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.gapM
        spacing: Theme.gapM
        ActionButton {
            id: navigation
            visible: head.narrow
            text: qsTr("Navigation")
            icon: "menu"
            showLabel: false
            tip: text
            onActivated: head.navigationRequested()
        }
        ActionButton {
            id: back
            text: head.backText
            icon: "back"
            showLabel: !head.narrow
            tip: text
            key: "Esc"
            onActivated: head.backRequested()
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.gapXs
            Caption {
                Layout.fillWidth: true
                text: head.caption
                color: Theme.accentText
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: head.title
                color: Theme.textPrimary
                font: Theme.title
                elide: Text.ElideRight
                Accessible.role: Accessible.Heading
            }
        }
        ActionButton {
            id: refresh
            text: qsTr("Refresh")
            icon: "refresh"
            showLabel: false
            tip: text
            key: head.refreshKey
            usable: head.refreshUsable
            onActivated: head.refreshRequested()
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.border
    }
}
