pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome

// A slim Theme-tinted scroll bar that shows while scrolling or hovered.
C.ScrollBar {
    id: bar

    padding: 2
    minimumSize: 0.08

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: width / 2
        color: Theme.fill(Theme.textPrimary, bar.pressed ? 0.45 : 0.28)
        opacity: bar.size < 1 && (bar.active || bar.hovered) ? 1 : 0

        Behavior on opacity { Ease { duration: Theme.fast } }
    }
}
