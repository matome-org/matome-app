pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// The commands that act on the open location. "New" is the one gold pill;
// the rest are quiet icons that name themselves in a tooltip with their key.
// File verbs only show inside a space, where they stay put and dim when they
// cannot run; paste and restore only show when they can. Refresh ends the row.
RowLayout {
    id: toolbar

    readonly property bool files: Session.childKind === "folder"

    // A hairline between groups of buttons.
    component Rule: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: Theme.iconM
        Layout.leftMargin: Theme.gapXs
        Layout.rightMargin: Theme.gapXs
        color: Theme.border
    }

    spacing: Theme.gapXs

    CommandButton { commandId: "new"; primary: true }

    Rule { visible: toolbar.files }
    CommandButton { commandId: "upload"; visible: toolbar.files; showLabel: false }
    CommandButton { commandId: "controlled-docs"; visible: toolbar.files }
    CommandButton { commandId: "download"; visible: toolbar.files; showLabel: false }
    CommandButton { commandId: "rename"; visible: toolbar.files; showLabel: false }
    CommandButton { commandId: "trash"; visible: toolbar.files; showLabel: false }

    Rule { visible: paste.visible || restore.visible }
    CommandButton { id: paste; commandId: "paste"; visible: paste.usable; showLabel: false }
    CommandButton { id: restore; commandId: "restore"; visible: restore.usable; showLabel: false }

    Rule {}
    CommandButton { commandId: "refresh"; showLabel: false }
}
