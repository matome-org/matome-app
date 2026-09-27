pragma ComponentBehavior: Bound

import QtQuick

// A tap handler that leaves presses on an open popup to the popup. Qt shows
// a press on a popup (a menu row) to every pointer handler beneath it too,
// so without this a control under an open menu would take the menu's click.
// Listen to `hit`, `doubleHit`, and `held` rather than the raw signals.
TapHandler {
    id: tap

    // The window's popup layer (C.Overlay.overlay of the item this sits in).
    required property Item popups
    // Whether the press under way landed on a popup its item is not part of.
    property bool popupPress: false

    signal hit(point position, int button, bool touch)
    signal doubleHit(int button)
    signal held(point position)

    function onPopup(position) {
        const item = tap.parent as Item
        if (!item || !tap.popups || !tap.popups.visible)
            return false
        const at = item.mapToItem(tap.popups, position.x, position.y)
        const popup = tap.popups.childAt(at.x, at.y)
        for (let each = item; each !== null; each = each.parent) {
            if (each === popup)
                return false
        }
        return popup !== null
    }

    // Touch reports Qt.NoButton. Do not require LeftButton: that is what
    // left Android taps dead while desktop keyboard e2e still passed.
    acceptedButtons: Qt.AllButtons
    onPressedChanged: if (tap.pressed)
        tap.popupPress = tap.onPopup(tap.point.position)
    onTapped: function (eventPoint, button) {
        if (!tap.popupPress)
            tap.hit(eventPoint.position, button, eventPoint.device.type === PointerDevice.TouchScreen)
    }
    onDoubleTapped: function (eventPoint, button) {
        if (!tap.popupPress)
            tap.doubleHit(button)
    }
    onLongPressed: if (!tap.popupPress)
        tap.held(tap.point.position)
}
