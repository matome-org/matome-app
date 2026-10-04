pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import matome
import "../chrome"
import "../screens"
import "../chrome/Commands.js" as Commands
import "../chrome/Messages.js" as Messages

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
    // The access page asked for the page of space `id` in Settings.
    signal spaceSettingsRequested(string id, string name)
    // Whether the access page of what `Session.accessGrants` has open takes
    // the list's place.
    property bool accessOpen: false
    // The folder that Delete asks about.
    property string deleting

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

    // Opens the access side panel `kind`, focus returning to `returnTo`.
    function editAccess(kind, returnTo) {
        panel.show(placePage.view.panels[kind] ?? null, returnTo)
    }
    function closeAccess() {
        panel.close()
        explorer.accessOpen = false
        Session.accessGrants.close()
        list.focusList()
    }

    // Esc closes what floats over the list before it means "up".
    function dismiss() {
        if (panel.shown) {
            panel.dismiss()
            return true
        }
        if (reviewPanel.shown) {
            reviewPanel.dismiss()
            return true
        }
        if (explorer.accessOpen) {
            explorer.closeAccess()
            return true
        }
        if (spacePanel.shown) {
            spacePanel.dismiss()
            return true
        }
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
        const regions = [topBar, sidebar, toolbar, list, accessPage, status].filter(function (region) {
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
        function onPromptNew() {
            if (Session.childKind === "space") spacePanel.openNew()
            else list.beginNew()
        }
        function onPromptRename(currentName) { list.beginRename(currentName) }
        function onPromptUpload() { uploadDialog.open() }
        function onPromptUploadReviews() { reviewPanel.ask() }
        function onPromptDelete(folderName) {
            explorer.deleting = folderName
            panel.show(deletePanel, null)
        }
        function onPromptAccess() {
            panel.close()
            explorer.accessOpen = true
            Qt.callLater(function () { placePage.backButton.forceActiveFocus(Qt.TabFocusReason) })
        }
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
                    visible: !explorer.accessOpen
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
                    visible: !explorer.accessOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    touch: explorer.touch
                    onMenuRequested: function (groups, item, x, y) {
                        menu.show(groups, item, x, y, list.listView)
                    }
                }
                // The access page of the focused folder or document. Keys
                // other than Tab, F6, and Esc stay on it, so none reaches
                // the explorer's commands for the entry behind it.
                Page {
                    id: accessPage
                    objectName: "accessPage"
                    visible: explorer.accessOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.rightMargin: panel.reserve
                    leftMargin: Theme.inset + Theme.gapS
                    rightMargin: Theme.inset + Theme.gapS
                    topMargin: Theme.gapM
                    bottomMargin: Theme.gapM
                    Keys.onPressed: function (event) {
                        event.accepted = ![Qt.Key_Tab, Qt.Key_Backtab, Qt.Key_F6, Qt.Key_Escape].includes(event.key)
                    }
                    PlacePage {
                        id: placePage
                        title: Session.accessGrants.name
                        backText: qsTr("Back to files")
                        narrow: explorer.touch
                        view.outcome: !panel.shown
                        onBackRequested: explorer.closeAccess()
                        onPanelRequested: function (kind, from) { explorer.editAccess(kind, from) }
                        onSourceRequested: function (kind, id, name) {
                            if (kind === "folder") {
                                Session.accessGrants.open("folder", Session.accessGrants.spaceId, id, Messages.placeName(kind, name, ""))
                            } else {
                                explorer.closeAccess()
                                explorer.spaceSettingsRequested(id, name)
                            }
                        }
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
                menu.show([{ title: Session.identifier, ids: ["settings"] },
                           { title: qsTr("Theme"), ids: ["theme-light", "theme-dark", "theme-system"] },
                           { title: qsTr("Language"), ids: Commands.languageIds(Theme.languages) },
                           { title: qsTr("Keyboard"), ids: ["keymap", "sheet"] },
                           { title: "", ids: ["sign-out"] }],
                          item, 0, 0, item)
            }
        }
    }

    // Markdown files going into a space that requires reviews: managed with
    // reviews once they land when checked, asked every time and unchecked
    // at first. Closing without Upload drops them.
    SidePanel {
        id: reviewPanel
        objectName: "reviewUploadPanel"
        property bool manage: false
        property bool sent: false
        readonly property int count: Session.reviewUploads
        function ask() {
            reviewPanel.manage = false
            reviewPanel.sent = false
            reviewPanel.open(null)
        }
        anchors.fill: parent
        narrow: explorer.narrow
        title: qsTr("Manage %n Markdown file(s) with reviews?", "", reviewPanel.count)
        saveText: qsTr("Upload")
        initialFocus: manageRow
        onCountChanged: if (reviewPanel.count === 0) reviewPanel.close()
        onSaveRequested: {
            reviewPanel.sent = true
            Session.uploadStaged(reviewPanel.manage)
            reviewPanel.close()
        }
        onClosed: {
            if (!reviewPanel.sent)
                Session.cancelStaged()
            if (explorer.visible)
                list.focusList()
        }
        NavigationRow {
            id: manageRow
            objectName: "manageUploadsRow"
            text: qsTr("Manage with reviews")
            detail: qsTr("A managed document gets a new version only once a reviewer approves it.")
            icon: reviewPanel.manage ? "checkbox-checked" : "checkbox"
            checkable: true
            selected: reviewPanel.manage
            touch: explorer.touch
            onActivated: reviewPanel.manage = !reviewPanel.manage
        }
    }

    // The access page's side panels, and Delete's question.
    PanelHost {
        id: panel
        objectName: "explorerPanel"
        anchors.fill: parent
        narrow: explorer.narrow
        onClosed: {
            if (!explorer.visible || (panel.returnTo && panel.returnTo.visible))
                return
            if (explorer.accessOpen)
                placePage.backButton.forceActiveFocus(Qt.TabFocusReason)
            else
                list.focusList()
        }
    }
    Component {
        id: deletePanel
        ConfirmPanel {
            objectName: "deleteFolderPanel"
            title: qsTr("Delete folder “%1”?").arg(explorer.deleting)
            detail: qsTr("This cannot be undone.")
            saveText: qsTr("Delete")
            onConfirmed: Session.deleteFocusedFolder()
        }
    }

    // A new space: its name and who reads it, which Core asks at creation.
    SidePanel {
        id: spacePanel
        objectName: "newSpacePanel"
        property string visibility: "private"
        function openNew() {
            spaceName.text = ""
            spacePanel.visibility = "private"
            spacePanel.open(null)
        }
        anchors.fill: parent
        narrow: explorer.narrow
        title: qsTr("New space")
        saveText: qsTr("Create space")
        saveUsable: spaceName.text.trim() !== ""
        initialFocus: spaceName
        onSaveRequested: {
            list.pendingName = spaceName.text.trim()
            Session.createHere(spaceName.text, spacePanel.visibility)
            spacePanel.close()
        }
        onClosed: list.focusList()

        Field {
            id: spaceName
            objectName: "newSpaceName"
            placeholderText: qsTr("Space name")
            maximumLength: 80
            onAccepted: if (spacePanel.saveUsable) spacePanel.saveRequested()
        }
        Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapS; text: qsTr("Visibility") }
        Repeater {
            model: [{ value: "private", label: qsTr("Private"), detail: qsTr("Only people given access") },
                    { value: "public", label: qsTr("Public"), detail: qsTr("Every member except guests reads it") }]
            delegate: NavigationRow {
                id: choice
                required property var modelData
                objectName: "spaceVisibility_" + choice.modelData.value
                touch: explorer.touch
                text: choice.modelData.label
                detail: choice.modelData.detail
                icon: spacePanel.visibility === choice.modelData.value ? "checkbox-checked" : "checkbox"
                checkable: true
                selected: spacePanel.visibility === choice.modelData.value
                onActivated: spacePanel.visibility = choice.modelData.value
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
