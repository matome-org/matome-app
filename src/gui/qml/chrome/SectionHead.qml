pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A section's heading with its command bar on the same line, over a
// hairline. The bar's buttons are this item's children.
Item {
    id: head

    property string title
    default property alias commands: bar.data

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Theme.gapM + 1

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.gapL
        Text {
            Layout.fillWidth: true
            text: head.title
            font: Theme.heading
            color: Theme.textPrimary
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
        }
        CommandBar {
            id: bar
            Accessible.role: Accessible.ToolBar
            Accessible.name: head.title
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
