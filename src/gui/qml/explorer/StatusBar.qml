pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The landing's footer under the explorer: upload progress and the one line
// of news (an error, a file that did not upload, a pending cut, or an
// undoable trash) in quiet small type, and the account as a quiet link that
// opens settings, theme, language, and sign-out.
Rectangle {
    id: status

    property bool touch: false
    property string errorText

    readonly property string failure: status.errorText !== ""
                                      ? status.errorText
                                      : Messages.uploadFailure(Session.uploadError, Session.uploadErrorName)
    readonly property string message: {
        if (status.failure !== "")
            return status.failure
        if (Session.hasClipboard)
            return qsTr("Cut. Paste moves it into the open folder.")
        if (Session.lastTrashedId !== "")
            return qsTr("Moved to trash. Restore brings it back.")
        return ""
    }

    signal accountMenuRequested(Item item)

    implicitHeight: status.touch ? Theme.controlL : Theme.controlM
    color: Theme.background

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.gapM
        anchors.rightMargin: Theme.gapXs
        spacing: Theme.gapM

        RowLayout {
            objectName: "uploadProgress"
            visible: Session.uploadBusy
            spacing: Theme.gapS
            Accessible.role: Accessible.ProgressBar
            Accessible.name: uploadText.text

            Text {
                id: uploadText
                objectName: "uploadText"
                text: qsTr("Uploading %1 of %2 · %3%").arg(Session.uploadIndex).arg(Session.uploadCount)
                                                       .arg(Math.round(Session.uploadProgress * 100))
                color: Theme.textSecondary
                font: Theme.caption
            }
            Rectangle {
                Layout.preferredWidth: Theme.gapXxl * 2
                Layout.preferredHeight: Theme.gapXs
                radius: height / 2
                color: Theme.subtleFillStrong

                Rectangle {
                    objectName: "uploadBar"
                    width: parent.width * Session.uploadProgress
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                }
            }
        }

        Text {
            objectName: "explorerStatus"
            Layout.fillWidth: true
            text: status.message
            color: status.failure !== "" ? Theme.failed : Theme.textSecondary
            font: Theme.caption
            elide: Text.ElideRight
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        TextLink {
            id: account
            objectName: "accountButton"
            implicitHeight: status.touch ? Theme.controlL : Theme.controlS
            icon: "user"
            text: Session.email
            Accessible.name: qsTr("Account, theme, and language: %1").arg(Session.email)
            onActivated: status.accountMenuRequested(account)
        }
    }
}
