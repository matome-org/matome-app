pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"

// A side panel's body that names something new, or renames what is named
// `current`: `named` asks for the change, which the panel waits for while
// `busy`. A rename closes the panel once it lands; Core's refusal
// (`failure`) shows in the panel.
PanelBody {
    id: panel

    property string current
    property bool creating: false
    property string placeholder
    // Names the name field.
    property string fieldName: "nameField"
    property int maximumLength: 80
    property bool busy: false
    property string failure
    // Whether the change was asked for, and is on its way.
    property bool tried: false
    property bool sent: false
    readonly property string name: nameField.text.trim()

    signal named(string name)

    function landed() {
        if (panel.busy)
            return
        panel.sent = false
        if (panel.failure === "" && !panel.creating)
            panel.finished()
    }

    saveUsable: !panel.busy && panel.name !== "" && panel.name !== panel.current
    initialFocus: nameField
    onSaveRequested: {
        panel.tried = true
        panel.sent = true
        panel.named(panel.name)
    }
    onBusyChanged: if (panel.sent && !panel.busy) Qt.callLater(panel.landed)
    Component.onCompleted: {
        nameField.text = panel.current
        nameField.selectAll()
    }

    Label {
        objectName: "nameError"
        visible: panel.tried && panel.failure !== ""
        text: panel.failure
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Label { text: qsTr("Name") }
    Field {
        id: nameField
        objectName: panel.fieldName
        placeholderText: panel.placeholder
        maximumLength: panel.maximumLength
        Accessible.name: qsTr("Name")
        onTextChanged: panel.tried = false
        onAccepted: if (panel.saveUsable) panel.saveRequested()
    }
}
