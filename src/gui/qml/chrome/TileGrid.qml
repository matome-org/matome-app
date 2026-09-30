pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// Cards in as many equal columns as the width holds, each at least
// `tileWidth` wide; the cards of a row share its height.
GridLayout {
    id: grid

    property real tileWidth: Theme.column + Theme.gapXxl

    Layout.fillWidth: true
    columns: Math.max(1, Math.floor((grid.width + grid.columnSpacing) / (grid.tileWidth + grid.columnSpacing)))
    columnSpacing: Theme.gapM
    rowSpacing: Theme.gapM
    uniformCellWidths: true
}
