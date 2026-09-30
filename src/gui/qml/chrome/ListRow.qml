pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// One item of a CursorList in a screen: a title over a detail line on a
// surface card, gold-soft when selected. The list holds the tab stop and
// the cursor; a tap selects, a double tap or Enter activates.
FocusableControl {
    id: row

    property string title
    property string detail
    property bool selected: false
    property bool cursor: false
    property bool touch: false
    property Item view: null

    width: row.view ? row.view.width : implicitWidth
    implicitHeight: Math.max(row.touch ? Theme.rowTouch : Theme.controlM, lines.implicitHeight + 2 * Theme.gapM)
    tabFocusable: false
    tapSelects: true
    ringOffset: 0
    pointerFocus: row.view ?? row
    focusRingSource: row.cursor && row.view ? row.view : row
    color: row.selected ? Theme.accentSoft : Theme.surface
    hoverColor: row.selected ? Theme.accentSoft : Theme.subtleFill
    borderColor: Theme.border
    Accessible.role: Accessible.ListItem
    Accessible.name: row.detail !== "" ? row.title + ", " + row.detail : row.title
    Accessible.selectable: true
    Accessible.selected: row.selected

    ColumnLayout {
        id: lines
        anchors.fill: parent
        anchors.margins: Theme.gapM
        spacing: Theme.gapXs
        Text {
            Layout.fillWidth: true
            text: row.title
            font: Theme.strong(Theme.body)
            color: Theme.textPrimary
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        Text {
            Layout.fillWidth: true
            visible: row.detail !== ""
            text: row.detail
            font: Theme.caption
            color: Theme.textSecondary
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
    }
}
