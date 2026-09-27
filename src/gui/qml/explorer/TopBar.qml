pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// The landing's bar over the explorer: the マ mark (the way home), quiet
// history and up buttons, the breadcrumb, and the filter as a hairline field.
// Every crumb opens its location; space and folder crumbs take dropped
// payloads. The mark is not a drop target: nothing lives at the root.
Rectangle {
    id: bar

    property bool narrow: false
    property bool filterOpen: false
    readonly property int control: bar.narrow ? Theme.controlL : Theme.controlM
    readonly property font crumbFont: bar.narrow ? Theme.bodyLarge : Theme.body
    // The trail below the root, which the mark stands for.
    readonly property var crumbs: Session.trail.slice(1)

    signal drawerRequested()
    signal leave()

    function focusFilter() {
        bar.filterOpen = true
        filter.forceActiveFocus()
        filter.selectAll()
    }

    function closeFilter() {
        const wasOpen = bar.narrow && bar.filterOpen
        bar.filterOpen = false
        return wasOpen
    }

    implicitHeight: bar.control + 2 * Theme.gapS
    color: Theme.background

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.gapS
        anchors.rightMargin: Theme.gapS
        spacing: Theme.gapXs

        // The mark and the crumbs are buttons, like Back and Up: they move
        // the explorer, as a file manager's path bar does, and open no page.
        FocusableControl {
            objectName: "homeLink"
            implicitWidth: bar.control
            implicitHeight: bar.control
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Matome")
            onActivated: Session.navigate("root", "")

            Logo {
                anchors.fill: parent
                anchors.margins: Theme.gapXs
            }
        }

        ActionButton {
            objectName: "drawerButton"
            visible: bar.narrow
            implicitHeight: bar.control
            icon: "menu"
            text: qsTr("Browse")
            showLabel: false
            onActivated: bar.drawerRequested()
        }
        CommandButton {
            visible: !bar.narrow
            commandId: "back"
            showLabel: false
        }
        CommandButton {
            visible: !bar.narrow
            commandId: "forward"
            showLabel: false
        }
        CommandButton {
            commandId: "up"
            implicitHeight: bar.control
            showLabel: false
        }

        Flickable {
            id: crumbs
            objectName: "breadcrumb"
            visible: !(bar.narrow && bar.filterOpen)
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.gapXs
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            contentWidth: path.implicitWidth
            interactive: crumbs.contentWidth > crumbs.width
            Accessible.role: Accessible.List
            Accessible.name: qsTr("Location")

            // The last crumbs stay in sight when the path is wider than the bar.
            function showEnd() {
                crumbs.contentX = Math.max(0, crumbs.contentWidth - crumbs.width)
            }
            onContentWidthChanged: crumbs.showEnd()
            onWidthChanged: crumbs.showEnd()

            Row {
                id: path
                height: crumbs.height

                Repeater {
                    model: bar.crumbs

                    delegate: Row {
                        id: crumb
                        required property var modelData
                        required property int index

                        readonly property bool last: crumb.index === bar.crumbs.length - 1
                        readonly property bool holdsFiles: crumb.modelData.kind === "space"
                                                           || crumb.modelData.kind === "folder"
                        readonly property string folderId: crumb.modelData.kind === "folder"
                                                           ? crumb.modelData.id : ""

                        height: path.height

                        Icon {
                            visible: crumb.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconS
                            height: Theme.iconS
                            name: "chevron"
                            color: Theme.textMuted
                        }

                        FocusableControl {
                            id: link
                            objectName: "crumb" + crumb.index
                            anchors.verticalCenter: parent.verticalCenter
                            width: label.implicitWidth + 2 * Theme.gapS
                            height: bar.narrow ? Theme.controlL : Theme.controlS
                            color: drop.containsDrag ? Theme.accentSoft : "transparent"
                            borderColor: drop.containsDrag ? Theme.accentLine : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: crumb.modelData.name
                            onActivated: Session.navigate(crumb.modelData.kind, crumb.modelData.id)
                            onActiveFocusChanged: if (link.activeFocus) {
                                const at = link.mapToItem(path, 0, 0).x
                                if (at < crumbs.contentX)
                                    crumbs.contentX = at
                                else if (at + link.width > crumbs.contentX + crumbs.width)
                                    crumbs.contentX = at + link.width - crumbs.width
                            }

                            RowDropArea {
                                id: drop
                                anchors.fill: parent
                                enabled: crumb.holdsFiles
                                folderId: crumb.folderId
                            }

                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: crumb.modelData.name
                                color: crumb.last ? Theme.textPrimary : Theme.textSecondary
                                font: crumb.last ? Theme.strong(bar.crumbFont) : bar.crumbFont
                            }
                        }
                    }
                }
            }
        }

        Field {
            id: filter
            objectName: "filterField"
            visible: !bar.narrow || bar.filterOpen
            Layout.fillWidth: bar.narrow
            Layout.preferredWidth: bar.narrow ? -1 : Theme.column
            implicitHeight: bar.control
            line: true
            horizontalAlignment: TextInput.AlignLeft
            font: Theme.body
            leftPadding: Theme.iconM + Theme.gapS
            placeholderText: qsTr("Filter")
            text: Session.filter
            onTextEdited: Session.filter = filter.text
            Keys.onDownPressed: bar.leave()
            Keys.onReturnPressed: bar.leave()
            Keys.onEnterPressed: bar.leave()
            Keys.onEscapePressed: {
                if (filter.text !== "")
                    Session.filter = ""
                else
                    bar.leave()
            }
            onActiveFocusChanged: if (!filter.activeFocus && filter.text === "")
                bar.filterOpen = false

            Icon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "filter"
                color: Theme.textMuted
            }
        }

        ActionButton {
            objectName: "filterButton"
            visible: bar.narrow && !bar.filterOpen
            implicitHeight: bar.control
            icon: "filter"
            text: qsTr("Filter")
            showLabel: false
            onActivated: bar.focusFilter()
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
