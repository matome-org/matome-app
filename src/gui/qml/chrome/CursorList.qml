pragma ComponentBehavior: Bound

import QtQuick
import matome

// A list that is one tab stop with a keyboard cursor: Up/Down, Home/End, and
// PageUp/PageDown move it, the view keeps it in sight, and the row under it
// holds focus while the list does. Keys with Ctrl, Alt, or Meta fall through
// to the window. Enter and Space are the rows' own (FocusableControl).
ListView {
    id: view

    property real rowHeight: Theme.rowDense

    // The cursor moved by key or by `moveCursor`.
    signal moved()
    // Menu or Shift+F10 on the list or the row under the cursor.
    signal menuRequested()

    function moveCursor(index) {
        if (view.count === 0)
            return
        view.currentIndex = Math.max(0, Math.min(view.count - 1, index))
        view.moved()
    }

    // A replaced row leaves focus on its dying delegate; hand it to the new
    // one once focus has settled. Focus inside the row (an editor) stays.
    function keepFocus() {
        if (!view.activeFocus || !view.currentItem)
            return
        for (let item = view.Window.activeFocusItem; item && item !== view; item = item.parent) {
            if (item === view.currentItem)
                return
        }
        view.currentItem.forceActiveFocus()
    }

    keyNavigationEnabled: false
    highlightMoveDuration: 0
    boundsBehavior: Flickable.StopAtBounds

    onCurrentItemChanged: Qt.callLater(view.keepFocus)
    onActiveFocusChanged: Qt.callLater(view.keepFocus)
    onCurrentIndexChanged: if (view.currentIndex >= 0)
        view.positionViewAtIndex(view.currentIndex, ListView.Contain)

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Menu
            || (event.key === Qt.Key_F10 && event.modifiers === Qt.ShiftModifier)) {
            view.menuRequested()
            event.accepted = true
            return
        }
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        const page = Math.max(1, Math.floor(view.height / view.rowHeight) - 1)
        if (event.key === Qt.Key_Down)
            view.moveCursor(view.currentIndex + 1)
        else if (event.key === Qt.Key_Up)
            view.moveCursor(view.currentIndex - 1)
        else if (event.key === Qt.Key_Home)
            view.moveCursor(0)
        else if (event.key === Qt.Key_End)
            view.moveCursor(view.count - 1)
        else if (event.key === Qt.Key_PageDown)
            view.moveCursor(view.currentIndex + page)
        else if (event.key === Qt.Key_PageUp)
            view.moveCursor(view.currentIndex - page)
        else
            return
        event.accepted = true
    }
}
