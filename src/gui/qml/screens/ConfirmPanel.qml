pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"

// A side panel's body that asks before a change: what it changes
// (`detail`), a reason (`reasonLabel`, which the step waits for unless
// `reasonRequired` is false), then the step that makes it (`confirmed`),
// usable once `ready`. It closes once the change ends without a refusal
// (`busy` back to false, or never set, and `failure` empty), and says the
// refusal otherwise.
PanelBody {
    id: panel

    property string detail
    property bool busy: false
    property string failure
    property bool ready: true
    property string reasonLabel
    property bool reasonRequired: true
    property int reasonLength: 500
    readonly property string reason: reasonField.text.trim()
    // Whether the change was asked for, and is on its way.
    property bool tried: false
    property bool sent: false

    signal confirmed()

    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (panel.failure === "")
            panel.finished()
    }

    saveUsable: !panel.busy && panel.ready && (panel.reasonLabel === "" || !panel.reasonRequired || panel.reason !== "")
    initialFocus: panel.reasonLabel !== "" ? reasonField : null
    onSaveRequested: {
        panel.tried = true
        panel.sent = true
        panel.confirmed()
        // A change that is never busy has already ended.
        if (!panel.busy)
            Qt.callLater(panel.landed)
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)

    Label {
        objectName: "confirmError"
        visible: panel.tried && panel.failure !== ""
        text: panel.failure
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Label {
        objectName: "confirmDetail"
        visible: panel.detail !== ""
        text: panel.detail
    }
    Field {
        id: reasonField
        objectName: "confirmReason"
        visible: panel.reasonLabel !== ""
        placeholderText: panel.reasonLabel
        maximumLength: panel.reasonLength
        onAccepted: if (panel.saveUsable) panel.saveRequested()
    }
}
