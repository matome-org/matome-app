pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that creates an account the organization manages: a
// username, a name, its built-in organization roles, and an optional
// password. Without one, the one-time setup code shows here once.
PanelBody {
    id: panel

    property bool tried: false
    property bool sent: false
    // The sign-in of the account just created, once Core answered a setup code.
    property string created
    readonly property string username: usernameField.text.trim().toLowerCase()
    readonly property bool ready: /^[a-z0-9._-]{2,64}$/.test(panel.username) && roles.checked.length > 0
                                  && (password.text === "" || (password.text.length >= 8 && password.text.length <= 72))

    title: qsTr("New user")
    saveText: panel.created !== "" ? "" : qsTr("Create user")
    saveUsable: !Session.orgAdmin.busy && panel.ready
    cancelText: panel.created !== "" ? qsTr("Close") : qsTr("Cancel")
    initialFocus: usernameField
    objectName: "newUserPanel"

    onSaveRequested: {
        panel.tried = true
        panel.sent = true
        Session.orgAdmin.createMember(panel.username, nameField.text, roles.checked, password.text)
    }
    Component.onCompleted: Session.orgAdmin.clearSetupCode()

    Connections {
        target: Session.orgAdmin
        function onChangeSaved(notice) {
            if (!panel.sent || notice !== "member_created")
                return
            panel.sent = false
            if ((Session.orgAdmin.setupCode.code ?? "") === "")
                panel.finished()
            else
                panel.created = Session.orgAdmin.slug + "/" + panel.username
        }
    }

    Label {
        objectName: "newUserError"
        visible: panel.tried && Session.orgAdmin.errorCode !== ""
        text: Messages.memberFailure(Session.orgAdmin.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    SetupCode {
        visible: panel.created !== ""
        identifier: panel.created
    }

    ColumnLayout {
        visible: panel.created === ""
        Layout.fillWidth: true
        spacing: Theme.gapS
        Label { text: qsTr("Username") }
        Field {
            id: usernameField
            objectName: "newUserUsernameField"
            placeholderText: qsTr("For example: ana.lima")
            maximumLength: 64
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase
            Accessible.name: qsTr("Username")
            onTextChanged: panel.tried = false
            onAccepted: if (panel.saveUsable) panel.saveRequested()
        }
        Label { text: qsTr("Name") }
        Field {
            id: nameField
            objectName: "newUserNameField"
            placeholderText: qsTr("Optional")
            maximumLength: 160
            Accessible.name: qsTr("Name")
            onAccepted: if (panel.saveUsable) panel.saveRequested()
        }
        Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapS; text: qsTr("Roles") }
        Checklist {
            id: roles
            prefix: "newUserRole_"
            touch: panel.narrow
            checked: ["member"]
            choices: ["admin", "member", "billing", "guest"].map(function (key) {
                return { value: key, label: Messages.roleName(key, key) }
            })
        }
        Label { Layout.topMargin: Theme.gapS; text: qsTr("Password") }
        Field {
            id: password
            objectName: "newUserPasswordField"
            placeholderText: qsTr("Optional, 8 to 72 characters")
            echoMode: TextInput.Password
            maximumLength: 72
            Accessible.name: qsTr("Password")
            onAccepted: if (panel.saveUsable) panel.saveRequested()
        }
    }
}
