pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The Access tab of what `Session.accessGrants` has open: the people and
// groups given access here, then those it inherits, each with its roles and
// where it comes from. Its commands are Grant access, Manage roles on the
// one row selected that was given here, and Remove on the rows selected
// that were given here; a folder or document adds to its page's commands
// Stop inheriting or, once stopped, Change inheritance (restricted or
// open), and Restore inheritance. Check access is a command of a space's
// tab and of a folder's or document's page; a tag has none. Each opens the
// side panel body in `panels` that the page holding the side panel loads
// (`panelRequested`); one that does not apply says why. While `outcome`,
// the last change's notice or refusal shows above the rows, and an
// inherited row opens where it comes from (`sourceRequested`).
DetailTab {
    id: view

    property bool touch: false
    property bool outcome: true
    // The roles Grant access starts with checked.
    property var grantRoles: []
    readonly property string kind: Session.accessGrants.kind
    readonly property string target: view.kind + ":" + Session.accessGrants.targetId
    readonly property var rows: Session.accessGrants.holders.map(function (holder) {
        return Object.assign({ key: holder.principal, inherited: false }, holder)
    }).concat(Session.accessGrants.inherited.map(function (holder) {
        return Object.assign({ key: "inherited:" + holder.sourceKind + ":" + holder.sourceId + "_" + holder.principal, inherited: true },
                             holder)
    }))
    readonly property var selectedRows: table.selectedRows
    readonly property var selectedRow: table.selectedRow
    readonly property string placeName: Messages.placeName(view.kind, Session.accessGrants.name, "")
    readonly property bool ready: Session.accessGrants.active && !Session.accessGrants.busy
    readonly property bool inheritable: view.kind === "folder" || view.kind === "document"
    readonly property bool broken: (Session.accessGrants.summary.inheritance ?? "") !== ""
    readonly property bool givenHere: view.selectedRows.length > 0 && view.selectedRows.every(function (row) {
        return !row.inherited && row.roleIds.length > 0
    })
    // The side panel bodies the commands open, by the kind they ask for.
    readonly property var panels: ({ grantAccess: grantPanel, holderRoles: holderRolesPanel, removeAccess: removePanel,
                                     stopInheriting: inheritancePanel, restoreInheritance: restorePanel,
                                     checkAccess: checkPanel })

    signal panelRequested(string kind, Item from)
    // The place an inherited row comes from: a space or a folder.
    signal sourceRequested(string kind, string id, string name)

    function failure(code) { return Messages.refused(code, managing.answer, Messages.accessFailure) }

    onTargetChanged: table.selectedKeys = []
    view: "access"
    title: qsTr("Access")

    // What a refusal of a change here lacks: managing access on the place.
    Gate { id: managing; action: "resource_grant.create"; spaceId: Session.accessGrants.spaceId }

    commands: [
        ActionButton {
            id: grant
            objectName: "grantAccessButton"
            text: qsTr("Grant access")
            icon: "new"
            primary: true
            showLabel: !view.compact
            tip: view.compact ? text : ""
            usable: view.ready && Session.accessDirectory.grantableRoles.length > 0
            reason: Session.accessDirectory.grantableRoles.length === 0 ? qsTr("No roles to give yet.") : ""
            onActivated: {
                view.grantRoles = []
                view.panelRequested("grantAccess", grant)
            }
        },
        ActionButton {
            id: manage
            objectName: "manageAccessRolesButton"
            text: qsTr("Manage roles")
            icon: "role"
            showLabel: !view.compact
            tip: view.compact ? text : ""
            usable: view.ready && view.selectedRow !== null && !view.selectedRow.inherited
            reason: view.selectedRow === null ? qsTr("Select one row.")
                  : view.selectedRow.inherited ? qsTr("It comes from above; change it there.") : ""
            onActivated: view.panelRequested("holderRoles", manage)
        },
        ActionButton {
            id: remove
            objectName: "removeAccessButton"
            text: qsTr("Remove")
            icon: "trash"
            showLabel: !view.compact
            tip: view.compact ? text : ""
            usable: view.ready && view.givenHere
            reason: view.selectedRows.length === 0 ? qsTr("Select what to remove.")
                  : !view.givenHere ? qsTr("Only access given here can be removed here.") : ""
            onActivated: view.panelRequested("removeAccess", remove)
        },
        // On a folder or document, a command of its page.
        ActionButton {
            id: check
            objectName: "checkAccessButton"
            parent: view.inheritable ? view.pageCommandRow : view.commandRow
            visible: view.kind !== "tag"
            text: qsTr("Check access")
            icon: "user"
            showLabel: !view.compact
            tip: view.compact ? text : ""
            usable: view.ready
            onActivated: view.panelRequested("checkAccess", check)
        }
    ]
    pageCommands: [
        ActionButton {
            id: stop
            objectName: "stopInheritingButton"
            visible: view.inheritable
            text: view.broken ? qsTr("Change inheritance") : qsTr("Stop inheriting")
            icon: "access"
            showLabel: !view.compact
            tip: view.compact ? text : ""
            usable: view.ready
            onActivated: view.panelRequested("stopInheriting", stop)
        },
        ActionButton {
            id: restore
            objectName: "restoreInheritanceButton"
            visible: view.inheritable
            text: qsTr("Restore inheritance")
            icon: "restore"
            showLabel: !view.compact
            tip: view.compact ? text : ""
            usable: view.ready && view.broken
            reason: view.broken ? "" : qsTr("It inherits already.")
            onActivated: view.panelRequested("restoreInheritance", restore)
        }
    ]

    Label {
        objectName: "accessGrantsError"
        visible: view.outcome && Session.accessGrants.errorCode !== ""
        text: view.failure(Session.accessGrants.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Notice {
        objectName: "accessGrantsNotice"
        code: view.outcome ? Session.accessGrants.notice : ""
        place: view.target
        text: Messages.accessNotice(Session.accessGrants.notice)
    }
    Label {
        visible: Session.accessGrants.busy && view.rows.length === 0
        text: qsTr("Working…")
    }
    Table {
        id: table
        objectName: "accessTable"
        label: qsTr("Access")
        prefix: "accessHolder_"
        multiSelect: true
        touch: view.touch
        columns: [{ title: qsTr("Holder"), share: 3 }, { title: qsTr("Roles"), share: 3 }, { title: qsTr("Source"), share: 2 }]
        model: view.visible ? view.rows : []
        keyOf: function (row) { return row.key }
        cells: function (row) { return [Messages.grantHolder(row), Messages.heldRoles(row), Messages.accessSource(row)] }
        emptyText: Session.accessGrants.active && !Session.accessGrants.busy && Session.accessGrants.errorCode === ""
                   ? qsTr("Nobody has access given here.") : ""
        onOpened: function (row) { if (row.inherited) view.sourceRequested(row.sourceKind, row.sourceId, row.sourceName) }
    }

    Component {
        id: grantPanel
        GrantPanel {
            narrow: view.touch
            presetRoles: view.grantRoles
        }
    }
    Component {
        id: holderRolesPanel
        HolderRolesPanel {
            narrow: view.touch
            holder: view.selectedRow
        }
    }
    Component {
        id: removePanel
        ConfirmPanel {
            objectName: "removeAccessPanel"
            title: view.selectedRow !== null ? qsTr("Remove access for %1?").arg(Messages.grantHolder(view.selectedRow))
                                             : qsTr("Remove access for %n holder(s)?", "", view.selectedRows.length)
            subtitle: view.placeName
            detail: view.selectedRow !== null
                    ? qsTr("They lose %1 here. Access through groups or from above stays.")
                      .arg(Messages.heldRoles(view.selectedRow) || qsTr("their roles"))
                    : qsTr("They lose their roles here. Access through groups or from above stays.")
            saveText: qsTr("Remove access")
            busy: Session.accessGrants.busy
            failure: view.failure(Session.accessGrants.errorCode)
            onConfirmed: Session.accessGrants.remove(view.selectedRows.map(function (row) { return row.principal }))
        }
    }
    Component {
        id: inheritancePanel
        InheritancePanel {
            narrow: view.touch
            rows: view.rows
        }
    }
    Component {
        id: restorePanel
        ConfirmPanel {
            objectName: "restoreInheritancePanel"
            title: qsTr("Restore inheritance?")
            subtitle: view.placeName
            detail: qsTr("Access from the space and the folders above applies here again.")
            saveText: qsTr("Restore inheritance")
            busy: Session.accessGrants.busy
            failure: view.failure(Session.accessGrants.errorCode)
            onConfirmed: Session.accessGrants.setInheritance("inherit")
        }
    }
    Component {
        id: checkPanel
        CheckAccessPanel { narrow: view.touch }
    }
}
