pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// The body of a SidePanel: what heads it, what its footer offers, and the
// `step` it is at ("" the first, else a confirmation or a picker). The
// footer's Save asks `saveRequested`; Cancel and Esc go `back` a step
// first. `finished` follows a change that landed and closes the panel.
ColumnLayout {
    id: body

    property string title
    property string subtitle
    property string saveText
    property bool saveUsable: true
    property string cancelText: body.step !== "" ? qsTr("Back") : qsTr("Cancel")
    property Item initialFocus: null
    property string step
    property bool narrow: false

    signal saveRequested()
    signal finished()

    // Steps back to the first step; false when already there.
    function back() {
        if (body.step === "")
            return false
        body.step = ""
        return true
    }

    Layout.fillWidth: true
    spacing: Theme.gapS
}
