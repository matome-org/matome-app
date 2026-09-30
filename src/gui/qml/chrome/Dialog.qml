pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A form over the window: the title, the fields (this item's children),
// then Cancel and the step. `initialFocus` takes focus on open, Cancel when
// unset. The step runs only while `ready`; Esc or a click on the scrim
// cancels. Keys other than Tab stay here, so none reaches the window's
// commands while it asks.
Overlay {
    id: dialog

    property string action
    property bool ready: true
    property Item initialFocus: null
    default property alias fields: body.data

    signal accepted()

    function accept() {
        if (!dialog.ready)
            return
        dialog.close()
        dialog.accepted()
    }

    onVisibleChanged: if (dialog.visible)
        (dialog.initialFocus ?? cancel).forceActiveFocus()

    Keys.onPressed: function (event) {
        event.accepted = event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Theme.gapS
    }
    RowLayout {
        Layout.alignment: Qt.AlignRight
        Layout.topMargin: Theme.gapS
        spacing: Theme.gapS

        ActionButton {
            id: cancel
            objectName: "confirmCancel"
            text: qsTr("Cancel")
            onActivated: dialog.close()
        }
        ActionButton {
            objectName: "confirmAccept"
            primary: true
            text: dialog.action
            usable: dialog.ready
            onActivated: dialog.accept()
        }
    }
}
