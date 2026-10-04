pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that invites someone: an email, the built-in
// organization roles, and optional access to spaces, each checked space
// with the roles checked for it, sent as the invitation's grants.
PanelBody {
    id: editor

    property bool tried: false
    property bool sent: false
    // The roles offered in each checked space, by space id.
    property var access: ({})
    readonly property var offered: Object.keys(editor.access)
    readonly property bool ready: email.text.trim() !== "" && roles.checked.length > 0
                                  && editor.offered.every(function (id) { return editor.access[id].length > 0 })

    function offer(spaceId) {
        const access = Object.assign({}, editor.access)
        if (access[spaceId] === undefined) access[spaceId] = []
        else delete access[spaceId]
        editor.access = access
    }
    function choose(spaceId, roleIds) {
        const access = Object.assign({}, editor.access)
        access[spaceId] = roleIds
        editor.access = access
    }

    title: qsTr("Invite")
    saveText: qsTr("Send invitation")
    saveUsable: !Session.orgAdmin.busy && editor.ready
    initialFocus: email
    objectName: "invitePanel"

    onSaveRequested: {
        editor.tried = true
        editor.sent = true
        Session.orgAdmin.invite(email.text, roles.checked, editor.offered.map(function (id) {
            return { space_id: id, role_ids: editor.access[id] }
        }))
    }

    Connections {
        target: Session.orgAdmin
        function onChangeSaved(notice) {
            if (editor.sent && notice === "invited") {
                editor.sent = false
                editor.finished()
            }
        }
    }

    Label {
        objectName: "inviteError"
        visible: editor.tried && Session.orgAdmin.errorCode !== ""
        text: Messages.inviteFailure(Session.orgAdmin.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Field {
        id: email
        objectName: "invitationEmailField"
        placeholderText: qsTr("Email address")
        inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
        onTextChanged: editor.tried = false
        onAccepted: if (editor.saveUsable) editor.saveRequested()
    }
    Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapS; text: qsTr("Roles") }
    // Core gives any of these on acceptance; only an owner makes an owner.
    Checklist {
        id: roles
        prefix: "inviteOrgRole_"
        touch: editor.narrow
        checked: ["member"]
        choices: ["admin", "member", "billing", "guest"].map(function (key) {
            return { value: key, label: Messages.roleName(key, key) }
        })
    }
    Caption {
        visible: spaces.count > 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.gapS
        text: qsTr("Access to spaces")
    }
    Repeater {
        id: spaces
        model: Session.accessDirectory.grantableRoles.length > 0 ? Session.spaces : null
        delegate: ColumnLayout {
            id: space
            required property string spaceId
            required property string name
            readonly property bool chosen: editor.access[space.spaceId] !== undefined
            onChosenChanged: if (!space.chosen) checks.checked = []
            Layout.fillWidth: true
            spacing: Theme.gapXs
            NavigationRow {
                objectName: "inviteSpace_" + space.spaceId
                touch: editor.narrow
                text: space.name
                icon: space.chosen ? "checkbox-checked" : "checkbox"
                checkable: true
                selected: space.chosen
                onActivated: editor.offer(space.spaceId)
            }
            Checklist {
                id: checks
                visible: space.chosen
                Layout.leftMargin: 2 * Theme.gapM
                prefix: "inviteRole_" + space.spaceId + "_"
                touch: editor.narrow
                searchFrom: 12
                searchLabel: qsTr("Search roles")
                choices: Messages.roleChoices(Session.accessDirectory.grantableRoles)
                onCheckedChanged: if (space.chosen) editor.choose(space.spaceId, checks.checked)
            }
        }
    }
}
