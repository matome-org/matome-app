pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// Asks before a step that cannot be undone: the question as the title, a
// line on what follows, then Cancel, which has focus, and the step. With a
// `reasonLabel`, a reason field comes first and has focus; the step waits
// for it unless `reasonRequired` is false. Enter there takes the step.
Dialog {
    id: confirm

    property string detail
    property string reasonLabel
    property bool reasonRequired: true
    property int reasonLength: 500
    readonly property string reason: reasonField.text.trim()

    ready: confirm.reasonLabel === "" || !confirm.reasonRequired || confirm.reason !== ""
    initialFocus: confirm.reasonLabel !== "" ? reasonField : null

    onVisibleChanged: if (confirm.visible)
        reasonField.clear()

    Text {
        objectName: "confirmDetail"
        Layout.fillWidth: true
        visible: confirm.detail !== ""
        text: confirm.detail
        color: Theme.textSecondary
        font: Theme.body
        wrapMode: Text.Wrap
    }

    Field {
        id: reasonField
        objectName: "confirmReason"
        visible: confirm.reasonLabel !== ""
        Layout.topMargin: Theme.gapS
        placeholderText: confirm.reasonLabel
        maximumLength: confirm.reasonLength
        onAccepted: confirm.accept()
    }
}
