pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// Read-only rows under a header of column titles; the page's command bar
// acts on the selected rows. The rows are one tab stop: the arrows,
// Home/End, and PageUp/PageDown move the cursor and select the row under
// it, and a click selects one row. With `multiSelect`, Shift extends the
// selection, Ctrl+Space, a Ctrl click, a right click, or a long press toggle
// a row, and Ctrl+A selects them all. Enter, Space, or a double click open
// the row under the cursor (`opened`), the default command. Cells elide;
// the page around the table scrolls.
ColumnLayout {
    id: table

    // What the rows are, for screen readers.
    property string label
    // `{title, share}` each: the column's title and its share of the width.
    property var columns: []
    // A list model or an array; each row is its item.
    property var model: []
    // The text of each cell of `row`, one per column.
    property var cells: function (row) { return [] }
    // What names `row` across reloads; its item is `prefix` and the key.
    property var keyOf: function (row) { return row.id }
    property string prefix
    property bool multiSelect: false
    property bool touch: false
    // Said in place of the rows while there are none.
    property string emptyText
    property var selectedKeys: []
    readonly property alias count: rows.count
    // Counts the rows built or changed, so what reads them reads again.
    property int revision: 0
    // The rows selected, in table order.
    readonly property var selectedRows: table.revision >= 0 ? table.rowsKeyed(table.selectedKeys) : []
    // The one row selected; null with none or several.
    readonly property var selectedRow: table.selectedRows.length === 1 ? table.selectedRows[0] : null
    readonly property real share: table.columns.reduce(function (sum, column) { return sum + column.share }, 0)
    // The row a range reaches from, whether the cursor moves to extend
    // the selection, and the key of the row under the cursor.
    property int anchor: 0
    property bool extending: false
    property string cursorKey

    signal opened(var row)

    // Puts focus on the rows and the cursor on the row keyed `key`, once
    // it is built; false while the table has no rows.
    function focusKey(key) {
        if (rows.count === 0)
            return false
        table.cursorKey = key
        rows.forceActiveFocus(Qt.TabFocusReason)
        table.reconcile()
        return true
    }

    function rowsKeyed(keys) {
        const found = []
        for (let at = 0; at < rows.count; ++at) {
            const row = rows.itemAtIndex(at) as TableRow
            if (row && keys.includes(row.key)) found.push(row.record)
        }
        return found
    }
    function keyAt(index) {
        return (rows.itemAtIndex(index) as TableRow)?.key ?? ""
    }
    // Puts the cursor on row `index`, where it stays across reloads.
    function point(index) {
        rows.currentIndex = index
        table.cursorKey = table.keyAt(index)
    }
    function selectOnly(index) {
        const key = table.keyAt(index)
        table.anchor = index
        table.selectedKeys = key === "" ? [] : [key]
    }
    function toggle(index) {
        const key = table.keyAt(index)
        table.anchor = index
        table.selectedKeys = table.selectedKeys.includes(key) ? table.selectedKeys.filter(function (each) { return each !== key })
                                                              : table.selectedKeys.concat([key])
    }
    function selectRange(index) {
        const keys = []
        for (let at = Math.min(table.anchor, index); at <= Math.max(table.anchor, index); ++at)
            keys.push(table.keyAt(at))
        table.selectedKeys = keys
    }
    function selectAll() {
        const keys = []
        for (let at = 0; at < rows.count; ++at)
            keys.push(table.keyAt(at))
        table.selectedKeys = keys
    }
    // Moves the cursor to `index`, the selection reaching from the anchor.
    function extendTo(index) {
        table.extending = true
        rows.moveCursor(index)
        table.extending = false
        table.selectRange(rows.currentIndex)
    }
    // Keeps the selection to rows still listed and the cursor on its row.
    function reconcile() {
        const keys = []
        for (let at = 0; at < rows.count; ++at)
            keys.push(table.keyAt(at))
        const kept = table.selectedKeys.filter(function (key) { return keys.includes(key) })
        if (kept.length !== table.selectedKeys.length)
            table.selectedKeys = kept
        const cursor = keys.indexOf(table.cursorKey)
        if (cursor >= 0 && cursor !== rows.currentIndex)
            rows.currentIndex = cursor
    }

    onRevisionChanged: Qt.callLater(table.reconcile)
    Layout.fillWidth: true
    spacing: Theme.gapXs

    // The column titles over the cells they head.
    Row {
        id: header
        objectName: "tableHeader"
        Layout.fillWidth: true
        leftPadding: Theme.gapM
        rightPadding: Theme.gapM
        Repeater {
            model: table.columns
            delegate: Text {
                id: heading
                required property var modelData
                width: (header.width - 2 * Theme.gapM) * heading.modelData.share / table.share
                rightPadding: Theme.gapS
                text: heading.modelData.title
                font: Theme.caption
                color: Theme.textMuted
                elide: Text.ElideRight
                textFormat: Text.PlainText
                Accessible.role: Accessible.ColumnHeader
                Accessible.name: heading.text
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.border
    }

    Label {
        objectName: table.prefix + "empty"
        visible: rows.count === 0 && table.emptyText !== ""
        text: table.emptyText
    }

    CursorList {
        id: rows
        objectName: table.prefix + "table"
        visible: rows.count > 0
        Layout.fillWidth: true
        // Every row is built, the page around the table scrolling them.
        Layout.preferredHeight: rows.count * rows.rowHeight
        interactive: false
        activeFocusOnTab: true
        rowHeight: table.touch ? Theme.rowTouch : Theme.controlM
        model: table.model
        Accessible.role: Accessible.List
        Accessible.name: table.label

        onMoved: {
            table.cursorKey = table.keyAt(rows.currentIndex)
            if (!table.extending)
                table.selectOnly(rows.currentIndex)
        }
        // Reaching the rows by keyboard selects the row under the cursor.
        onActiveFocusChanged: if (rows.activeFocus && Theme.focusVisible && table.selectedKeys.length === 0 && rows.count > 0)
            table.selectOnly(Math.max(0, rows.currentIndex))

        delegate: TableRow {}
    }

    component TableRow: FocusableControl {
        id: row

        required property int index
        required property var model
        // The array's item, or the list model's roles.
        readonly property var record: row.model.modelData
        // Empty while the row goes, its record gone first.
        readonly property string key: row.record ? String(table.keyOf(row.record)) : ""
        readonly property var cells: row.record ? table.cells(row.record).map(function (cell) { return cell ?? "" }) : []
        // The first cell, which names the row.
        readonly property string title: row.cells[0] ?? ""
        readonly property bool selected: table.selectedKeys.includes(row.key)

        // A row given focus takes the cursor.
        onActiveFocusChanged: if (row.activeFocus && rows.currentIndex !== row.index) table.point(row.index)
        onRecordChanged: ++table.revision
        Component.onCompleted: ++table.revision
        Component.onDestruction: ++table.revision

        objectName: table.prefix + row.key
        implicitWidth: rows.width
        implicitHeight: rows.rowHeight
        tabFocusable: false
        tapSelects: true
        ringOffset: 0
        radius: 0
        pointerFocus: rows
        focusRingSource: rows.currentIndex === row.index ? rows : row
        color: row.selected ? Theme.accentSoft : "transparent"
        hoverColor: row.selected ? Theme.accentSoft : Theme.subtleFill
        Accessible.role: Accessible.ListItem
        Accessible.name: table.columns.map(function (column, at) {
            return row.cells[at] !== "" ? column.title + ": " + row.cells[at] : ""
        }).filter(function (part) { return part !== "" }).join(", ")
        Accessible.selectable: true
        Accessible.selected: row.selected

        onClicked: function (touch, modifiers) {
            table.point(row.index)
            if (table.multiSelect && (modifiers & Qt.ControlModifier))
                table.toggle(row.index)
            else if (table.multiSelect && (modifiers & Qt.ShiftModifier))
                table.selectRange(row.index)
            else
                table.selectOnly(row.index)
        }
        onMenuRequested: {
            table.point(row.index)
            if (table.multiSelect)
                table.toggle(row.index)
            else
                table.selectOnly(row.index)
        }
        onActivated: {
            table.point(row.index)
            if (!row.selected)
                table.selectOnly(row.index)
            table.opened(row.record)
        }
        Keys.onPressed: function (event) {
            const modifiers = event.modifiers & ~Qt.KeypadModifier
            if (!table.multiSelect)
                return
            if (modifiers === Qt.ShiftModifier) {
                const page = Math.max(1, Math.floor(rows.height / rows.rowHeight) - 1)
                const to = ({ [Qt.Key_Down]: rows.currentIndex + 1, [Qt.Key_Up]: rows.currentIndex - 1,
                              [Qt.Key_Home]: 0, [Qt.Key_End]: rows.count - 1,
                              [Qt.Key_PageDown]: rows.currentIndex + page, [Qt.Key_PageUp]: rows.currentIndex - page })[event.key]
                if (to === undefined)
                    return
                table.extendTo(to)
                event.accepted = true
            } else if (modifiers === Qt.ControlModifier && event.key === Qt.Key_Space) {
                table.toggle(rows.currentIndex)
                event.accepted = true
            } else if (modifiers === Qt.ControlModifier && event.key === Qt.Key_A) {
                table.selectAll()
                event.accepted = true
            }
        }

        Repeater {
            model: table.columns
            delegate: Text {
                id: cell
                required property int index
                x: Theme.gapM + (row.width - 2 * Theme.gapM) * table.columns.slice(0, cell.index).reduce(function (sum, column) {
                    return sum + column.share
                }, 0) / table.share
                width: (row.width - 2 * Theme.gapM) * table.columns[cell.index].share / table.share
                y: (row.height - cell.height) / 2
                rightPadding: Theme.gapS
                text: row.cells[cell.index] ?? ""
                font: cell.index === 0 ? Theme.strong(Theme.body) : Theme.body
                color: cell.index === 0 ? Theme.textPrimary : Theme.textSecondary
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.border
        }
    }
}
