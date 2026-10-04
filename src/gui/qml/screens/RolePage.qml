pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A role's page (`roleId`): its own commands open the panels that change,
// copy, or archive it; its tabs are its details, what it allows by area,
// and who holds it as `Session.roleHolders` read it: each person, group, or
// role it is given to and where, whose commands give it to more people,
// take it back, and open the holder of the selected row.
DetailPage {
    id: page

    required property string roleId
    readonly property var role: Session.accessDirectory.roles.find(function (row) { return row.id === page.roleId }) ?? null
    readonly property bool loaded: Session.roleHolders.roleId === page.roleId
    readonly property bool custom: page.role?.custom === true
    // It is given on places, never across the organization.
    readonly property bool placed: page.role?.placeOnly === true || page.role?.appliesTo === "space"
    property alias holders: holderTable

    signal panelRequested(string kind, Item from)
    signal entryRequested(string section, string id, string name)

    function openHolder(holder) {
        if (holder.principalKind === "role")
            page.entryRequested("roles", holder.principal.split(":")[1], Messages.grantHolder(holder))
        else
            page.entryRequested(holder.principalKind === "group" ? "groups" : "members", holder.principal.split(":")[1],
                                holder.principalName)
    }

    objectName: "rolePage"
    name: "role"
    backText: qsTr("Roles")
    title: page.role === null ? "" : Messages.roleName(page.role.key, page.role.name)
    subject: page.roleId

    commands: [
        ActionButton {
            id: edit
            objectName: "roleEditButton"
            text: qsTr("Edit permissions")
            icon: "rename"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !Session.accessDirectory.busy && page.custom && updating.allowed
            reason: page.custom ? updating.reason : qsTr("Only custom roles can be edited. Copy it to make one.")
            Gate { id: updating; action: "role.update" }
            onActivated: page.panelRequested("editRole", edit)
        },
        ActionButton {
            id: copy
            objectName: "roleCopyButton"
            text: qsTr("Copy")
            icon: "new"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !Session.accessDirectory.busy && copying.allowed
            reason: copying.reason
            onActivated: page.panelRequested("copyRole", copy)
            Gate { id: copying; action: "role.create" }
        },
        ActionButton {
            id: archive
            objectName: "roleArchiveButton"
            text: qsTr("Archive")
            icon: "trash"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !Session.accessDirectory.busy && page.custom && archiving.allowed
            reason: page.custom ? archiving.reason : qsTr("Only custom roles can be archived.")
            Gate { id: archiving; action: "role.archive" }
            onActivated: page.panelRequested("archiveRole", archive)
        }
    ]

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: page.role === null ? [] : [
                { name: "roleKind", label: qsTr("Type"), value: Messages.roleKind(page.role) },
                { name: "roleScope", label: qsTr("Applies to"), value: Messages.roleScope(page.role.appliesTo) },
                { name: "roleSize", label: qsTr("Permissions"), value: qsTr("%n permission(s)", "", page.role.actions.length) }]
        }
    }

    DetailTab {
        view: "permissions"
        title: qsTr("Permissions")
        Table {
            objectName: "rolePermissions"
            label: qsTr("Permissions")
            prefix: "rolePermission_"
            touch: page.narrow
            columns: [{ title: qsTr("Area"), share: 1 }, { title: qsTr("Permission"), share: 2 }]
            // Grouped by area, in the order each area first comes.
            model: Messages.permissionGroups(Messages.actionRows(page.role?.actions ?? []))
                   .reduce(function (all, group) { return all.concat(group.actions) }, [])
            keyOf: function (action) { return action.key }
            cells: function (action) { return [Messages.actionArea(action.area), Messages.actionLabel(action)] }
            emptyText: qsTr("None.")
        }
    }

    DetailTab {
        view: "holders"
        title: qsTr("Assigned to")

        commands: [
            ActionButton {
                id: addPeople
                objectName: "roleAddPeopleButton"
                text: qsTr("Add people")
                icon: "user"
                primary: true
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: page.loaded && !Session.roleHolders.busy && (page.placed || assigning.allowed)
                reason: page.placed ? "" : assigning.reason
                onActivated: page.panelRequested("addPeople", addPeople)
                Gate { id: assigning; action: "principal_role.grant" }
            },
            ActionButton {
                id: remove
                objectName: "roleRemoveHoldersButton"
                text: qsTr("Remove")
                icon: "trash"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: page.loaded && !Session.roleHolders.busy && holderTable.selectedRows.length > 0
                reason: holderTable.selectedRows.length === 0 ? qsTr("Select what to remove.") : ""
                onActivated: page.panelRequested("removeHolders", remove)
            },
            ActionButton {
                objectName: "roleOpenHolderButton"
                text: qsTr("Open")
                icon: "forward"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: holderTable.selectedRow !== null
                reason: qsTr("Select one row.")
                onActivated: page.openHolder(holderTable.selectedRow)
            }
        ]

        Label {
            objectName: "roleHoldersError"
            visible: page.loaded && Session.roleHolders.errorCode !== ""
            text: Messages.accessFailure(Session.roleHolders.errorCode)
            color: Theme.failed
            Accessible.role: Accessible.AlertMessage
        }
        Table {
            id: holderTable
            objectName: "roleHolders"
            label: qsTr("Assigned to")
            prefix: "roleHolder_"
            multiSelect: true
            touch: page.narrow
            columns: [{ title: qsTr("Holder"), share: 3 }, { title: qsTr("Kind"), share: 1 }, { title: qsTr("Where"), share: 3 }]
            model: page.loaded ? Session.roleHolders.holders : []
            keyOf: function (holder) { return holder.key }
            cells: function (holder) {
                return [Messages.grantHolder(holder),
                        holder.principalKind === "group" ? qsTr("Group") : holder.principalKind === "role" ? qsTr("Role") : qsTr("Person"),
                        holder.kind === "assignment" ? Messages.accessWhere({ placeKind: "organization", idle: holder.idle })
                                                     : Messages.placeName(holder.resourceKind, holder.name, holder.spaceName)]
            }
            emptyText: page.loaded && !Session.roleHolders.busy && Session.roleHolders.errorCode === "" ? qsTr("None.") : ""
            onOpened: function (holder) { page.openHolder(holder) }
        }
    }
}
