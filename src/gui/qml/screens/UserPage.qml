pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"

// A member's page (`memberId`): its own commands open the panels that
// change their roles and groups, issue a setup code, or remove them; its
// tabs are how they sign in, their organization roles, their groups, and
// where they have access, each opening the item of the row selected.
DetailPage {
    id: page

    required property string memberId
    readonly property var member: Session.accessDirectory.members.find(function (row) { return row.id === page.memberId }) ?? null
    readonly property string principal: "user:" + page.memberId
    readonly property bool loaded: Session.principalAccess.principal === page.principal
    readonly property string identifier: page.member === null ? ""
                                       : page.member.email !== "" ? page.member.email
                                       : Session.orgAdmin.slug + "/" + page.member.username
    readonly property var groups: Session.accessDirectory.groups.filter(function (group) {
        return group.members.some(function (person) { return person.id === page.memberId })
    })
    readonly property bool busy: Session.orgAdmin.busy || Session.accessDirectory.busy || Session.principalAccess.busy
    // What Remove takes back on the tab shown.
    readonly property var removal: page.current === "roles" ? roles.removal : places.removal

    // Asks AccessAdmin for the panel `kind`, focus returning to `from`.
    signal panelRequested(string kind, Item from)
    signal entryRequested(string section, string id, string name)
    signal placeRequested(var place)

    objectName: "userPage"
    name: "user"
    backText: qsTr("People")
    title: page.member?.label ?? ""
    subject: page.memberId

    commands: [
        ActionButton {
            id: manageRoles
            objectName: "userManageRolesButton"
            text: qsTr("Manage roles")
            icon: "role"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: page.loaded && !page.busy && granting.allowed
            reason: granting.reason
            onActivated: page.panelRequested("roles", manageRoles)
            Gate { id: granting; action: "principal_role.grant" }
        },
        ActionButton {
            id: manageGroups
            objectName: "userManageGroupsButton"
            text: qsTr("Manage groups")
            icon: "group"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && changingGroups.allowed
            reason: changingGroups.reason
            onActivated: page.panelRequested("groups", manageGroups)
            Gate { id: changingGroups; action: "group.membership_change" }
        },
        ActionButton {
            id: setupCode
            objectName: "userSetupCodeButton"
            text: qsTr("New setup code")
            icon: "access"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && page.member?.managed === true && creating.allowed
            reason: page.member?.managed === true ? creating.reason : qsTr("Only accounts the organization manages sign in with a setup code.")
            Gate { id: creating; action: "membership.create" }
            onActivated: page.panelRequested("setupCode", setupCode)
        },
        ActionButton {
            id: remove
            objectName: "userRemoveButton"
            text: qsTr("Remove from organization")
            icon: "trash"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && page.loaded
            onActivated: page.panelRequested("removeMember", remove)
        }
    ]

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: [{ name: "userIdentifier", label: qsTr("Sign-in"), value: page.identifier },
                    { name: "userName", label: qsTr("Name"), value: page.member?.name ?? "" },
                    { name: "userKind", label: qsTr("Account"),
                      value: page.member === null ? "" : page.member.managed ? qsTr("Managed by the organization") : qsTr("Personal") }]
        }
    }

    HeldRoles {
        id: roles
        principal: page.principal
        touch: page.narrow
        onPanelRequested: function (kind, from) { page.panelRequested(kind, from) }
        onEntryRequested: function (section, id, name) { page.entryRequested(section, id, name) }
    }

    DetailTab {
        view: "groups"
        title: qsTr("Groups")

        commands: [
            ActionButton {
                objectName: "userOpenGroupButton"
                text: qsTr("Open")
                icon: "forward"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: groupTable.selectedRow !== null
                reason: qsTr("Select one row.")
                onActivated: page.entryRequested("groups", groupTable.selectedRow.id, groupTable.selectedRow.name)
            }
        ]

        Table {
            id: groupTable
            objectName: "userGroups"
            label: qsTr("Groups")
            prefix: "userGroup_"
            touch: page.narrow
            columns: [{ title: qsTr("Group"), share: 1 }]
            model: page.groups
            cells: function (group) { return [group.name] }
            emptyText: qsTr("None.")
            onOpened: function (group) { page.entryRequested("groups", group.id, group.name) }
        }
    }

    HeldPlaces {
        id: places
        principal: page.principal
        touch: page.narrow
        onPanelRequested: function (kind, from) { page.panelRequested(kind, from) }
        onPlaceRequested: function (place) { page.placeRequested(place) }
    }
}
