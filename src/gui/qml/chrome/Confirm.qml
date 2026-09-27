pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// Asks before a step that cannot be undone: the question as the title, a
// line on what follows, then Cancel, which has focus, and the step. Esc or a
// click on the scrim cancels. Keys other than Tab stay here, so none reaches
// the window's commands while it asks.
Overlay {
    id: confirm

    property string detail
    property string action

    signal accepted()

    onVisibleChanged: if (confirm.visible)
        cancel.forceActiveFocus()

    Keys.onPressed: function (event) {
        event.accepted = event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab
    }

    Text {
        objectName: "confirmDetail"
        Layout.fillWidth: true
        text: confirm.detail
        color: Theme.textSecondary
        font: Theme.body
        wrapMode: Text.Wrap
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        Layout.topMargin: Theme.gapS
        spacing: Theme.gapS

        ActionButton {
            id: cancel
            objectName: "confirmCancel"
            text: qsTr("Cancel")
            onActivated: confirm.close()
        }
        ActionButton {
            objectName: "confirmAccept"
            primary: true
            text: confirm.action
            onActivated: {
                confirm.close()
                confirm.accepted()
            }
        }
    }
}
