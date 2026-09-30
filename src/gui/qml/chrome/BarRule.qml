pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A hairline between groups of buttons in a command bar.
Rectangle {
    Layout.preferredWidth: 1
    Layout.preferredHeight: Theme.iconM
    Layout.leftMargin: Theme.gapXs
    Layout.rightMargin: Theme.gapXs
    color: Theme.border
}
