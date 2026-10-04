pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// An invitation's page (`invitationId`): its own command cancels it while
// pending; its tabs are its state and the organization roles it gives,
// and the roles it gives in each space, the one selected opening there.
DetailPage {
    id: page

    required property string invitationId
    readonly property var invitation: Session.orgAdmin.active ? Session.orgAdmin.invitation(page.invitationId) : ({})

    signal panelRequested(string kind, Item from)
    signal entryRequested(string section, string id, string name)

    // The names of the roles `ids` name, as the directory lists them.
    function roleNames(ids) {
        return ids.map(function (id) {
            const role = Session.accessDirectory.roles.find(function (row) { return row.id === id })
            return role ? Messages.roleName(role.key, role.name) : qsTr("A former role")
        }).join(", ")
    }

    objectName: "invitationPage"
    name: "invitation"
    backText: qsTr("People")
    title: page.invitation.label ?? ""
    subject: page.invitationId

    commands: [
        ActionButton {
            id: cancel
            objectName: "cancelInvitationButton"
            text: qsTr("Cancel invitation")
            icon: "trash"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !Session.orgAdmin.busy && page.invitation.status === "pending" && cancelling.allowed
            reason: page.invitation.status !== "pending" ? qsTr("It is no longer pending.") : cancelling.reason
            onActivated: page.panelRequested("cancelInvitation", cancel)
            Gate { id: cancelling; action: "membership.invite_cancel" }
        }
    ]

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: [{ name: "invitationState", label: qsTr("Status"), value: Messages.invitationState(page.invitation.status ?? "") },
                    { name: "invitationExpiry", label: qsTr("Expires"), value: page.invitation.expiresAt ?? "" },
                    { name: "invitationRoles", label: qsTr("Roles"), value: Messages.roleNames(page.invitation.roles ?? []) }]
        }
    }

    DetailTab {
        view: "spaces"
        title: qsTr("Access to spaces")

        commands: [
            ActionButton {
                objectName: "invitationOpenSpaceButton"
                text: qsTr("Open")
                icon: "forward"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: spaces.selectedRow !== null
                reason: qsTr("Select one row.")
                onActivated: page.entryRequested("spaces", spaces.selectedRow.spaceId, spaces.selectedRow.name)
            }
        ]

        Table {
            id: spaces
            objectName: "invitationSpaces"
            label: qsTr("Access to spaces")
            prefix: "invitationSpace_"
            touch: page.narrow
            columns: [{ title: qsTr("Space"), share: 1 }, { title: qsTr("Roles"), share: 2 }]
            model: page.invitation.spaces ?? []
            keyOf: function (row) { return row.spaceId }
            cells: function (row) { return [Messages.placeName("space", row.name, ""), page.roleNames(row.roleIds)] }
            emptyText: qsTr("None.")
            onOpened: function (row) { page.entryRequested("spaces", row.spaceId, row.name) }
        }
    }
}
