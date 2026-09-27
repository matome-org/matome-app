pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// Where the list is: the landing's gold eyebrow (what kind of place, and
// what holds it) over the place's name in the serif title, with the item
// count as a quiet caption on the title's line. Narrow windows set the name
// one step smaller.
ColumnLayout {
    id: header

    property bool narrow: false

    readonly property var here: Session.trail[Session.trail.length - 1]
    readonly property string holder: Session.trail.length > 2 ? Session.trail[Session.trail.length - 2].name : ""
    readonly property string eyebrow: {
        switch (header.here.kind) {
        case "org":
            return qsTr("Organization")
        case "space":
            return qsTr("Space · %1").arg(header.holder)
        case "folder":
            return qsTr("Folder · %1").arg(header.holder)
        default:
            return qsTr("Organizations")
        }
    }

    spacing: Theme.gapXs

    Caption {
        objectName: "locationEyebrow"
        Layout.fillWidth: true
        text: header.eyebrow
        color: Theme.accentText
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: title.implicitHeight

        Text {
            id: title
            objectName: "locationTitle"
            width: Math.min(title.implicitWidth, parent.width - count.implicitWidth - Theme.gapM)
            text: header.here.name
            color: Theme.textPrimary
            font: header.narrow ? Theme.heading : Theme.title
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
            Accessible.name: title.text
        }
        Text {
            id: count
            objectName: "itemCount"
            visible: !Session.loading && Session.locationError === ""
            x: title.width + Theme.gapM
            anchors.baseline: title.baseline
            text: Session.entryCount === 1 ? qsTr("1 item") : qsTr("%1 items").arg(Session.entryCount)
            color: Theme.textMuted
            font: Theme.caption
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }
}
