pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome

// Tab focus, activation, hover wash, and the one focus ring every control
// shares. The resting fill binds straight to Theme, so a mode switch walks
// it with everything else; only the hover wash eases, by opacity. Taps
// activate; a control that `tapSelects` reports the tap instead so lists can
// select on click and open on double click. Right click and long press ask
// for a context menu. A press on a popup over the control is the popup's.
Item {
    id: control

    property bool usable: true
    property bool tabFocusable: true
    property bool handCursor: true
    property bool tapSelects: false
    property bool tapEnabled: true
    property Item focusRingSource: control
    property Item pointerFocus: control
    property color color: "transparent"
    // Laid over `color` under the pointer; set it to `color` for no wash.
    property color hoverColor: Theme.subtleFill
    property color borderColor: "transparent"
    property real radius: Theme.rounding
    // How far the ring stands off the edge; rows in lists keep it on theirs.
    property real ringOffset: Theme.gapXs
    // How far the fill, the wash, and the ring stand in from the left and
    // right edges: rows span their list but draw clear of the panel's edge.
    property real inset: 0

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: tap.pressed
    // 0 at rest, 1 under the pointer, eased between: the wash and any ink
    // that brightens on hover follow it. Read it; do not set it.
    property real lit: control.hovered && control.usable ? 1 : 0
    // The window's popup layer, which a press may land on instead.
    readonly property Item popups: C.Overlay.overlay

    signal activated()
    signal clicked(bool touch)
    signal menuRequested(point position)

    default property alias content: contentLayer.data

    implicitWidth: Theme.controlM
    implicitHeight: Theme.controlM
    enabled: control.usable

    Accessible.focusable: control.tabFocusable
    activeFocusOnTab: control.tabFocusable

    onUsableChanged: if (!control.usable && control.activeFocus)
        nextItemInFocusChain(true).forceActiveFocus()

    Keys.onSpacePressed: function (event) {
        control.activated()
        event.accepted = true
    }
    Keys.onReturnPressed: function (event) {
        control.activated()
        event.accepted = true
    }
    Keys.onEnterPressed: function (event) {
        control.activated()
        event.accepted = true
    }

    Behavior on lit { Ease { duration: Theme.fast } }

    Rectangle {
        id: fill
        objectName: "fill"
        anchors.fill: parent
        anchors.leftMargin: control.inset
        anchors.rightMargin: control.inset
        z: -1
        radius: control.radius
        color: control.color
        border.width: control.borderColor.a > 0 ? 1 : 0
        border.color: control.borderColor

        Rectangle {
            anchors.fill: parent
            anchors.margins: fill.border.width
            radius: control.radius
            color: control.hoverColor
            opacity: control.lit
        }
    }

    Item {
        id: contentLayer
        anchors.fill: parent
    }

    // The landing's :focus-visible: one gold line, stood off the edge, only
    // while the keyboard drives.
    Rectangle {
        objectName: "focusRing"
        anchors.fill: parent
        anchors.margins: -control.ringOffset
        anchors.leftMargin: control.inset - control.ringOffset
        anchors.rightMargin: control.inset - control.ringOffset
        z: 2
        visible: Theme.focusVisible && control.focusRingSource.activeFocus
        radius: control.radius > 0 ? control.radius + control.ringOffset : 0
        color: "transparent"
        border.width: 1
        border.color: Theme.accentLine
    }

    HoverHandler {
        id: hover
        cursorShape: control.handCursor && control.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    Tap {
        id: tap
        enabled: control.tapEnabled
        popups: control.popups
        onHit: function (position, button, touch) {
            control.pointerFocus.forceActiveFocus()
            if (button === Qt.RightButton)
                control.menuRequested(position)
            else if (control.tapSelects)
                control.clicked(touch)
            else
                control.activated()
        }
        onDoubleHit: function (button) {
            if (control.tapSelects && button !== Qt.RightButton)
                control.activated()
        }
        onHeld: function (position) {
            control.pointerFocus.forceActiveFocus()
            control.menuRequested(position)
        }
    }
}
