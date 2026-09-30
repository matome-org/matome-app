pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome
import "Commands.js" as Commands

// A popup of commands from Session.commandList in groups: what acts on the
// item it opened on first, then what acts around it. Each group is
// `{title, ids}`; a titled group shows its title, and every group after the
// first sits under a hairline. Unusable commands are left out, and so is a
// group left empty. Arrows move between commands only, Enter or Space runs,
// Esc closes, and focus goes back where it came from.
C.Popup {
    id: menu

    property var commands: []
    property var groups: []
    property Item returnFocus: null
    property bool touch: false
    readonly property int rowHeight: menu.touch ? Theme.rowTouch : Theme.controlM
    readonly property int captionHeight: Theme.controlS
    readonly property int dividerHeight: Theme.gapS + 1

    // Commands to show, each group opened by a heading row: `{caption}` with
    // its title, empty for a bare divider, absent before an untitled first group.
    readonly property var shown: {
        const rows = []
        for (const group of menu.groups) {
            const usable = group.ids.map(function (id) { return Commands.find(menu.commands, id) })
                                    .filter(function (cmd) { return cmd.usable })
            if (usable.length === 0)
                continue
            if (rows.length > 0 || (group.title ?? "") !== "")
                rows.push({ caption: group.title ?? "", divider: rows.length > 0 })
            for (const cmd of usable)
                rows.push(cmd)
        }
        return rows
    }
    readonly property real rowsHeight: menu.shown.reduce(function (sum, row) {
        return sum + menu.span(row)
    }, 0)
    readonly property real listHeight: Math.min(menu.rowsHeight,
                                               Math.max(0, menu.parent.height - 2 * menu.margins
                                                        - menu.topPadding - menu.bottomPadding))

    signal chosen(string id)

    // The height of one row of `shown`.
    function span(row) {
        return row.caption === undefined ? menu.rowHeight
             : row.caption === "" ? menu.dividerHeight
             : menu.captionHeight + (row.divider ? menu.dividerHeight : 0)
    }

    // Opens at (x, y) in `item`'s coordinates, or above that point when it
    // would not fit below; Esc or a pick gives focus to `returnTo`. Nothing
    // opens when none of the commands applies.
    function show(wanted, item, x, y, returnTo) {
        menu.groups = wanted
        if (menu.shown.length === 0)
            return
        const at = menu.parent.mapFromItem(item, x, y)
        const height = menu.listHeight + menu.topPadding + menu.bottomPadding
        menu.returnFocus = returnTo
        list.currentIndex = -1
        list.moveCursor(0)
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
        selectable: function (index) { return menu.shown[index]?.caption === undefined }
        C.ScrollBar.vertical: ThinScrollBar {}
        model: menu.shown
        Accessible.role: Accessible.PopupMenu
        Accessible.name: qsTr("Actions")
        Keys.onEscapePressed: menu.dismiss()

        delegate: Item {
            id: item
            required property var modelData
            required property int index
            readonly property bool heading: item.modelData.caption !== undefined

            objectName: item.heading ? "menuHeading" : "menu_" + item.modelData.id
            width: list.width
            // The row a reader focuses: it speaks for the command it holds.
            Accessible.role: item.heading ? Accessible.Heading : Accessible.MenuItem
            Accessible.name: item.heading ? item.modelData.caption : item.modelData.title
            Accessible.checkable: !item.heading && row.Accessible.checkable
            Accessible.checked: !item.heading && row.Accessible.checked
            height: menu.span(item.modelData)
            // The cursor's row holds focus; Enter and Space run its command.
            Keys.onReturnPressed: if (!item.heading) menu.pick(item.modelData.id)
            Keys.onEnterPressed: if (!item.heading) menu.pick(item.modelData.id)
            Keys.onSpacePressed: if (!item.heading) menu.pick(item.modelData.id)

            Rectangle {
                visible: item.heading && item.modelData.divider
                x: Theme.gapS
                width: parent.width - 2 * Theme.gapS
                y: Theme.gapS / 2
                height: 1
                color: Theme.border
            }
            Caption {
                visible: item.heading && item.modelData.caption !== ""
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.gapS
                anchors.rightMargin: Theme.gapS
                height: menu.captionHeight
                verticalAlignment: Text.AlignVCenter
                text: item.heading ? item.modelData.caption : ""
            }
            CommandRow {
                id: row
                visible: !item.heading
                anchors.fill: parent
                touch: menu.touch
                pointerFocus: list
                command: item.heading ? ({ id: "", title: "", icon: "", shortcut: "", usable: false }) : item.modelData
                cursor: list.currentIndex === item.index
                onActivated: menu.pick(item.modelData.id)
            }
        }
    }
}
