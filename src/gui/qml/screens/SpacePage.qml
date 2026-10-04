pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A space's page (`spaceId`): its own commands open the panels that rename
// or archive it; its tabs are its name and visibility, its Access tab, and
// every installed add-on that works per space, active or not here, flagged
// while active with nobody holding its roles here, whose commands open an
// add-on's activation panel ("activation", with its key) or the add-on
// (`addOnRequested`).
DetailPage {
    id: page

    required property string spaceId
    // The space's row in Session.spaces: `{name, status}`.
    property var space: ({})
    readonly property bool archived: page.space.status === "archived"
    property alias view: access
    readonly property var addOns: Session.addOnActivations.rows.filter(function (row) { return row.space_id === page.spaceId })
    readonly property var addOn: addOnTable.selectedRow

    signal panelRequested(string kind, string subject, Item from)
    signal sourceRequested(string kind, string id, string name)
    signal addOnRequested(string key, string name)

    // The roles the add-on `key` adds, as the organization lists them.
    function rolesOf(key) {
        return Session.accessDirectory.roles.filter(function (role) {
            return role.origin === "add_on" && role.key.startsWith("addon." + key + ".")
        })
    }
    // Whether the add-on `key` adds roles that nobody given access here holds.
    function unheld(key) {
        const roles = page.rolesOf(key).map(function (role) { return role.id })
        return roles.length > 0 && !Session.accessGrants.holders.some(function (holder) {
            return holder.roleIds.some(function (id) { return roles.includes(id) })
        })
    }
    function productName(key) {
        return Session.orgBilling.products.find(function (product) { return product.key === key })?.name ?? key
    }

    objectName: "spacePage"
    name: "space"
    backText: qsTr("Spaces")
    title: page.space.name ?? ""
    subject: page.spaceId

    Instantiator {
        model: Session.spaces
        delegate: Binding {
            id: row
            required property string spaceId
            required property string name
            required property string status
            when: row.spaceId === page.spaceId
            target: page
            property: "space"
            value: ({ name: row.name, status: row.status })
        }
    }

    commands: [
        ActionButton {
            id: rename
            objectName: "spaceRenameButton"
            text: qsTr("Rename")
            icon: "rename"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !Session.accessDirectory.busy && !page.archived && renaming.allowed
            reason: page.archived ? qsTr("It is archived.") : renaming.reason
            onActivated: page.panelRequested("renameSpace", page.spaceId, rename)
            Gate { id: renaming; action: "space.update_metadata"; spaceId: page.spaceId }
        },
        ActionButton {
            id: archive
            objectName: "spaceArchiveButton"
            text: qsTr("Archive")
            icon: "trash"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: !Session.accessDirectory.busy && !page.archived && archiving.allowed
            reason: page.archived ? qsTr("It is archived.") : archiving.reason
            onActivated: page.panelRequested("archiveSpace", page.spaceId, archive)
            Gate { id: archiving; action: "space.archive"; spaceId: page.spaceId }
        }
    ]

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: [{ name: "spaceName", label: qsTr("Name"), value: page.space.name ?? "" },
                    { name: "spaceStatus", label: qsTr("Status"), value: page.archived ? qsTr("Archived") : qsTr("Active") },
                    { name: "spaceVisibility", label: qsTr("Visibility"),
                      value: Session.accessGrants.summary.visibility === "public" ? qsTr("Public")
                           : Session.accessGrants.summary.visibility === "private" ? qsTr("Private") : "" }]
        }
    }

    AccessView {
        id: access
        touch: page.narrow
        onPanelRequested: function (kind, from) { page.panelRequested(kind, "", from) }
        onSourceRequested: function (kind, id, name) { page.sourceRequested(kind, id, name) }
    }

    DetailTab {
        view: "addons"
        title: qsTr("Add-ons")

        commands: [
            ActionButton {
                id: activate
                objectName: "spaceActivationButton"
                text: page.addOn?.status === "active" ? qsTr("Settings") : qsTr("Activate")
                icon: "settings"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: page.addOn !== null
                reason: qsTr("Select an add-on.")
                onActivated: page.panelRequested("activation", page.addOn.product_key, activate)
            },
            ActionButton {
                objectName: "spaceOpenAddOnButton"
                text: qsTr("Open")
                icon: "forward"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: page.addOn !== null
                reason: qsTr("Select an add-on.")
                onActivated: page.addOnRequested(page.addOn.product_key, page.productName(page.addOn.product_key))
            }
        ]

        Label {
            objectName: "spaceAddOnsError"
            visible: Session.addOnActivations.readError !== "" && page.addOns.length === 0
            text: Messages.controlledFailure(Session.addOnActivations.readError)
            color: Theme.failed
        }
        Table {
            id: addOnTable
            objectName: "spaceAddOns"
            label: qsTr("Add-ons")
            prefix: "spaceAddOn_"
            touch: page.narrow
            columns: [{ title: qsTr("Add-on"), share: 2 }, { title: qsTr("Status"), share: 3 }]
            model: page.addOns
            keyOf: function (row) { return row.product_key }
            cells: function (row) {
                return [page.productName(row.product_key),
                        row.status === "active" && row.installation_status !== "paused" && page.unheld(row.product_key)
                        ? qsTr("Active · nobody holds its roles here") : Messages.activationState(row)]
            }
            emptyText: Session.addOnActivations.active && !Session.addOnActivations.busy && Session.addOnActivations.readError === ""
                       ? qsTr("None installed.") : ""
            onOpened: function (row) { page.panelRequested("activation", row.product_key, activate) }
        }
    }
}
