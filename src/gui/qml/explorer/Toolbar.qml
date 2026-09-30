pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"

// The commands that act on the open location. "New" is the one gold pill;
// the rest are quiet icons that name themselves in a tooltip with their key.
// File verbs only show inside a space, where they stay put and dim when they
// cannot run; paste and restore only show when they can. Refresh ends the row.
CommandBar {
    id: toolbar

    readonly property bool files: Session.childKind === "folder"

    CommandButton { commandId: "new"; primary: true }

    BarRule { visible: toolbar.files }
    CommandButton { commandId: "upload"; visible: toolbar.files; showLabel: false }
    CommandButton { commandId: "download"; visible: toolbar.files; showLabel: false }
    CommandButton { commandId: "rename"; visible: toolbar.files; showLabel: false }
    CommandButton { commandId: "trash"; visible: toolbar.files; showLabel: false }

    BarRule { visible: paste.visible || restore.visible }
    CommandButton { id: paste; commandId: "paste"; visible: paste.usable; showLabel: false }
    CommandButton { id: restore; commandId: "restore"; visible: restore.usable; showLabel: false }

    BarRule {}
    CommandButton { commandId: "refresh"; showLabel: false }
}
