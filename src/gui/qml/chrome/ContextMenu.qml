pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome
import "Commands.js" as Commands

// A popup of commands from Session.commandList. Callers pass the ids that fit
// where it opened; unusable ones are left out. Arrows move, Enter or Space
// runs, Esc closes, and focus goes back where it came from.
C.Popup {
    id: menu

    property var commands: []
    property var ids: []
    property Item returnFocus: null
    property bool touch: false
    readonly property int rowHeight: menu.touch ? Theme.rowTouch : Theme.controlM
    readonly property real listHeight: Math.min(menu.shown.length * menu.rowHeight,
                                               Math.max(0, menu.parent.height - 2 * menu.margins
                                                        - menu.topPadding - menu.bottomPadding))

    readonly property var shown: menu.ids.map(function (id) {
        return Commands.find(menu.commands, id)
    }).filter(function (cmd) { return cmd.usable })

    signal chosen(string id)

    // Opens at (x, y) in `item`'s coordinates, or above that point when it
    // would not fit below; Esc or a pick gives focus to `returnTo`. Nothing
    // opens when none of the commands applies.
    function show(wanted, item, x, y, returnTo) {
        menu.ids = wanted
        if (menu.shown.length === 0)
            return
        const at = menu.parent.mapFromItem(item, x, y)
        const height = menu.listHeight + menu.topPadding + menu.bottomPadding
        menu.returnFocus = returnTo
        list.currentIndex = 0
        menu.x = at.x
        menu.y = at.y + height + menu.margins > menu.parent.height ? at.y - height : at.y
        menu.open()
    }

    function dismiss() {
        menu.close()
        menu.returnFocus.forceActiveFocus()
    }

    function pick(id) {
        menu.dismiss()
        menu.chosen(id)
    }

    padding: Theme.gapXs
    margins: Theme.gapS
    focus: true
    closePolicy: C.Popup.CloseOnPressOutside

    onOpened: list.forceActiveFocus()

    background: Rectangle {
        radius: Theme.rounding
        color: Theme.surface
        border.color: Theme.border
    }

    contentItem: CursorList {
        id: list
        objectName: "contextMenuList"
        implicitWidth: Theme.column
        implicitHeight: menu.listHeight
        rowHeight: menu.rowHeight
        interactive: contentHeight > height
        clip: true
        C.ScrollBar.vertical: ThinScrollBar {}
        model: menu.shown
        Accessible.role: Accessible.PopupMenu
        Accessible.name: qsTr("Actions")
        Keys.onEscapePressed: menu.dismiss()

        delegate: CommandRow {
            id: item
            required property var modelData
            required property int index

            objectName: "menu_" + item.modelData.id
            width: list.width
            height: menu.rowHeight
            touch: menu.touch
            pointerFocus: list
            command: item.modelData
            cursor: list.currentIndex === item.index
            onActivated: menu.pick(item.modelData.id)
        }
    }
}
