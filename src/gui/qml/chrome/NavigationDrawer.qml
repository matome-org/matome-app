pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome

// A narrow screen's navigation column, slid in from the left over a scrim.
// `navigation` is loaded only while it is open.
C.Drawer {
    id: drawer

    property Component navigation

    width: Math.min(Theme.column + 2 * Theme.gapM, drawer.parent.width - Theme.gapXl)
    height: drawer.parent.height
    edge: Qt.LeftEdge
    modal: true
    focus: true
    padding: 0
    background: Rectangle { color: Theme.surface }
    C.Overlay.modal: Rectangle {
        color: Theme.dark ? Theme.fill(Theme.background, 0.66) : Theme.fill(Theme.textPrimary, 0.32)
    }
    contentItem: Loader {
        active: drawer.visible
        sourceComponent: drawer.navigation
    }
}
