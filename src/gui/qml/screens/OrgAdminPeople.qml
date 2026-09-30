pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// Members or invitations as a list to select from: email over role and
// state. The Settings command bar acts on the person under the cursor;
// Enter or a double tap asks for its main verb (`opened`).
CursorList {
    id: people

    property bool invitations: false
    property bool touch: false
    readonly property PersonRow current: people.currentItem as PersonRow
    readonly property string currentId: people.current?.personId ?? ""
    readonly property string currentEmail: people.current?.email ?? ""
    readonly property string currentRole: people.current?.roleName ?? ""
    readonly property string currentStatus: people.current?.status ?? ""

    signal opened()

    function roleLabel(value) {
        return Session.orgAdmin.roles.find(function (role) { return role.value === value })?.label ?? value
    }

    component PersonRow: ListRow {
        required property string personId
        required property string email
        required property string roleName
        required property string status
        required property string expiresAt
    }

    model: people.invitations ? Session.orgAdmin.invitations : Session.orgAdmin.members
    clip: true
    activeFocusOnTab: true
    spacing: Theme.gapS
    rowHeight: people.touch ? Theme.rowTouch : Theme.controlM
    C.ScrollBar.vertical: ThinScrollBar {}
    Accessible.role: Accessible.List
    Accessible.name: people.invitations ? qsTr("Invitations") : qsTr("Members")

    delegate: PersonRow {
        id: row
        required property int index
        objectName: (people.invitations ? "invitation_" : "member_") + row.personId
        view: people
        touch: people.touch
        cursor: people.currentIndex === row.index
        selected: row.cursor
        title: row.email
        detail: people.invitations
                ? [people.roleLabel(row.roleName), Messages.invitationState(row.status),
                   row.expiresAt !== "" ? qsTr("Expires %1").arg(row.expiresAt) : ""]
                  .filter(function (part) { return part !== "" }).join(" · ")
                : people.roleLabel(row.roleName)
        onClicked: people.currentIndex = row.index
        onActivated: {
            people.currentIndex = row.index
            people.opened()
        }
    }
}
