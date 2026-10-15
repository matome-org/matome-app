pragma ComponentBehavior: Bound

import QtQuick
import matome
import "Marks.js" as Marks

// Two texts side by side, line by line (MarkdownDiff's lines): the earlier
// on the left, the later on the right, each line with its number. A line
// removed or added sits on its wash, the words a changed line removes or
// adds marked inside it; a side without the line stays blank. Both sides
// are one row each, so they scroll together, and only the rows in sight
// are built. Unchanged runs fold into a row a click or Enter opens.
GlideList {
    id: list

    // MarkdownDiff's lines.
    property var lines: null
    readonly property real numberWidth: digits.advanceWidth + 2 * Theme.gapS

    function expand(index) {
        if ((list.itemAtIndex(index) as Line)?.change === "fold")
            list.lines.expand(index)
    }

    model: list.lines
    line: Math.round(Theme.mono.pixelSize * 1.5)
    topMargin: Theme.gapS
    bottomMargin: Theme.gapL
    Accessible.role: Accessible.Table
    delegate: Line {}

    Keys.onPressed: function (event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && list.marked >= 0) {
            list.expand(list.marked)
            event.accepted = true
        } else {
            event.accepted = list.navigate(event)
        }
    }

    TextMetrics {
        id: digits
        font: Theme.mono
        text: "00000"
    }

    TapHandler {
        parent: list
        onTapped: function (point) {
            const at = list.mapToItem(list.contentItem, point.position.x, point.position.y)
            const row = list.itemAt(at.x, at.y) as Line
            if (row)
                list.expand(row.index)
        }
    }

    // One row: a fold, or the line on each side.
    component Line: Item {
        id: row

        required property int index
        required property string change
        required property int count
        required property int beforeNumber
        required property int afterNumber
        required property string beforeText
        required property string afterText

        width: list.width
        height: row.change === "fold" ? fold.height + 2 * Theme.gapXs : Math.max(left.height, right.height)
        Accessible.role: row.change === "fold" ? Accessible.Button : Accessible.Row
        Accessible.name: row.change === "fold" ? foldText.text
                         : [Marks.name(row.change), row.beforeNumber > 0 ? qsTr("Line %1").arg(row.beforeNumber) : "",
                            row.afterNumber > 0 ? qsTr("Line %1").arg(row.afterNumber) : ""]
                           .filter(function (part) { return part !== "" }).join(", ")

        Rectangle {
            id: fold
            visible: row.change === "fold"
            y: Theme.gapXs
            width: row.width
            height: foldText.implicitHeight + 2 * Theme.gapS
            radius: Theme.rounding
            color: Theme.subtleFill
            Text {
                id: foldText
                anchors.centerIn: parent
                text: qsTr("⋯ %n unchanged line(s)", "", row.count)
                font: Theme.body
                color: Theme.textMuted
                textFormat: Text.PlainText
            }
        }
        Side {
            id: left
            visible: row.change !== "fold"
            width: row.width / 2
            number: row.beforeNumber
            text: row.beforeText
            wash: row.change === "removed" || row.change === "changed" ? Marks.wash(Theme, "removed") : "transparent"
        }
        Side {
            id: right
            visible: row.change !== "fold"
            x: row.width / 2
            width: row.width / 2
            number: row.afterNumber
            text: row.afterText
            wash: row.change === "added" || row.change === "changed" ? Marks.wash(Theme, "added") : "transparent"
        }
        Rectangle {
            visible: row.index === list.marked && list.activeFocus
            anchors.fill: parent
            color: "transparent"
            border.color: Theme.accentLine
            border.width: 2
        }
    }

    // One side of a row: the line's number and its text, or a blank where
    // the side has no line.
    component Side: Rectangle {
        id: side

        property int number
        property string text
        property color wash

        height: Math.max(code.implicitHeight, list.line)
        color: side.number > 0 ? side.wash : Theme.subtleFill
        Text {
            width: list.numberWidth - Theme.gapS
            y: (list.line - implicitHeight) / 2
            text: side.number > 0 ? side.number : ""
            font: Theme.mono
            color: Theme.textMuted
            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
        }
        TextEdit {
            id: code
            x: list.numberWidth
            width: side.width - list.numberWidth - Theme.gapS
            readOnly: true
            selectByMouse: true
            activeFocusOnPress: false
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
            text: side.number > 0 ? "<style>" + Marks.css(Theme) + "</style><div style=\"white-space:pre-wrap\">" + side.text + "</div>" : ""
            font: Theme.mono
            color: Theme.textPrimary
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.textPrimary
        }
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: Theme.border
        }
    }
}
