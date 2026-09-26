pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// A captioned sidebar list: one tab stop, arrows move, a click or Enter opens
// the row's location. The rows read their id from `idRole`; a `tree` section
// indents, folds, and takes dropped payloads. While a deeper section shows
// the open location (`ancestral`), this one only marks the row on the way.
ColumnLayout {
    id: section

    property alias title: caption.text
    property alias model: nav.model
    property string kind
    property string idRole
    property string currentId
    property string rowName
    property string listName
    property bool tree: false
    property bool ancestral: false
    property bool touch: false
    readonly property alias list: nav

    // A row was opened; `id` is its location id.
    signal opened(string id)
    // The cursor moved to `row` while the list has focus.
    signal moved(Item row)

    // Tree keys: Right opens a folder or steps into it; Left closes it or
    // steps out to its parent. False when there is nowhere to go.
    function stepIn() {
        const node = nav.currentItem as EntryRow
        if (!node)
            return false
        if (node.expandable && !node.expanded) {
            Session.toggleFolder(node.entryId)
            return true
        }
        // An open folder with children is followed by its first child.
        const hasChild = node.depth === 0 ? nav.count > 1 : node.expandable
        if (node.expanded && hasChild) {
            nav.moveCursor(nav.currentIndex + 1)
            return true
        }
        return false
    }

    function stepOut() {
        const node = nav.currentItem as EntryRow
        if (!node)
            return false
        if (node.expandable && node.expanded) {
            Session.toggleFolder(node.entryId)
            return true
        }
        for (let i = nav.currentIndex - 1; i >= 0; --i) {
            const above = nav.itemAtIndex(i) as EntryRow
            if (above && above.depth < node.depth) {
                nav.moveCursor(i)
                return true
            }
        }
        return false
    }

    spacing: 0

    Caption {
        id: caption
        Layout.fillWidth: true
        Layout.leftMargin: Theme.inset + Theme.gapS
        Layout.rightMargin: Theme.inset + Theme.gapS
        Layout.topMargin: Theme.gapL
        Layout.bottomMargin: Theme.gapXs
    }

    CursorList {
        id: nav
        objectName: section.listName
        Layout.fillWidth: true
        implicitHeight: nav.contentHeight
        rowHeight: section.touch ? Theme.rowTouch : Theme.rowDense
        interactive: false
        activeFocusOnTab: true
        currentIndex: 0
        Accessible.role: section.tree ? Accessible.Tree : Accessible.List
        Accessible.name: section.title

        Keys.onRightPressed: function (event) {
            event.accepted = section.tree && event.modifiers === Qt.NoModifier && section.stepIn()
        }
        Keys.onLeftPressed: function (event) {
            event.accepted = section.tree && event.modifiers === Qt.NoModifier && section.stepOut()
        }
        onCurrentItemChanged: if (nav.activeFocus)
            section.moved(nav.currentItem)
        onActiveFocusChanged: if (nav.activeFocus)
            section.moved(nav.currentItem)

        delegate: EntryRow {
            id: row
            required property var model
            required property int index

            objectName: section.rowName + row.index
            width: nav.width
            touch: section.touch
            view: nav
            cursor: nav.currentIndex === row.index
            // The tree's first row is the space itself.
            kind: section.tree && row.index === 0 ? "space" : section.kind
            entryId: row.model[section.idRole]
            title: row.model.name
            colorIndex: row.model.colorIndex ?? -1
            depth: section.tree ? row.model.depth : 0
            disclosure: section.tree
            expandable: section.tree && row.model.depth > 0 && row.model.hasChildren
            expanded: section.tree && row.model.expanded
            selected: section.tree ? row.model.current : row.entryId === section.currentId && !section.ancestral
            along: !section.tree && section.ancestral && row.entryId === section.currentId
            dropTarget: section.tree
            Accessible.role: section.tree ? Accessible.TreeItem : Accessible.ListItem
            onToggled: Session.toggleFolder(row.entryId)
            onActivated: {
                nav.currentIndex = row.index
                section.opened(row.entryId)
            }
        }
    }
}
