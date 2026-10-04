pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// One add-on's page, opened from its row in Settings › Add-ons: its own
// commands open the side panels that install, pause, uninstall, and
// configure it (`panelRequested`), and Resume acts at once; its tabs are
// its status with its organization settings read only, every space marked
// active or not, whose command opens the panel that turns it on in the
// space selected, and the roles it adds, the one selected opening its page
// (`entryRequested`).
DetailPage {
    id: page

    required property var product
    readonly property string key: page.product?.key ?? ""
    readonly property var installation: page.product?.installation ?? ({})
    readonly property string status: page.installation.status ?? ""
    readonly property var schema: page.product?.settings_schema ?? ({})
    readonly property var keys: Object.keys(page.schema)
    readonly property bool manages: Session.addOns.canInstall && !Session.addOns.busy
    readonly property var spaces: Session.addOnActivations.rows.filter(function (row) { return row.product_key === page.key })
    readonly property int activeIn: page.spaces.filter(function (row) { return row.status === "active" }).length
    // An add-on that calls Core itself has no action of its own in the
    // catalog, yet works per space.
    readonly property bool trusted: page.spaces.length > 0 && !Session.accessDirectory.catalog.some(function (action) {
        return action.key.startsWith("addon." + page.key + ".")
    })
    // The roles it adds that the organization lists: none while it is paused.
    readonly property var addOnRoles: Session.accessDirectory.roles.filter(function (role) {
        return role.origin === "add_on" && role.key.startsWith("addon." + page.key + ".")
    })
    readonly property bool hasPlan: ((page.product?.meter_dimension ?? null) !== null && page.product?.allowance !== undefined)
                                    || (page.product?.skus?.length ?? 0) > 0

    signal panelRequested(string kind, string subject, Item from)
    signal entryRequested(string section, string id, string name)

    objectName: "addonDetail"
    name: "addon"
    backText: qsTr("Add-ons")
    title: page.product?.name ?? ""
    subject: page.key
    Component.onCompleted: Session.accessDirectory.open()
    // The roles it adds are the organization's: read them again as it
    // installs, pauses, or resumes.
    onStatusChanged: Session.accessDirectory.open()

    commands: [
        ActionButton {
            id: install
            objectName: "installAddonButton"
            text: qsTr("Install")
            icon: "check"
            primary: page.status === ""
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: page.manages && page.status === "" && page.product?.entitled === true && page.product?.catalogued === true
            reason: !installing.allowed ? installing.reason
                  : page.status !== "" ? qsTr("It is installed.")
                  : page.product?.entitled !== true ? qsTr("The plan does not include it.") : ""
            onActivated: page.panelRequested("install", "", install)
        },
        ActionButton {
            objectName: "resumeAddonButton"
            text: qsTr("Resume")
            icon: "check"
            primary: page.status === "paused"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: page.manages && page.status === "paused" && page.product?.entitled === true
            reason: !installing.allowed ? installing.reason
                  : page.status !== "paused" ? qsTr("It is not paused.")
                  : page.product?.entitled !== true ? qsTr("The plan does not include it.") : ""
            onActivated: Session.addOns.resume(page.key)
        },
        ActionButton {
            id: pause
            objectName: "pauseAddonButton"
            text: qsTr("Pause")
            icon: "pause"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: page.manages && page.status === "active"
            reason: !installing.allowed ? installing.reason : page.status !== "active" ? qsTr("It is not running.") : ""
            onActivated: page.panelRequested("pause", "", pause)
        },
        ActionButton {
            id: uninstall
            objectName: "uninstallAddonButton"
            text: qsTr("Uninstall")
            icon: "trash"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: page.manages && page.status !== ""
            reason: !installing.allowed ? installing.reason : page.status === "" ? qsTr("It is not installed.") : ""
            onActivated: page.panelRequested("uninstall", "", uninstall)
        },
        ActionButton {
            id: settings
            objectName: "addonSettingsButton"
            visible: page.keys.length > 0
            text: qsTr("Settings")
            icon: "settings"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: page.manages && page.status !== ""
            reason: !installing.allowed ? installing.reason : page.status === "" ? qsTr("It is not installed.") : ""
            onActivated: page.panelRequested("settings", "", settings)
        },
        ActionButton {
            id: plan
            objectName: "addonPlanButton"
            visible: page.hasPlan
            text: qsTr("Plan and usage")
            icon: "space"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            onActivated: page.panelRequested("plan", "", plan)
        },
        ActionButton {
            id: responsible
            objectName: "addonResponsibleButton"
            visible: page.trusted
            text: qsTr("Responsible member")
            icon: "user"
            showLabel: !page.compact
            tip: page.compact ? text : ""
            usable: page.manages && page.status !== ""
            reason: !installing.allowed ? installing.reason : page.status === "" ? qsTr("It is not installed.") : ""
            onActivated: page.panelRequested("responsible", "", responsible)
            Gate { id: installing; action: "add_on.install" }
        }
    ]

    DetailTab {
        view: "details"
        title: qsTr("Details")
        Facts {
            facts: [{ name: "addonStatus", label: qsTr("Status"), value: Messages.addOnStatus(page.installation) },
                    { name: "addonSpaces", label: qsTr("Spaces"),
                      value: page.spaces.length > 0 ? qsTr("Active in %n space(s)", "", page.activeIn) : "" },
                    { name: "addonPlan", label: qsTr("Plan"),
                      value: page.product?.entitled === true ? "" : qsTr("Not included") }]
        }
        Caption {
            visible: page.keys.length > 0 && page.status !== ""
            Layout.fillWidth: true
            Layout.topMargin: Theme.gapS
            text: qsTr("Organization settings")
        }
        Facts {
            objectName: "addonSettings"
            visible: page.keys.length > 0 && page.status !== ""
            facts: page.keys.map(function (key) {
                return { name: "addonSetting_" + key, label: Messages.settingName(key),
                         value: Messages.settingValue(page.schema[key], page.installation.settings?.[key] ?? page.schema[key]?.default ?? null) }
            })
        }
    }

    DetailTab {
        view: "spaces"
        title: qsTr("Spaces")

        commands: [
            ActionButton {
                id: activation
                objectName: "addonActivationButton"
                text: spaceTable.selectedRow?.status === "active" ? qsTr("Settings") : qsTr("Activate")
                icon: "settings"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: spaceTable.selectedRow !== null
                reason: qsTr("Select a space.")
                onActivated: page.panelRequested("activation", spaceTable.selectedRow.space_id, activation)
            }
        ]

        Table {
            id: spaceTable
            objectName: "addonSpaceTable"
            label: qsTr("Spaces")
            prefix: "addonSpace_"
            touch: page.narrow
            columns: [{ title: qsTr("Space"), share: 2 }, { title: qsTr("Status"), share: 1 }]
            model: page.spaces
            keyOf: function (row) { return row.space_id }
            cells: function (row) { return [row.space_name, Messages.activationState(row)] }
            emptyText: qsTr("None.")
            onOpened: function (row) { page.panelRequested("activation", row.space_id, activation) }
        }
    }

    DetailTab {
        view: "roles"
        title: qsTr("Roles")

        commands: [
            ActionButton {
                objectName: "addonOpenRoleButton"
                text: qsTr("Open")
                icon: "forward"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: roleTable.selectedRow !== null
                reason: qsTr("Select one row.")
                onActivated: page.entryRequested("roles", roleTable.selectedRow.id,
                                                 Messages.roleName(roleTable.selectedRow.key, roleTable.selectedRow.name))
            }
        ]

        Table {
            id: roleTable
            objectName: "addonRoles"
            label: qsTr("Roles")
            prefix: "addonRole_"
            touch: page.narrow
            columns: [{ title: qsTr("Role"), share: 2 }, { title: qsTr("Permissions"), share: 3 }]
            model: page.addOnRoles
            keyOf: function (role) { return role.key }
            cells: function (role) { return [Messages.roleName(role.key, role.name), Messages.roleSummary(role.actions)] }
            emptyText: qsTr("None.")
            onOpened: function (role) { page.entryRequested("roles", role.id, Messages.roleName(role.key, role.name)) }
        }
    }
}
