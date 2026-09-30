pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A surface panel on the border: its children stack in a padded column.
Rectangle {
    id: card

    default property alias content: column.data

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 2 * Theme.gapM
    color: Theme.surface
    border.color: Theme.border
    radius: Theme.rounding

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Theme.gapM
        spacing: Theme.gapS
    }
}
