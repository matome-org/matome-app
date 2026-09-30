pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "Scroll.js" as Scroll

// A scrolling column no wider than `measure`. The control that takes focus
// inside it, and the text cursor of an editor in it, stay in sight.
Flickable {
    id: page

    property real measure: page.width
    property alias spacing: column.spacing
    default property alias content: column.data
    readonly property Item focused: page.Window.activeFocusItem
    readonly property TextEdit editor: page.focused as TextEdit

    clip: true
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    C.ScrollBar.vertical: ThinScrollBar {}

    onFocusedChanged: if (page.visible && page.focused)
        Scroll.reveal(page, page.focused, page.editor ? page.editor.cursorRectangle : null, Theme.gapS)

    Connections {
        target: page.editor
        function onCursorRectangleChanged() {
            Scroll.reveal(page, page.editor, page.editor.cursorRectangle, Theme.gapS)
        }
    }

    ColumnLayout {
        id: column
        width: Math.min(page.width - page.leftMargin - page.rightMargin, page.measure)
        spacing: Theme.gapM
    }
}
