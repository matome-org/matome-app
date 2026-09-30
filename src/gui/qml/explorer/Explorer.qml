pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Commands.js" as Commands

// The signed-in window: a file explorer over organizations, spaces, and
// folders. Top bar, sidebar, toolbar, list, status bar, in tab order; the
// location header shares its line with the toolbar. Below 600 px the sidebar
// becomes a drawer and the toolbar a floating button.
FocusScope {
    id: explorer

    readonly property bool narrow: explorer.width < 600
    readonly property bool touch: explorer.narrow || Qt.platform.os === "android"
    property bool drawerOpen: false
    property real sidebarWidth: Theme.column

    signal commandChosen(string id)

    function focusDefault() {
        list.focusList()
    }

    function openDrawer() {
        explorer.drawerOpen = true
        sidebar.focusFirst()
    }

    function closeDrawer() {
        explorer.drawerOpen = false
        list.focusList()
    }

    // Esc closes what floats over the list before it means "up".
    function dismiss() {
        if (explorer.drawerOpen) {
            explorer.closeDrawer()
            return true
        }
        if (topBar.closeFilter()) {
            list.focusList()
            return true
        }
        return false
    }

    // F6 and Shift+F6: focus the first control of the next visible region
    // that has one, in tab order.
    function cycleRegion(step) {
        const regions = [topBar, sidebar, toolbar, list, status].filter(function (region) {
            return region.visible
        })
        const count = regions.length
        const at = regions.findIndex(function (region) {
            return explorer.holds(region, explorer.Window.activeFocusItem)
        })
        for (let i = 1; i <= count; ++i) {
            const region = regions[((at + step * i) % count + count) % count]
            const first = region.nextItemInFocusChain(true)
            if (explorer.holds(region, first)) {
                first.forceActiveFocus()
                return
            }
        }
    }

    function holds(region, item) {
        for (let at = item; at; at = at.parent) {
            if (at === region)
                return true
        }
        return false
    }

    onNarrowChanged: explorer.drawerOpen = false
    onVisibleChanged: if (explorer.visible)
        explorer.focusDefault()

    Connections {
        target: Session
        function onPromptNew() { list.beginNew() }
        function onPromptRename(currentName) { list.beginRename(currentName) }
        function onPromptUpload() { uploadDialog.open() }
        function onFocusFilter() { topBar.focusFilter() }
        function onDownloadReady(file) { Qt.openUrlExternally(file) }
        function onCycleRegion(step) { explorer.cycleRegion(step) }
    }

    FileDialog {
        id: uploadDialog
        objectName: "uploadDialog"
        title: qsTr("Upload files")
        fileMode: FileDialog.OpenFiles
        onAccepted: Session.uploadUrls(uploadDialog.selectedFiles)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            id: topBar
            objectName: "topBar"
            Layout.fillWidth: true
            narrow: explorer.narrow
            onDrawerRequested: explorer.drawerOpen ? explorer.closeDrawer() : explorer.openDrawer()
            onLeave: list.focusList()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Sidebar {
                id: sidebar
                objectName: "sidebar"
                z: 2
                width: explorer.narrow ? Math.min(300, parent.width * 0.85) : explorer.sidebarWidth
                height: parent.height
                x: !explorer.narrow || explorer.drawerOpen ? 0 : -sidebar.width
                visible: !explorer.narrow || explorer.drawerOpen || sidebar.x > -sidebar.width
                touch: explorer.touch
                onNavigated: if (explorer.narrow)
                    explorer.closeDrawer()

                Behavior on x {
                    enabled: explorer.narrow
                    Ease {}
                }

                MouseArea {
                    id: handle
                    objectName: "sidebarHandle"
                    visible: !explorer.narrow
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: -handle.width / 2
                    width: Theme.gapS
                    cursorShape: Qt.SplitHCursor
                    onPositionChanged: function (mouse) {
                        if (handle.pressed)
                            explorer.sidebarWidth = Math.max(180, Math.min(420,
                                handle.mapToItem(sidebar.parent, mouse.x, 0).x))
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: explorer.narrow ? 0 : sidebar.width
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    implicitHeight: head.implicitHeight + Theme.gapM + Theme.gapS

                    RowLayout {
                        id: head
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Theme.inset + Theme.gapS
                        anchors.rightMargin: Theme.inset + Theme.gapS
                        anchors.bottomMargin: Theme.gapS
                        spacing: Theme.gapL

                        LocationHeader {
                            objectName: "locationHeader"
                            Layout.fillWidth: true
                            narrow: explorer.narrow
                        }
                        Toolbar {
                            id: toolbar
                            objectName: "toolbar"
                            visible: !explorer.narrow
                            Layout.alignment: Qt.AlignBottom
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

                EntryList {
                    id: list
                    objectName: "entryPane"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    touch: explorer.touch
                    onMenuRequested: function (groups, item, x, y) {
                        menu.show(groups, item, x, y, list.listView)
                    }
                }
            }

            ActionButton {
                id: fab
                objectName: "fabButton"
                visible: explorer.narrow
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.gapL
                implicitWidth: Theme.controlXl
                implicitHeight: Theme.controlXl
                primary: true
                icon: "new"
                text: qsTr("New or upload")
                showLabel: false
                onActivated: menu.show([{ title: "", ids: ["new", "upload", "paste"] }], fab, 0, 0, list.listView)
            }

            Rectangle {
                objectName: "drawerScrim"
                anchors.fill: parent
                z: 1
                visible: explorer.narrow && explorer.drawerOpen
                color: Theme.dark ? Theme.fill(Theme.background, 0.66) : Theme.fill(Theme.textPrimary, 0.32)

                TapHandler {
                    onTapped: explorer.closeDrawer()
                }
            }
        }

        StatusBar {
            id: status
            objectName: "statusBar"
            Layout.fillWidth: true
            touch: explorer.touch
            errorText: Session.entryCount > 0 ? list.errorText : ""
            onAccountMenuRequested: function (item) {
                menu.show([{ title: Session.email, ids: ["settings"] },
                           { title: qsTr("Theme"), ids: ["theme-light", "theme-dark", "theme-system"] },
                           { title: qsTr("Language"), ids: Commands.languageIds(Theme.languages) },
                           { title: qsTr("Keyboard"), ids: ["keymap", "sheet"] },
                           { title: "", ids: ["sign-out"] }],
                          item, 0, 0, item)
            }
        }
    }

    ContextMenu {
        id: menu
        commands: Session.commandList
        touch: explorer.touch
        onChosen: function (id) { explorer.commandChosen(id) }
    }
}
