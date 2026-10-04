pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that gives member `memberId`'s managed account a new
// setup code after asking, then shows it once.
PanelBody {
    id: panel

    required property string memberId
    required property string identifier
    property bool tried: false
    readonly property bool issued: (Session.orgAdmin.setupCode.code ?? "") !== ""

    title: qsTr("New setup code")
    subtitle: panel.identifier
    saveText: panel.issued ? "" : qsTr("Issue code")
    saveUsable: !Session.orgAdmin.busy
    cancelText: panel.issued ? qsTr("Close") : qsTr("Cancel")
    objectName: "setupCodePanel"

    onSaveRequested: {
        panel.tried = true
        Session.orgAdmin.issueSetupCode(panel.memberId)
    }
    Component.onCompleted: Session.orgAdmin.clearSetupCode()

    Label {
        objectName: "setupCodeError"
        visible: panel.tried && Session.orgAdmin.errorCode !== ""
        text: Messages.memberFailure(Session.orgAdmin.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Label {
        visible: !panel.issued
        text: qsTr("The current code stops working.")
    }
    SetupCode { identifier: panel.identifier }
}
