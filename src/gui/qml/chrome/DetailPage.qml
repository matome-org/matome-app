pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// An item's page: the way back to its list and the item's name, one
// command bar, then the row of its tabs (its DetailTab children) over the
// tab shown. The bar holds the item's own commands (`commands`, then each
// tab's `pageCommands`) and, after a hairline, the shown tab's `commands`.
// When the name and the bar do not fit on one line, the bar goes below the
// name; when the bar's labels do not fit the width, its commands show only
// their icons (`compact`).
ColumnLayout {
    id: page

    // Prefixes the object names of its back button, title, and tabs.
    property string name
    property string backText
    property string title
    property bool narrow: false
    // What the page shows: another one opens on the tab `start`, else on
    // the first.
    property var subject
    property string start
    property string current
    property alias commands: itemRow.data
    default property alias tabs: body.data
    readonly property alias backButton: back
    readonly property var tabList: body.children.filter(function (child) { return child instanceof DetailTab })
    readonly property real labelled: page.labelledWidth(bar)
    readonly property bool compact: page.narrow || page.labelled > page.width
    readonly property bool stacked: back.implicitWidth + titleMetrics.advanceWidth + (page.compact ? bar.implicitWidth : page.labelled)
                                    + 2 * Theme.gapL > page.width

    signal backRequested()

    function show(view) {
        page.current = view
    }
    // Shows the tab another subject opens on.
    function opened() {
        page.current = page.start !== "" ? page.start : page.tabList[0]?.view ?? ""
    }
    // The width of the commands shown in `row`, each with its label.
    function labelledWidth(row: Item): real {
        let width = 0
        let shown = 0
        for (const child of row.children) {
            if (!child.visible)
                continue
            const button = child as ActionButton
            const nested = child as RowLayout
            width += button ? button.labelledWidth : nested ? page.labelledWidth(nested) : child.implicitWidth
            ++shown
        }
        return width + Math.max(0, shown - 1) * Theme.gapXs
    }
    // Whether `row` shows a command.
    function anyShown(row: Item): bool {
        for (const child of row.children) {
            const nested = child as RowLayout
            if (child.visible && (!nested || page.anyShown(nested)))
                return true
        }
        return false
    }

    onSubjectChanged: page.opened()
    Component.onCompleted: {
        for (const tab of page.tabList) {
            tab.shown = Qt.binding(function () { return page.current === tab.view })
            tab.compact = Qt.binding(function () { return page.compact })
            tab.pageCommandRow.parent = itemRow
            tab.commandRow.parent = tabRows
        }
        page.opened()
    }

    Layout.fillWidth: true
    spacing: Theme.gapM

    TextMetrics {
        id: titleMetrics
        font: Theme.heading
        text: page.title
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + Theme.gapM + 1

        GridLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            columns: page.stacked ? 2 : 3
            columnSpacing: Theme.gapL
            rowSpacing: Theme.gapS

            ActionButton {
                id: back
                objectName: page.name + "BackButton"
                text: page.backText
                icon: "back"
                showLabel: !page.narrow
                tip: text
                key: "Esc"
                onActivated: page.backRequested()
            }
            Text {
                objectName: page.name + "Title"
                Layout.fillWidth: true
                text: page.title
                font: Theme.heading
                color: Theme.textPrimary
                elide: Text.ElideRight
                textFormat: Text.PlainText
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }
            CommandBar {
                id: bar
                Layout.fillWidth: false
                Layout.columnSpan: page.stacked ? 2 : 1
                Layout.alignment: page.stacked ? Qt.AlignLeft : Qt.AlignRight
                Accessible.role: Accessible.ToolBar
                Accessible.name: page.title

                RowLayout {
                    id: itemRow
                    Layout.fillWidth: false
                    spacing: Theme.gapXs
                }
                BarRule {
                    visible: page.anyShown(itemRow) && page.anyShown(tabRows)
                }
                RowLayout {
                    id: tabRows
                    Layout.fillWidth: false
                    spacing: Theme.gapXs
                }
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

    Flow {
        Layout.fillWidth: true
        spacing: Theme.gapXs
        Accessible.role: Accessible.PageTabList
        Accessible.name: page.title

        Repeater {
            model: page.tabList
            delegate: ViewTab {
                id: tab
                required property DetailTab modelData
                objectName: page.name + "Tab_" + tab.modelData.view
                view: tab.modelData.view
                current: page.current
                text: tab.modelData.title
                onPicked: function (view) { page.show(view) }
            }
        }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Theme.gapS
    }
}
