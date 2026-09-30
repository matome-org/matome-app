pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome

// A plain text editor for Markdown and text documents. Tab leaves it; the
// window's keys (Ctrl+S, Ctrl+Enter) still reach it. With `images`, a pasted,
// dropped, or picked image uploads to the space's assets folder: a
// placeholder marks the cursor until the link replaces it. A dropped .md
// file is reported instead (`draftDropped`). With `images` too, "@" or "/"
// after a space or at a line's start suggests the space's files by name:
// picking one after "@" links it by id, after "/" by its path. "#" at a
// line's start suggests commands.
C.TextArea {
    id: editor

    property bool images: false
    property string assetError
    // The placeholder text of each upload under way, by token.
    property var uploads: ({})
    // The document being edited and its folder: left out of, and first
    // among, the suggested files.
    property string documentId
    property string folderId
    // Links must pin the file's version (a managed document's space rule).
    property bool pinLinks: false
    // The "@", "/", or "#" being typed: where it starts, which, and what
    // follows it.
    property int triggerAt: -1
    property string trigger
    property string query
    property var files: []
    // The query `files` answers; another one is still being looked up.
    property string answered
    readonly property var commands: [
        { id: "@", title: qsTr("Link a file"), detail: qsTr("Type @ and part of its name"), icon: "document" },
        { id: "/", title: qsTr("Link a file by path"), detail: qsTr("Type / and part of its name"), icon: "folder" },
        { id: "image", title: qsTr("Insert image"), detail: qsTr("From this device"), icon: "image" }
    ].filter(function (command) {
        return command.title.toLowerCase().indexOf(editor.query.toLowerCase()) >= 0
    })

    signal draftDropped(url file)

    // Finds the "@", "/", or "#" the cursor is typing after, or closes the
    // suggestions when there is none.
    function detect() {
        const before = editor.images ? editor.text.slice(0, editor.cursorPosition) : ""
        const file = /(^|\s)([@\/])([^\s@\/]*)$/.exec(before)
        const command = /(^|\n)#([^\s#]*)$/.exec(before)
        const found = file ? { trigger: file[2], query: file[3] } : command ? { trigger: "#", query: command[2] } : null
        if (!found || !editor.activeFocus) {
            editor.triggerAt = -1
            suggestions.close()
            return
        }
        editor.triggerAt = before.length - found.query.length - 1
        if (found.trigger !== editor.trigger || found.query !== editor.query || !suggestions.visible) {
            editor.trigger = found.trigger
            editor.query = found.query
            if (found.trigger !== "#")
                searching.restart()
        }
        const at = editor.cursorRectangle
        suggestions.x = Math.min(at.x, Math.max(0, editor.width - suggestions.width))
        suggestions.y = at.y + at.height + Theme.gapXs
        suggestions.open()
    }
    // Writes `text` in place of the "@", "/", or "#" and what follows it.
    function replaceTrigger(text) {
        const start = editor.triggerAt
        editor.remove(start, editor.cursorPosition)
        editor.insert(start, text)
        editor.triggerAt = -1
        suggestions.close()
    }
    function choose(index) {
        if (editor.trigger === "#") {
            const command = editor.commands[index]
            if (command.id === "image") {
                editor.replaceTrigger("")
                Session.assets.pickImages()
            } else {
                editor.replaceTrigger(command.id)
                Qt.callLater(editor.detect)
            }
            return
        }
        const file = editor.files[index]
        editor.replaceTrigger(editor.trigger === "/" ? Session.assets.pathLink(file.title, file.path)
                                                     : Session.assets.markdownLink(file.title, file.documentId,
                                                                                   file.image || editor.pinLinks ? file.versionId : "",
                                                                                   file.image))
    }

    // Swaps the placeholder of upload `token` for `text` where it now stands.
    function settle(token, text) {
        const placeholder = editor.uploads[token]
        if (!placeholder)
            return
        const at = editor.text.indexOf(placeholder)
        if (at >= 0) {
            editor.remove(at, at + placeholder.length)
            editor.insert(at, text)
        }
        delete editor.uploads[token]
    }

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(10 * Theme.controlL, editor.implicitHeight)
    font: Theme.body
    color: Theme.textPrimary
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.accentSoft
    selectedTextColor: Theme.textPrimary
    wrapMode: TextEdit.Wrap
    textFormat: TextEdit.PlainText
    selectByMouse: true
    activeFocusOnTab: true
    background: Rectangle {
        color: Theme.surface
        radius: Theme.rounding
        border.color: drop.containsDrag || editor.activeFocus ? Theme.accentLine : Theme.border
    }

    onTextChanged: Qt.callLater(editor.detect)
    onCursorPositionChanged: Qt.callLater(editor.detect)
    onActiveFocusChanged: if (!editor.activeFocus) suggestions.close()

    Keys.onPressed: function (event) {
        if (suggestions.visible && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
            suggestions.move(event.key === Qt.Key_Down ? 1 : -1)
            event.accepted = true
        } else if (suggestions.visible && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                           || event.key === Qt.Key_Tab) && event.modifiers === Qt.NoModifier) {
            suggestions.choose()
            event.accepted = true
        } else if (suggestions.visible && event.key === Qt.Key_Escape) {
            editor.triggerAt = -1
            suggestions.close()
            event.accepted = true
        } else if (editor.images && event.matches(StandardKey.Paste) && Clipboard.hasImage()) {
            Session.assets.uploadImage(Clipboard.imageName(), Clipboard.image())
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            editor.nextItemInFocusChain(event.key === Qt.Key_Tab).forceActiveFocus(Qt.TabFocusReason)
            event.accepted = true
        } else if (event.modifiers & Qt.ControlModifier) {
            event.accepted = Session.handleKey(event.key, event.modifiers, true)
        }
    }

    Connections {
        target: Session.assets
        enabled: editor.images && editor.visible
        function onQueued(token, name) {
            const placeholder = "![" + qsTr("Uploading %1…").arg(name) + "](matome:uploading/" + token + ")"
            editor.uploads[token] = placeholder
            editor.assetError = ""
            editor.insert(editor.cursorPosition, placeholder)
        }
        function onUploaded(token, markdown) {
            editor.settle(token, markdown)
        }
        function onFailed(token, code) {
            editor.settle(token, "")
            editor.assetError = code
        }
    }

    Timer {
        id: searching
        interval: 150
        onTriggered: Session.assets.search(editor.query, editor.folderId, editor.documentId)
    }

    Connections {
        target: Session.assets
        enabled: editor.images && editor.visible
        function onFound(text, files) {
            if (text !== editor.query || editor.trigger === "#")
                return
            // A file with no published version yet can only be linked by path:
            // images and pinned links need one.
            editor.answered = text
            editor.files = editor.trigger === "/" ? files : files.filter(function (file) {
                return file.versionId !== "" || !(file.image || editor.pinLinks)
            })
        }
    }

    LinkSuggestions {
        id: suggestions
        keeper: editor
        rows: editor.trigger === "#" ? editor.commands
                                     : editor.files.map(function (file) {
                                           return { title: file.title, detail: editor.trigger === "/" ? file.path : file.place,
                                                    icon: file.image ? "image" : "document" }
                                       })
        emptyText: editor.trigger === "#" ? qsTr("No command matches.")
                 : editor.answered !== editor.query ? qsTr("Searching…") : qsTr("No file matches “%1”.").arg(editor.query)
        onChosen: function (index) { editor.choose(index) }
        onClosed: {
            editor.files = []
            editor.answered = ""
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        onEntered: function (drag) { drag.accepted = drag.hasUrls && editor.enabled }
        onDropped: function (event) {
            if (String(event.urls[0]).toLowerCase().endsWith(".md"))
                editor.draftDropped(event.urls[0])
            else if (editor.images)
                Session.assets.uploadUrls(event.urls)
            event.acceptProposedAction()
        }
    }
}
