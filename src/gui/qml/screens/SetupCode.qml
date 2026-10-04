pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// The one-time setup code Core last answered (`Session.orgAdmin.setupCode`)
// for the managed account signing in as `identifier`, selectable to copy.
ColumnLayout {
    id: setup

    required property string identifier
    readonly property var answer: Session.orgAdmin.setupCode

    visible: (setup.answer.code ?? "") !== ""
    Layout.fillWidth: true
    spacing: Theme.gapS

    Caption { Layout.fillWidth: true; text: qsTr("Sign-in") }
    Field {
        objectName: "setupIdentifierField"
        readOnly: true
        text: setup.identifier
        Accessible.name: qsTr("Sign-in")
    }
    Caption { Layout.fillWidth: true; text: qsTr("Setup code") }
    Field {
        objectName: "setupCodeField"
        readOnly: true
        text: setup.answer.code ?? ""
        Accessible.name: qsTr("Setup code")
    }
    Label {
        objectName: "setupCodeExpiry"
        text: qsTr("Shown only once. Expires %1.").arg(setup.answer.expiresAt ?? "")
    }
}
