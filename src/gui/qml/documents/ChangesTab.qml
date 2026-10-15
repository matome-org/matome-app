pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// The Changes tab of a review or of two versions compared: how much
// changed ("+12 −4 · 3 sections"), then the two texts compared, rendered
// (the later document with each block added, removed, or changed marked)
// or as source, side by side, as its Rendered / Source switch picks. Next
// change and Previous change (N, P) bring each change into view in turn;
// the page hands its keys to handleKey().
DetailTab {
    id: tab

    // Prefixes the object names of its parts.
    property string name
    property string before
    property string after
    // The versions the images of each text are signed through.
    property string beforeVia
    property string afterVia
    property bool loaded: false
    property bool touch: false
    property string mode: "rendered"
    readonly property GlideList reader: tab.mode === "rendered" ? rendered.list : source
    readonly property var changes: tab.mode === "rendered" ? diff.blocks.changes : diff.lines.changes
    readonly property int nextChange: tab.changes.find(function (row) { return row > tab.reader.marked }) ?? -1
    readonly property int previousChange: {
        const earlier = tab.changes.filter(function (row) { return row < tab.reader.marked })
        return earlier.length > 0 ? earlier[earlier.length - 1] : -1
    }

    function go(row) {
        if (row < 0)
            return
        tab.reader.showIndex(row)
        tab.reader.forceActiveFocus(Qt.ShortcutFocusReason)
    }
    // N and P while the tab shows; true when the key was one of them.
    function handleKey(event): bool {
        if (!tab.shown || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return false
        if (event.key === Qt.Key_N)
            tab.go(tab.nextChange)
        else if (event.key === Qt.Key_P)
            tab.go(tab.previousChange)
        else
            return false
        return true
    }

    view: "changes"
    title: qsTr("Changes")

    commands: [
        ActionButton {
            objectName: tab.name + "PreviousChangeButton"
            text: qsTr("Previous change")
            icon: "up"
            key: "P"
            showLabel: !tab.compact
            tip: text
            usable: tab.previousChange >= 0
            reason: tab.changes.length === 0 ? qsTr("Nothing changed.") : qsTr("This is the first change.")
            onActivated: tab.go(tab.previousChange)
        },
        ActionButton {
            objectName: tab.name + "NextChangeButton"
            text: qsTr("Next change")
            icon: "down"
            key: "N"
            showLabel: !tab.compact
            tip: text
            usable: tab.nextChange >= 0
            reason: tab.changes.length === 0 ? qsTr("Nothing changed.") : qsTr("This is the last change.")
            onActivated: tab.go(tab.nextChange)
        },
        SegmentedSwitch {
            objectName: tab.name + "DiffMode"
            options: [{ value: "rendered", text: qsTr("Rendered"), icon: "document" },
                      { value: "source", text: qsTr("Source"), icon: "code" }]
            current: tab.mode
            showLabel: !tab.compact
            Accessible.name: qsTr("Show as")
            onPicked: function (value) { tab.mode = value }
        }
    ]

    MarkdownDiff {
        id: diff
        before: tab.loaded ? tab.before : ""
        after: tab.loaded ? tab.after : ""
    }

    Label {
        objectName: tab.name + "Summary"
        visible: tab.loaded
        text: qsTr("+%1 −%2 · %n section(s)", "", diff.sections).arg(diff.added).arg(diff.removed)
    }
    MarkdownView {
        id: rendered
        objectName: tab.name + "Rendered"
        visible: tab.loaded && tab.mode === "rendered"
        Layout.fillWidth: true
        Layout.fillHeight: true
        blockModel: diff.blocks
        via: tab.afterVia
        beforeVia: tab.beforeVia
        touch: tab.touch
        Accessible.name: qsTr("Changes")
        onDocumentRequested: function (id) { Session.openEntry("document", id) }
    }
    SourceDiff {
        id: source
        objectName: tab.name + "Source"
        visible: tab.loaded && tab.mode === "source"
        Layout.fillWidth: true
        Layout.fillHeight: true
        lines: diff.lines
        touch: tab.touch
        Accessible.name: qsTr("Changes")
    }
    Label {
        visible: !tab.loaded
        Layout.fillHeight: true
        text: qsTr("Working…")
    }
}
