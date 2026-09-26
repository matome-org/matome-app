pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"

// Organizations, the spaces of the open organization, and the folder tree of
// the open space, each one SidebarSection.
Rectangle {
    id: sidebar

    property bool touch: false

    signal navigated()

    function focusFirst() {
        for (const section of [folders, spaces, orgs]) {
            if (section.visible && section.list.count > 0) {
                section.list.forceActiveFocus()
                return
            }
        }
    }

    function reveal(item) {
        if (!item)
            return
        const top = item.mapToItem(column, 0, 0).y
        if (top < flick.contentY)
            flick.contentY = top
        else if (top + item.height > flick.contentY + flick.height)
            flick.contentY = top + item.height - flick.height
    }

    function go(kind, id) {
        Session.navigate(kind, id)
        sidebar.navigated()
    }

    color: Theme.surface

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        C.ScrollBar.vertical: ThinScrollBar {}

        ColumnLayout {
            id: column
            width: flick.width
            spacing: 0

            SidebarSection {
                id: orgs
                Layout.fillWidth: true
                title: qsTr("Organizations")
                model: Session.organizations
                kind: "org"
                idRole: "orgId"
                rowName: "orgRow"
                listName: "orgList"
                currentId: Session.currentOrgId
                ancestral: Session.currentSpaceId !== ""
                touch: sidebar.touch
                onOpened: function (id) { sidebar.go("org", id) }
                onMoved: function (row) { sidebar.reveal(row) }
            }
            SidebarSection {
                id: spaces
                visible: Session.currentOrgId !== ""
                Layout.fillWidth: true
                title: qsTr("Spaces")
                model: Session.spaces
                kind: "space"
                idRole: "spaceId"
                rowName: "spaceRow"
                listName: "spaceList"
                currentId: Session.currentSpaceId
                // The open space heads the folder tree below.
                ancestral: true
                touch: sidebar.touch
                onOpened: function (id) { sidebar.go("space", id) }
                onMoved: function (row) { sidebar.reveal(row) }
            }
            SidebarSection {
                id: folders
                visible: Session.currentSpaceId !== ""
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.gapM
                title: qsTr("Folders")
                model: Session.folderTree
                kind: "folder"
                idRole: "folderId"
                rowName: "treeRow"
                listName: "folderTree"
                tree: true
                touch: sidebar.touch
                onOpened: function (id) { sidebar.go("folder", id) }
                onMoved: function (row) { sidebar.reveal(row) }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: Theme.border
    }
}
