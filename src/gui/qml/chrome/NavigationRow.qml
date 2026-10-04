pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// One row of a screen's navigation column: icon and label, the gold-soft
// wash when selected, a chevron when it expands. Touch-sized under `touch`.
// A `detail` line under the label grows the row; a checklist names what
// each choice means there.
FocusableControl {
    id: row

    property string text
    property string detail
    property string icon
    property bool selected: false
    property bool checkable: false
    property bool indented: false
    property bool strong: false
    property bool expandable: false
    property bool expanded: false
    property bool touch: false

    Layout.fillWidth: true
    implicitHeight: Math.max(row.touch ? Theme.rowTouch : Theme.controlM, line.implicitHeight + 2 * Theme.gapS)
    color: row.selected ? Theme.accentSoft : "transparent"
    radius: Theme.rounding
    Accessible.role: Accessible.Button
    Accessible.name: row.expandable ? (row.expanded ? qsTr("Collapse %1") : qsTr("Expand %1")).arg(row.text)
                                    : row.detail !== "" ? row.text + ", " + row.detail : row.text
    Accessible.checkable: row.checkable || row.expandable
    Accessible.checked: row.expandable ? row.expanded : row.selected

    RowLayout {
        id: line
        anchors.fill: parent
        anchors.leftMargin: row.indented ? 2 * Theme.gapM : Theme.gapM
        anchors.rightMargin: Theme.gapM
        spacing: Theme.gapS
        Icon { name: row.icon; color: row.selected ? Theme.accentText : Theme.textSecondary }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: row.text
                font: row.strong ? Theme.strong(Theme.body) : Theme.body
                color: row.selected ? Theme.accentText : Theme.textPrimary
                elide: Text.ElideRight
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
        Icon {
            objectName: "organizationExpansionArrow"
            visible: row.expandable
            name: "chevron"
            color: Theme.textSecondary
            rotation: row.expanded ? 90 : 0
            Behavior on rotation { Ease {} }
        }
    }
}
