pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// One explorer row, used by the entry list and the sidebar. It draws the
// icon, name, and detail; it drags its payload, takes payload drops when it
// is a folder, and edits its name in place. Selection is a gold-soft wash;
// a row on the way to the open location only sets its name a step heavier.
FocusableControl {
    id: row

    property string kind
    property string entryId
    property string payload
    property int colorIndex: -1
    property string title
    property string detail
    property real detailWidth: 0
    property bool selected: false
    property bool along: false
    property bool cursor: false
    // Session marks this row current: the last organization, the open document.
    property bool here: false
    property Item view: null
    property bool touch: false
    property bool dropTarget: false
    property bool disclosure: false
    property int depth: 0
    property bool expandable: false
    property bool expanded: false
    property bool editing: false
    readonly property font titleFont: row.touch ? Theme.bodyLarge : Theme.body

    signal toggled()
    signal committed(string text)
    signal cancelled()

    function beginEdit(text) {
        editor.text = text
        row.editing = true
        editor.selectAll()
        editor.forceActiveFocus()
    }

    function finishEdit(commit) {
        if (!row.editing)
            return
        // Take focus off the editor so its scope does not hand it back hidden.
        row.forceActiveFocus()
        row.editing = false
        if (commit)
            row.committed(editor.text.trim())
        else
            row.cancelled()
    }

    implicitHeight: row.touch ? Theme.rowTouch : Theme.rowDense
    tabFocusable: false
    ringOffset: 0
    inset: Theme.inset
    tapEnabled: !row.editing
    focusRingSource: row.cursor && row.view ? row.view : row
    pointerFocus: row.view ?? row
    color: drop.containsDrag || row.selected ? Theme.accentSoft : "transparent"
    hoverColor: row.selected ? Theme.accentSoft : Theme.subtleFill
    borderColor: drop.containsDrag ? Theme.accentLine : "transparent"

    Accessible.role: Accessible.ListItem
    Accessible.name: !row.expandable ? row.title
                   : row.expanded ? qsTr("%1, expanded").arg(row.title)
                   : qsTr("%1, collapsed").arg(row.title)
    Accessible.selectable: true
    Accessible.selected: row.selected

    // A mouse drag carries the row inside the window (Drag.Internal): folder
    // rows, tree nodes, and crumbs take it from `drag.source`.
    // Nothing outside the studio takes a row, and a browser only drags
    // natively with JSPI. The carrier follows the pointer; targets light up.
    Item {
        id: carrier
        x: dragger.centroid.position.x
        y: dragger.centroid.position.y
        Drag.dragType: Drag.Internal
        Drag.source: row
        Drag.supportedActions: Qt.MoveAction
    }

    DragHandler {
        id: dragger
        enabled: row.payload !== "" && !row.editing
        target: null
        dragThreshold: 12
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: Qt.DragMoveCursor
        onActiveChanged: if (dragger.active)
            carrier.Drag.active = true
        else
            carrier.Drag.drop()
    }

    RowDropArea {
        id: drop
        anchors.fill: parent
        enabled: row.dropTarget
        folderId: row.entryId
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.inset + Theme.gapS + row.depth * Theme.gapM
        anchors.rightMargin: row.inset + Theme.gapS
        spacing: Theme.gapS

        Item {
            visible: row.disclosure
            Layout.preferredWidth: Theme.iconM
            Layout.fillHeight: true

            Icon {
                objectName: "disclosure"
                anchors.centerIn: parent
                width: Theme.iconS
                height: Theme.iconS
                visible: row.expandable || row.expanded
                name: "chevron"
                color: Theme.textMuted
                rotation: row.expanded ? 90 : 0

                Behavior on rotation { Ease { duration: Theme.fast } }
            }
            MouseArea {
                anchors.fill: parent
                enabled: row.expandable
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggled()
            }
        }

        Icon {
            Layout.preferredWidth: row.touch ? Theme.iconL : Theme.iconM
            Layout.preferredHeight: row.touch ? Theme.iconL : Theme.iconM
            name: row.kind
            color: row.kind === "folder" ? Theme.accentDark
                 : row.colorIndex >= 0 ? Theme.spaceColor(row.colorIndex) : Theme.textSecondary
            fillColor: row.kind === "folder" ? Theme.fill(Theme.accent, 0.22) : "transparent"
        }

        Text {
            objectName: "rowTitle"
            visible: !row.editing
            Layout.fillWidth: true
            text: row.title
            color: Theme.textPrimary
            font: row.along ? Theme.strong(row.titleFont) : row.titleFont
            elide: Text.ElideRight
        }

        Field {
            id: editor
            objectName: "rowEditor"
            visible: row.editing
            Layout.fillWidth: true
            implicitHeight: row.height - Theme.gapS
            leftPadding: Theme.gapS
            font: row.titleFont
            fill: Theme.background
            placeholderText: qsTr("Name")
            EnterKey.type: Qt.EnterKeyGo
            Keys.onReturnPressed: row.finishEdit(true)
            Keys.onEnterPressed: row.finishEdit(true)
            Keys.onEscapePressed: row.finishEdit(false)
            // Focus leaving the editor drops the edit without taking focus back.
            onActiveFocusChanged: if (!editor.activeFocus)
                row.editing = false
        }

        Text {
            objectName: "rowDetail"
            visible: row.detailWidth > 0
            Layout.preferredWidth: row.detailWidth
            text: row.detail
            color: Theme.textMuted
            font: row.touch ? Theme.body : Theme.caption
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
