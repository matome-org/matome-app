pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"

// A group's page (`groupId`): its own commands open the panels that change
// its members, its roles, or its name, or archive it; its tabs are its
// details, its members, its organization roles, and where it has access,
// each opening the item of the row selected.
DetailPage {
    id: page

    required property string groupId
    readonly property var group: Session.accessDirectory.groups.find(function (row) { return row.id === page.groupId }) ?? null
    readonly property string principal: "group:" + page.groupId
    readonly property bool loaded: Session.principalAccess.principal === page.principal
    readonly property bool busy: Session.accessDirectory.busy || Session.principalAccess.busy
    // What Remove takes back on the tab shown.
    readonly property var removal: page.current === "roles" ? roles.removal : places.removal

    signal panelRequested(string kind, Item from)
    signal entryRequested(string section, string id, string name)
    signal placeRequested(var place)

    objectName: "groupPage"
    name: "group"
    backText: qsTr("Groups")
    title: page.group?.name ?? ""
    subject: page.groupId

    commands: [
        ActionButton {
            id: manageMembers
            objectName: "groupManageMembersButton"
            text: qsTr("Manage members")
            icon: "user"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && changingMembers.allowed
            reason: changingMembers.reason
            Gate { id: changingMembers; action: "group.membership_change" }
            onActivated: page.panelRequested("groupMembers", manageMembers)
        },
        ActionButton {
            id: manageRoles
            objectName: "groupManageRolesButton"
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
            id: rename
            objectName: "groupRenameButton"
            text: qsTr("Rename")
            icon: "rename"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && renaming.allowed
            reason: renaming.reason
            onActivated: page.panelRequested("renameGroup", rename)
            Gate { id: renaming; action: "group.update" }
        },
        ActionButton {
            id: archive
            objectName: "groupArchiveButton"
            text: qsTr("Archive")
            icon: "trash"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !page.busy && archiving.allowed
            reason: archiving.reason
            onActivated: page.panelRequested("archiveGroup", archive)
            Gate { id: archiving; action: "group.archive" }
        }
    ]

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: [{ name: "groupName", label: qsTr("Name"), value: page.group?.name ?? "" },
                    { name: "groupSize", label: qsTr("Members"), value: qsTr("%n member(s)", "", (page.group?.members ?? []).length) }]
        }
    }

    DetailTab {
        view: "members"
        title: qsTr("Members")

        commands: [
            ActionButton {
                objectName: "groupOpenMemberButton"
                text: qsTr("Open")
                icon: "forward"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: people.selectedRow !== null
                reason: qsTr("Select one row.")
                onActivated: page.entryRequested("members", people.selectedRow.id, people.selectedRow.label)
            }
        ]

        Table {
            id: people
            objectName: "groupMembers"
            label: qsTr("Members")
            prefix: "groupPerson_"
            touch: page.narrow
            columns: [{ title: qsTr("Name"), share: 1 }]
            model: page.group?.members ?? []
            cells: function (person) { return [person.label || qsTr("Former member")] }
            emptyText: qsTr("None.")
            onOpened: function (person) { page.entryRequested("members", person.id, person.label) }
        }
    }

    HeldRoles {
        id: roles
        principal: page.principal
        touch: page.narrow
        onPanelRequested: function (kind, from) { page.panelRequested(kind, from) }
        onEntryRequested: function (section, id, name) { page.entryRequested(section, id, name) }
    }

    HeldPlaces {
        id: places
        principal: page.principal
        touch: page.narrow
        onPanelRequested: function (kind, from) { page.panelRequested(kind, from) }
        onPlaceRequested: function (place) { page.placeRequested(place) }
    }
}
