pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The children of the open location in one scrolling list. The cursor is the
// selection: moving it tells Session what the commands act on. Enter or a
// double click opens; on touch a tap opens. New names and renames are edited
// in place. Files dropped on the list upload into the open folder.
FocusScope {
    id: pane

    property bool touch: false
    // Ids of the last location, so the row you came from gets the cursor.
    property var cameFrom: []
    property bool landing: true
    readonly property Item popups: C.Overlay.overlay
    property string pendingName

    readonly property string errorText: Messages.failure(Session.locationError, Session.childKind)
    readonly property Item listView: list
    readonly property EntryRow cursorRow: list.currentItem as EntryRow
    readonly property string cursorPayload: pane.cursorRow ? pane.cursorRow.payload : ""

    signal menuRequested(var ids, Item item, real x, real y)

    function focusList() {
        list.forceActiveFocus()
    }

    function beginNew() {
        creator.beginEdit("")
    }

    function beginRename(name) {
        if (pane.cursorRow)
            pane.cursorRow.beginEdit(name)
    }

    function openCursor() {
        if (pane.cursorRow)
            Session.openEntry(pane.cursorRow.kind, pane.cursorRow.entryId)
    }

    function rowMenu(row, x, y) {
        const reviews = row.kind === "document" && row.controlled ? ["controlled-docs"] : []
        pane.menuRequested(["download", "toggle-document-control"].concat(reviews,
                           ["rename", "cut", "paste", "trash", "restore", "new", "upload", "refresh"]),
                           row, x, y)
    }

    function blankMenu(x, y) {
        pane.menuRequested(["new", "upload", "paste", "restore", "refresh"], list, x, y)
    }

    // Lands the cursor after the rows change: a row just created by name,
    // else the row we came up from, else the row Session marks current.
    function land() {
        if (list.count === 0) {
            list.currentIndex = -1
            return
        }
        for (let i = 0; i < list.count; ++i) {
            const row = list.itemAtIndex(i) as EntryRow
            if (!row)
                continue
            if (pane.pendingName !== "" && row.title === pane.pendingName && row.kind !== "document") {
                pane.pendingName = ""
                pane.landing = false
                list.currentIndex = i
                return
            }
            if (pane.landing && (pane.cameFrom.indexOf(row.entryId) >= 0 || row.here)) {
                pane.landing = false
                list.currentIndex = i
                return
            }
        }
        if (list.currentIndex < 0 || list.currentIndex >= list.count)
            list.currentIndex = 0
    }

    onCursorPayloadChanged: Session.setFocusPayload(pane.cursorPayload)
    onCursorRowChanged: if (pane.cursorRow && pane.cursorRow.kind === "document" && !pane.cursorRow.here)
        Session.openEntry("document", pane.cursorRow.entryId)

    Connections {
        target: Session.entries
        function onModelAboutToBeReset() {
            pane.cameFrom = [Session.currentOrgId, Session.currentSpaceId, Session.currentFolderId]
        }
        function onModelReset() {
            pane.landing = true
            pane.pendingName = ""
            Qt.callLater(pane.land)
        }
        function onRowsInserted() {
            Qt.callLater(pane.land)
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        // Files from the desktop upload into the open folder. Rows only
        // drop on other folders: the list is where they already are.
        onEntered: function (drag) {
            drag.accepted = drag.hasUrls && Session.childKind === "folder"
        }
        onDropped: function (event) {
            Session.uploadUrls(event.urls)
            event.acceptProposedAction()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        EntryRow {
            id: creator
            objectName: "newRow"
            visible: creator.editing
            Layout.fillWidth: true
            Layout.topMargin: Theme.gapXs
            touch: pane.touch
            kind: Session.childKind
            selected: true
            handCursor: false
            onCommitted: function (text) {
                if (text !== "") {
                    pane.pendingName = text
                    Session.createHere(text)
                }
                pane.focusList()
            }
            onCancelled: pane.focusList()
        }

        CursorList {
            id: list
            objectName: "entryList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true
            activeFocusOnTab: true
            rowHeight: pane.touch ? Theme.rowTouch : Theme.rowDense
            topMargin: Theme.gapXs
            // On touch the last row scrolls clear of the floating button.
            bottomMargin: pane.touch ? Theme.controlXl + 2 * Theme.gapL : Theme.gapS
            model: Session.entries
            Accessible.role: Accessible.List
            Accessible.name: qsTr("Items")

            C.ScrollBar.vertical: ThinScrollBar {}

            onMoved: pane.landing = false
            onMenuRequested: {
                if (pane.cursorRow)
                    pane.rowMenu(pane.cursorRow, Theme.gapXl, pane.cursorRow.height)
                else
                    pane.blankMenu(Theme.gapXl, Theme.gapS)
            }

            Tap {
                popups: pane.popups
                onHit: function (position, button) {
                    if (list.indexAt(position.x + list.contentX, position.y + list.contentY) >= 0)
                        return
                    list.forceActiveFocus()
                    if (button === Qt.RightButton)
                        pane.blankMenu(position.x, position.y)
                }
                onHeld: function (position) {
                    if (list.indexAt(position.x + list.contentX, position.y + list.contentY) < 0)
                        pane.blankMenu(position.x, position.y)
                }
            }

            delegate: EntryRow {
                id: entry
                required kind
                required entryId
                required payload
                required detail
                required colorIndex
                required property string name
                required property bool current
                required controlled
                required property int index

                objectName: "entryRow" + entry.index
                width: list.width
                touch: pane.touch
                view: list
                cursor: list.currentIndex === entry.index
                selected: entry.cursor
                here: entry.current
                title: entry.name
                detailWidth: pane.width < 480 ? 104 : 140
                dropTarget: entry.kind === "folder"
                tapSelects: true
                onClicked: function (touch) {
                    list.moveCursor(entry.index)
                    if (touch || pane.touch)
                        pane.openCursor()
                }
                onActivated: {
                    list.moveCursor(entry.index)
                    pane.openCursor()
                }
                onMenuRequested: function (position) {
                    list.moveCursor(entry.index)
                    pane.rowMenu(entry, position.x, position.y)
                }
                onCommitted: function (text) {
                    if (text !== "" && text !== entry.name)
                        Session.renameFocused(text)
                    pane.focusList()
                }
                onCancelled: pane.focusList()
            }
        }
    }

    EmptyState {
        objectName: "emptyState"
        visible: list.count === 0 && !creator.editing
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.gapXl, Theme.measure)
        mode: Session.loading ? "loading" : pane.errorText !== "" ? "error" : "empty"
        text: Session.loading ? qsTr("Loading…") : pane.errorText !== "" ? pane.errorText
                                                               : Messages.empty(Session.childKind, Session.filter)
    }

    Rectangle {
        objectName: "dropOverlay"
        anchors.fill: parent
        anchors.margins: Theme.inset
        visible: drop.containsDrag
        radius: Theme.rounding
        color: Theme.fill(Theme.accent, 0.08)
        border.width: 1
        border.color: Theme.accentLine

        Text {
            anchors.centerIn: parent
            text: qsTr("Drop to upload here")
            color: Theme.accentText
            font: Theme.title
        }
    }
}
