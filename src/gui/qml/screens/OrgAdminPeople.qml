pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

ListView {
    id: people

    property bool invitations: false
    property bool narrow: false

    signal roleRequested(string personId, string email, string role)
    signal removalRequested(string personId, string email)
    signal cancellationRequested(string personId, string email)

    model: people.invitations ? Session.orgAdmin.invitations : Session.orgAdmin.members
    clip: true
    spacing: Theme.gapS
    boundsBehavior: Flickable.StopAtBounds
    C.ScrollBar.vertical: ThinScrollBar {}

    delegate: Rectangle {
        id: row
        required property string personId
        required property string email
        required property string roleName
        required property string status
        required property string expiresAt

        width: people.width
        implicitHeight: content.implicitHeight + 2 * Theme.gapM
        color: Theme.surface
        radius: Theme.rounding
        border.color: Theme.border

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.gapM
            spacing: Theme.gapS

            Text {
                Layout.fillWidth: true
                text: row.email
                font: Theme.strong(Theme.body)
                color: Theme.textPrimary
                elide: Text.ElideRight
            }
            Text {
                visible: people.invitations
                Layout.fillWidth: true
                text: Messages.invitationState(row.status)
                      + (row.expiresAt !== "" ? " · " + qsTr("Expires %1").arg(row.expiresAt) : "")
                font: Theme.caption
                color: Theme.textSecondary
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gapS

                RolePicker {
                    id: role
                    Layout.fillWidth: true
                    roleName: row.roleName
                    enabled: !people.invitations && !Session.orgAdmin.busy
                }
                ActionButton {
                    objectName: "changeRoleButton"
                    visible: !people.invitations
                    text: qsTr("Apply")
                    icon: "check"
                    showLabel: !people.narrow
                    tip: text
                    usable: !Session.orgAdmin.busy && role.currentValue !== row.roleName
                    onActivated: people.roleRequested(row.personId, row.email, role.currentValue)
                }
                ActionButton {
                    objectName: "removeMemberButton"
                    visible: !people.invitations
                    text: qsTr("Remove")
                    icon: "trash"
                    showLabel: !people.narrow
                    tip: text
                    usable: !Session.orgAdmin.busy
                    onActivated: people.removalRequested(row.personId, row.email)
                }
                ActionButton {
                    objectName: "cancelInvitationButton"
                    visible: people.invitations && row.status === "pending"
                    text: qsTr("Cancel invitation")
                    icon: "close"
                    showLabel: !people.narrow
                    tip: text
                    usable: !Session.orgAdmin.busy
                    onActivated: people.cancellationRequested(row.personId, row.email)
                }
            }
        }
    }
}
