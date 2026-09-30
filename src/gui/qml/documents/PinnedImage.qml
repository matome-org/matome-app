pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// One image a version pins, signed through `via`, over a caption.
ColumnLayout {
    id: pinned

    property string via
    property string documentId
    property string versionId
    property string caption

    spacing: Theme.gapXs
    Image {
        visible: pinned.versionId !== ""
        source: pinned.versionId !== "" ? Session.assets.source(Session.currentOrgId, Session.currentSpaceId, pinned.via,
                                                                pinned.documentId, pinned.versionId, 240) : ""
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        Layout.maximumWidth: 240
        Layout.maximumHeight: 180
    }
    Caption { Layout.fillWidth: true; text: pinned.caption }
}
