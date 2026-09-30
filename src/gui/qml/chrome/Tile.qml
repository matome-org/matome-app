pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A selectable card in a TileGrid: its children stack in a padded column.
// A click, tap, Enter, or Space selects it; the arrows move to the tile
// before or after it.
FocusableControl {
    id: tile

    property bool selected: false
    default property alias body: column.data

    signal chosen()

    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitHeight: column.implicitHeight + 2 * Theme.gapM
    color: tile.selected ? Theme.accentSoft : Theme.surface
    hoverColor: tile.selected ? Theme.accentSoft : Theme.subtleFill
    borderColor: tile.selected ? Theme.accentLine : Theme.border
    handCursor: true
    Accessible.role: Accessible.ListItem
    Accessible.selectable: true
    Accessible.selected: tile.selected

    onActivated: tile.chosen()
    Keys.onRightPressed: tile.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
    Keys.onDownPressed: tile.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
    Keys.onLeftPressed: tile.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
    Keys.onUpPressed: tile.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.gapM
        spacing: Theme.gapS
    }
}
