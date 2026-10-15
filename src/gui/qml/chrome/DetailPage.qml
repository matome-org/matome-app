pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// An item's page: the way back to its list and the item's name with its
// state (`chips`), one command bar, the lines that say how it stands
// (`notes`), then the row of its tabs (its DetailTab children that are
// `available`) over the tab shown. The bar holds the item's own commands
// (`commands`, then each tab's `pageCommands`) and, after a hairline, the
// shown tab's `commands`. When the name and the bar do not fit on one line,
// the bar goes below the name; when the bar's labels do not fit the width,
// its commands show only their icons (`compact`). Given a height, the tab
// shown fills what is left of it.
ColumnLayout {
    id: page

    // Prefixes the object names of its back button, title, and tabs.
    property string name
    property string backText
    property string title
    property var chips: []
    property bool narrow: false
    // What the page shows: another one opens on the tab `start`, else on
    // the first.
    property var subject
    property string start
    property string current
    property alias commands: itemRow.data
    property alias notes: noteColumn.data
    default property alias tabs: body.data
    readonly property alias backButton: back
    readonly property var tabList: body.children.filter(function (child) { return child instanceof DetailTab })
    readonly property real labelled: page.labelledWidth(bar)
    readonly property bool compact: page.narrow || page.labelled > page.width
    readonly property bool stacked: back.implicitWidth + titleMetrics.advanceWidth + chipRow.implicitWidth
                                    + (page.compact ? bar.implicitWidth : page.labelled) + 3 * Theme.gapL > page.width

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
            const segmented = child as SegmentedSwitch
            const nested = child as RowLayout
            width += button ? button.labelledWidth : segmented ? segmented.labelledWidth
                   : nested ? page.labelledWidth(nested) : child.implicitWidth
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
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gapS
                Text {
                    objectName: page.name + "Title"
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.ceil(implicitWidth)
                    text: page.title
                    font: Theme.heading
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Row {
                    id: chipRow
                    objectName: page.name + "Chips"
                    spacing: Theme.gapXs
                    Repeater {
                        model: page.chips
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            implicitWidth: chipText.implicitWidth + 2 * Theme.gapS
                            implicitHeight: chipText.implicitHeight + Theme.gapXs
                            radius: height / 2
                            color: Theme.subtleFill
                            border.color: Theme.border
                            Accessible.role: Accessible.StaticText
                            Accessible.name: chip.modelData
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: chip.modelData
                                font: Theme.caption
                                color: Theme.textSecondary
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
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

    ColumnLayout {
        id: noteColumn
        Layout.fillWidth: true
        Layout.fillHeight: false
        // No room for the lines while none shows.
        Layout.topMargin: noteColumn.implicitHeight > 0 ? 0 : -page.spacing
        spacing: Theme.gapXs
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.gapXs
        Accessible.role: Accessible.PageTabList
        Accessible.name: page.title

        Repeater {
            model: page.tabList.filter(function (tab) { return tab.available })
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
        Layout.fillHeight: true
        spacing: Theme.gapS
    }
}
