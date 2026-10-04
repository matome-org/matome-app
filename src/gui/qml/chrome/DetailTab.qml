pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// One tab of a DetailPage: what it shows (its children: read-only facts on
// Details, else one table), the commands that act on its selected rows
// (`commands`), and the commands it adds to the item's own
// (`pageCommands`). The page moves both rows into its command bar, and
// shows `commands` only while the tab shows.
ColumnLayout {
    id: tab

    required property string view
    required property string title
    // Set by the page: whether the tab shows, and whether commands show
    // only their icons, their names as tips.
    property bool shown: false
    property bool compact: false
    property alias commands: tabRow.data
    property alias pageCommands: pageRow.data
    readonly property alias commandRow: tabRow
    readonly property alias pageCommandRow: pageRow

    visible: tab.shown
    Layout.fillWidth: true
    spacing: Theme.gapS

    RowLayout {
        id: tabRow
        visible: tab.shown
        spacing: Theme.gapXs
    }
    RowLayout {
        id: pageRow
        spacing: Theme.gapXs
    }
}
