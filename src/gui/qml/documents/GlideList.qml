pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome
import "../chrome"

// A list read top to bottom: the wheel, the arrows, PageUp and PageDown,
// and Space scroll a constant step and glide there; Home and End jump to
// either end; a drag scrolls it only on touch. A wheel across, or with
// Shift, goes to `sideways` first. `marked` is the row Next and
// Previous last brought into view (showIndex), -1 for none. The list's
// keys go through navigate(), which its owner calls from its own handler.
ListView {
    id: list

    property bool touch: false
    // One wheel notch, and one arrow press.
    property real step: Math.round(Theme.bodyLarge.pixelSize * 1.6 * 3)
    property real line: Math.round(Theme.bodyLarge.pixelSize * 1.6)
    property int marked: -1
    // Takes a scroll across by `delta` at the point (`x`, `y`) of the list;
    // true when something there scrolled.
    property var sideways: function (x, y, delta) { return false }

    function bounds() {
        const top = list.originY - list.topMargin
        return { top: top, bottom: Math.max(top, list.originY + list.contentHeight + list.bottomMargin - list.height) }
    }
    function scrollTo(target) {
        const range = list.bounds()
        const to = Math.max(range.top, Math.min(range.bottom, target))
        glide.stop()
        if (Theme.fast <= 0) {
            list.contentY = to
            return
        }
        glide.from = list.contentY
        glide.to = to
        glide.start()
    }
    function scrollBy(delta) {
        list.scrollTo((glide.running ? glide.to : list.contentY) + delta)
    }
    // Glides until row `index` sits a quarter down the list, and marks it.
    function showIndex(index) {
        if (index < 0 || index >= list.count)
            return
        glide.stop()
        const from = list.contentY
        list.positionViewAtIndex(index, ListView.Beginning)
        const target = list.contentY - list.height / 4
        list.contentY = from
        list.marked = index
        list.scrollTo(target)
    }
    // Scrolls for a navigation key; false for any other key.
    function navigate(event): bool {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false
        const page = Math.max(list.line, list.height - 2 * list.line)
        if (event.key === Qt.Key_Down) {
            list.scrollBy(list.line)
        } else if (event.key === Qt.Key_Up) {
            list.scrollBy(-list.line)
        } else if (event.key === Qt.Key_PageDown || (event.key === Qt.Key_Space && !(event.modifiers & Qt.ShiftModifier))) {
            list.scrollBy(page)
        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Space) {
            list.scrollBy(-page)
        } else if (event.key === Qt.Key_Home) {
            glide.stop()
            list.positionViewAtBeginning()
            list.contentY = list.bounds().top
        } else if (event.key === Qt.Key_End) {
            glide.stop()
            list.positionViewAtEnd()
            list.contentY = list.bounds().bottom
        } else {
            return false
        }
        return true
    }

    clip: true
    interactive: list.touch
    boundsBehavior: Flickable.StopAtBounds
    focus: true
    activeFocusOnTab: true
    onModelChanged: list.marked = -1
    C.ScrollBar.vertical: ThinScrollBar {}

    NumberAnimation {
        id: glide
        target: list
        property: "contentY"
        duration: Theme.fast
        easing.type: Easing.OutCubic
    }

    WheelHandler {
        id: wheel
        parent: list
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        target: null
        onWheel: function (event) {
            const shifted = (event.modifiers & Qt.ShiftModifier) && event.angleDelta.x === 0 && event.pixelDelta.x === 0
            const across = shifted ? (event.pixelDelta.y !== 0 ? -event.pixelDelta.y : -event.angleDelta.y / 120 * list.step)
                         : event.pixelDelta.x !== 0 ? -event.pixelDelta.x : -event.angleDelta.x / 120 * list.step
            const took = across !== 0 && list.sideways(wheel.point.position.x, wheel.point.position.y, across)
            if (took && shifted)
                return
            if (event.pixelDelta.y !== 0) {
                glide.stop()
                const range = list.bounds()
                list.contentY = Math.max(range.top, Math.min(range.bottom, list.contentY - event.pixelDelta.y))
            } else {
                list.scrollBy(-event.angleDelta.y / 120 * list.step)
            }
        }
    }

    Rectangle {
        parent: list
        anchors.fill: parent
        visible: list.activeFocus && Theme.focusVisible
        color: "transparent"
        radius: Theme.rounding
        border.color: Theme.accentLine
    }
}
