pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The Access tab of the person or group `principal`: each space, folder,
// document, or tag `Session.principalAccess` read for them, one row per
// place and way it reaches them, with the roles held there. Its commands
// ask for the panels that grant access on a place and take back the rows
// selected (`panelRequested`), and open the place of the one selected.
DetailTab {
    id: tab

    required property string principal
    property bool touch: false
    readonly property bool loaded: Session.principalAccess.principal === tab.principal
    readonly property var rows: tab.loaded ? tab.grouped(Session.principalAccess.rows) : []
    readonly property bool removable: table.selectedRows.length > 0
                                      && table.selectedRows.every(function (row) { return row.direct && row.kind !== "open" })
    // What Remove takes back: the keys of the roles the rows selected hold,
    // and a line naming each.
    readonly property var removal: {
        const held = table.selectedRows.reduce(function (all, row) { return all.concat(row.held) }, [])
        return { keys: held.map(function (row) { return row.key }),
                 lines: held.map(function (row) { return Messages.roleName(row.roleKey, row.roleName) + " · " + Messages.accessWhere(row) }) }
    }

    signal panelRequested(string kind, Item from)
    signal placeRequested(var place)

    // The PrincipalAccess rows on places, one per place and way it reaches
    // the principal (`via`, or open to members), `held` listing them.
    function grouped(rows) {
        const places = []
        for (const row of rows) {
            if (row.kind === "assignment")
                continue
            const key = row.placeKind + ":" + row.placeId + ":" + (row.kind === "open" ? "open" : row.via)
            let place = places.find(function (found) { return found.key === key })
            if (!place) {
                place = Object.assign({}, row, { key: key, held: [] })
                places.push(place)
            }
            place.held.push(row)
        }
        return places
    }
    function open(row) {
        tab.placeRequested({ kind: row.placeKind, spaceId: row.spaceId, id: row.placeId, name: row.name, spaceName: row.spaceName })
    }

    view: "access"
    title: qsTr("Access")

    commands: [
        ActionButton {
            id: grant
            objectName: "heldGrantAccessButton"
            text: qsTr("Grant access")
            icon: "new"
            primary: true
            showLabel: !tab.compact
            tip: tab.compact ? text : ""
            usable: tab.loaded && !Session.principalAccess.busy && Session.accessDirectory.grantableRoles.length > 0
            reason: Session.accessDirectory.grantableRoles.length === 0 ? qsTr("No roles to give yet.") : ""
            onActivated: tab.panelRequested("grantPlace", grant)
        },
        ActionButton {
            id: remove
            objectName: "heldRemoveButton"
            text: qsTr("Remove")
            icon: "trash"
            showLabel: !tab.compact
            tip: tab.compact ? text : ""
            usable: tab.loaded && !Session.principalAccess.busy && tab.removable
            reason: table.selectedRows.length === 0 ? qsTr("Select what to remove.")
                  : !tab.removable ? qsTr("Only what was given to them directly can be removed here.") : ""
            onActivated: tab.panelRequested("removeHeld", remove)
        },
        ActionButton {
            objectName: "heldOpenButton"
            text: qsTr("Open")
            icon: "forward"
            showLabel: !tab.compact
            tip: tab.compact ? text : ""
            usable: table.selectedRow !== null
            reason: qsTr("Select one row.")
            onActivated: tab.open(table.selectedRow)
        }
    ]

    Table {
        id: table
        objectName: "heldAccess"
        label: qsTr("Access")
        prefix: "heldAccess_"
        multiSelect: true
        touch: tab.touch
        columns: [{ title: qsTr("Place"), share: 3 }, { title: qsTr("Roles"), share: 3 }, { title: qsTr("Source"), share: 2 }]
        model: tab.rows
        keyOf: function (row) { return row.key }
        cells: function (row) {
            return [Messages.accessWhere(row),
                    row.kind === "open" ? qsTr("Reads")
                                        : row.held.map(function (held) { return Messages.roleName(held.roleKey, held.roleName) }).join(", "),
                    Messages.accessVia(row)]
        }
        emptyText: tab.loaded && !Session.principalAccess.busy && Session.principalAccess.errorCode === "" ? qsTr("None.") : ""
        onOpened: function (row) { tab.open(row) }
    }
}
