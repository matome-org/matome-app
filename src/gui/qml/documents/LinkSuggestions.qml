pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"

// Suggestions under the text cursor while typing a link: rows of `{title,
// detail, icon}`. The editor keeps focus and drives it (`move`, `choose`);
// a click or tap on a row chooses it too.
C.Popup {
    id: popup

    property var rows: []
    property bool touch: false
    property Item keeper: null
    property string emptyText
    readonly property int rowHeight: popup.touch ? Theme.rowTouch : Theme.controlL

    signal chosen(int index)

    function move(step) {
        list.moveCursor(list.currentIndex + step)
    }
    function choose() {
        if (list.currentIndex >= 0 && list.currentIndex < popup.rows.length)
            popup.chosen(list.currentIndex)
    }

    onRowsChanged: list.currentIndex = popup.rows.length > 0 ? 0 : -1
    width: Math.min(Theme.column * 1.6, popup.parent ? popup.parent.width : Theme.column)
    padding: Theme.gapXs
    focus: false
    modal: false
    closePolicy: C.Popup.CloseOnPressOutsideParent

    background: Rectangle {
        radius: Theme.rounding
        color: Theme.surface
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0
        Label {
            visible: popup.rows.length === 0
            Layout.margins: Theme.gapS
            text: popup.emptyText
        }
        CursorList {
            id: list
            objectName: "linkSuggestions"
            visible: popup.rows.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(list.contentHeight, 6 * popup.rowHeight)
            rowHeight: popup.rowHeight
            interactive: list.contentHeight > list.height
            clip: true
            activeFocusOnTab: false
            model: popup.rows
            C.ScrollBar.vertical: ThinScrollBar {}
            Accessible.role: Accessible.List
            Accessible.name: qsTr("Suggestions")
            delegate: FocusableControl {
                id: row
                required property var modelData
                required property int index
                objectName: "suggestion" + row.index
                width: list.width
                height: popup.rowHeight
                tabFocusable: false
                ringOffset: 0
                pointerFocus: popup.keeper ?? row
                color: list.currentIndex === row.index ? Theme.accentSoft : "transparent"
                hoverColor: list.currentIndex === row.index ? Theme.accentSoft : Theme.subtleFill
                Accessible.role: Accessible.ListItem
                Accessible.name: row.modelData.detail ? row.modelData.title + ", " + row.modelData.detail : row.modelData.title
                onActivated: popup.chosen(row.index)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.gapS
                    anchors.rightMargin: Theme.gapS
                    spacing: Theme.gapS
                    Icon { name: row.modelData.icon }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            font: Theme.body
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: (row.modelData.detail ?? "") !== ""
                            text: row.modelData.detail ?? ""
                            font: Theme.caption
                            color: Theme.textSecondary
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }
    }
}
