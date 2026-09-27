import QtQuick
import matome

// Takes a dragged row into the folder `folderId` (empty: the space's root).
// A row Session would refuse there is turned away as it enters.
DropArea {
    id: area

    property string folderId

    onEntered: function (drag) {
        if (!Session.acceptsDrop(area.folderId, (drag.source as EntryRow)?.payload ?? ""))
            drag.accepted = false
    }
    onDropped: function (event) {
        Session.dropPayload(area.folderId, (event.source as EntryRow).payload)
        event.acceptProposedAction()
    }
}
