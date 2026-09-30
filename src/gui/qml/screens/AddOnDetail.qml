pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// One add-on, opened from its tile in Settings › Add-ons: what the
// organization has of it, where it runs, the organization's settings its
// catalog `settings_schema` declares and, for document control, each
// space's rule with its own values for those settings. Verbs that need a
// confirmation are asked of the page that holds the dialogs.
ColumnLayout {
    id: detail

    required property var product
    property bool narrow: false
    property bool canChangeQuantity: false
    readonly property string key: detail.product?.key ?? ""
    readonly property var installation: detail.product?.installation ?? ({})
    readonly property string status: detail.installation.status ?? ""
    readonly property var schema: detail.product?.settings_schema ?? ({})
    readonly property var keys: Object.keys(detail.schema)
    readonly property bool manages: Session.addOns.canInstall && !Session.addOns.busy
    readonly property bool installable: detail.manages && detail.product?.entitled === true && detail.product?.catalogued === true
    readonly property bool ruled: detail.key === "controlled_docs" && detail.status !== ""
    readonly property var rule: Session.controlledRule.rule
    readonly property var savedSpaces: detail.installation.space_ids ?? []
    readonly property var nextSpaces: detail.coverage === "all" ? [] : detail.chosen
    readonly property bool spacesEdited: detail.savedSpaces.length !== detail.nextSpaces.length
                                         || detail.nextSpaces.some(function (id) { return !detail.savedSpaces.includes(id) })
    // Drafts reset when the saved state they were edited from changes.
    readonly property string stamp: detail.key + ":" + (detail.installation.revision ?? 0) + ":" + detail.status
    readonly property string ruleStamp: spacePicker.currentValue + ":" + (detail.rule.revision ?? 0)
    property var chosen: []
    property string coverage: "all"
    property var draft: ({})
    property var invalid: ({})
    property int generation: 0
    property var ruleDraft: ({})
    property var ruleInvalid: ({})
    property int ruleGeneration: 0

    signal back()
    signal pauseRequested()
    signal uninstallRequested()
    signal quantityRequested()
    signal removeRuleRequested()

    function organizationValue(key) {
        const saved = detail.installation.settings?.[key]
        return saved === undefined || saved === null ? detail.schema[key]?.default ?? null : saved
    }
    function edited(drafts, key, value, saved) {
        const next = Object.assign({}, drafts)
        if (value === saved || ((value === null || value === undefined) && (saved === null || saved === undefined)))
            delete next[key]
        else
            next[key] = value
        return next
    }
    function flagged(flags, key, valid) {
        const next = Object.assign({}, flags)
        if (valid) delete next[key]
        else next[key] = true
        return next
    }
    function reset() {
        detail.chosen = detail.savedSpaces.slice()
        detail.coverage = detail.savedSpaces.length > 0 ? "selected" : "all"
        detail.draft = ({})
        detail.invalid = ({})
        ++detail.generation
    }
    function resetRule() {
        detail.ruleDraft = ({})
        detail.ruleInvalid = ({})
        ++detail.ruleGeneration
    }
    function showSpace(spaceId) {
        spacePicker.value = spaceId
        detail.openRule()
    }
    function openRule() {
        if (detail.visible && detail.ruled && spacePicker.currentValue)
            Session.controlledRule.open(spacePicker.currentValue)
    }
    function install() {
        Session.addOns.install(detail.key, detail.nextSpaces, detail.status === "" ? detail.draft : ({}))
    }

    onStampChanged: detail.reset()
    onRuleStampChanged: detail.resetRule()
    onVisibleChanged: detail.openRule()
    onRuledChanged: detail.openRule()
    Component.onCompleted: {
        detail.reset()
        detail.openRule()
    }

    Layout.fillWidth: true
    spacing: Theme.gapM

    ActionButton {
        objectName: "addonBackButton"
        text: qsTr("All add-ons")
        icon: "back"
        onActivated: detail.back()
    }

    Card {
        objectName: "addonSummary"
        Text {
            objectName: "addonTitle"
            Layout.fillWidth: true
            text: detail.product?.name ?? ""
            font: Theme.heading
            color: Theme.textPrimary
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
        Label {
            objectName: "addonStatus"
            color: detail.status === "active" ? Theme.accentText : Theme.textSecondary
            text: detail.status === "active"
                  ? (detail.savedSpaces.length > 0 ? qsTr("Installed in %n space(s)", "", detail.savedSpaces.length)
                                                   : qsTr("Installed in all spaces"))
                  : detail.status === "paused" ? qsTr("Installation paused") : qsTr("Not installed")
        }
        Label {
            visible: detail.product?.entitled !== true
            text: qsTr("This organization’s plan does not include this add-on. Purchase it to install it.")
        }
        Label {
            visible: detail.product?.meter_dimension !== null && detail.product?.allowance !== undefined
            text: qsTr("Used: %1 · Reserved: %2 · Allowance: %3")
                    .arg(detail.product?.usage?.confirmed ?? 0)
                    .arg(detail.product?.usage?.reserved ?? 0)
                    .arg(detail.product?.allowance?.limit ?? qsTr("Unlimited"))
        }
        Repeater {
            model: detail.product?.skus ?? []
            delegate: ColumnLayout {
                id: sku
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: Theme.gapXs
                spacing: Theme.gapXs
                Caption { Layout.fillWidth: true; text: qsTr("%1 · version %2").arg(sku.modelData.key).arg(sku.modelData.version) }
                Label { text: qsTr("Purchased: %1 · Total assigned: %2").arg(sku.modelData.purchased).arg(sku.modelData.assigned) }
                Repeater {
                    model: Object.keys(sku.modelData.limits ?? {})
                    delegate: Label {
                        required property string modelData
                        text: Messages.usageName(modelData) + ": " + Messages.usageAmount(sku.modelData.limits[modelData], modelData)
                    }
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: Theme.gapS
            ActionButton {
                objectName: "changeQuantityButton"
                visible: Session.orgBilling.canManage && (detail.product?.skus?.length ?? 0) > 0
                text: qsTr("Change quantity")
                icon: "rename"
                usable: detail.canChangeQuantity
                onActivated: detail.quantityRequested()
            }
            ActionButton {
                objectName: "pauseAddonButton"
                visible: Session.addOns.canInstall && detail.status === "active"
                text: qsTr("Pause installation")
                icon: "pause"
                usable: detail.manages
                onActivated: detail.pauseRequested()
            }
            ActionButton {
                objectName: "uninstallAddonButton"
                visible: Session.addOns.canInstall && detail.key === "controlled_docs" && detail.status !== ""
                text: qsTr("Uninstall")
                icon: "trash"
                usable: detail.manages
                onActivated: detail.uninstallRequested()
            }
        }
    }

    Card {
        objectName: "addonSpaces"
        Caption { Layout.fillWidth: true; text: qsTr("Where it runs") }
        Label { text: qsTr("Installation controls where an add-on runs; it does not control billing.") }
        Picker {
            id: coverage
            objectName: "addonCoverage"
            Layout.fillWidth: true
            Layout.maximumWidth: Theme.column * 2
            enabled: detail.installable
            model: [{ value: "all", label: qsTr("All spaces") }, { value: "selected", label: qsTr("Only the selected spaces") }]
            value: detail.coverage
            Accessible.name: qsTr("Spaces")
            onActivated: detail.coverage = coverage.currentValue
        }
        Repeater {
            model: detail.coverage === "selected" ? Session.addOns.spaces : []
            delegate: NavigationRow {
                id: space
                required property var modelData
                readonly property bool checked: detail.chosen.includes(space.modelData.id)
                objectName: "addonSpace_" + space.modelData.id
                text: space.modelData.name
                icon: space.checked ? "check" : "space"
                checkable: true
                selected: space.checked
                touch: detail.narrow
                usable: detail.installable
                onActivated: {
                    const others = detail.chosen.filter(function (id) { return id !== space.modelData.id })
                    detail.chosen = space.checked ? others : others.concat([space.modelData.id])
                }
            }
        }
        ActionButton {
            objectName: "installAddonButton"
            visible: Session.addOns.canInstall
            text: detail.status === "active" ? qsTr("Save spaces")
                : detail.status === "paused" ? qsTr("Resume") : qsTr("Install")
            icon: "check"
            primary: true
            usable: detail.installable && (detail.coverage === "all" || detail.chosen.length > 0)
                    && (detail.status !== "active" || detail.spacesEdited)
                    && (detail.status !== "" || Object.keys(detail.invalid).length === 0)
            onActivated: detail.install()
        }
    }

    Card {
        objectName: "addonSettings"
        visible: detail.keys.length > 0
        Caption { Layout.fillWidth: true; text: qsTr("Organization settings") }
        Label {
            text: detail.status === "" ? qsTr("These settings apply once the add-on is installed.")
                                       : qsTr("Every space uses these settings unless it sets its own.")
        }
        Repeater {
            model: detail.keys
            delegate: AddOnSetting {
                id: organizationSetting
                required property string modelData
                key: organizationSetting.modelData
                spec: detail.schema[organizationSetting.modelData]
                scope: "organization"
                value: detail.organizationValue(organizationSetting.modelData)
                draft: detail.draft[organizationSetting.modelData]
                generation: detail.generation
                usable: detail.manages
                onEdited: function (value, valid) {
                    detail.invalid = detail.flagged(detail.invalid, organizationSetting.key, valid)
                    if (valid) detail.draft = detail.edited(detail.draft, organizationSetting.key, value, organizationSetting.value)
                }
            }
        }
        Label {
            visible: !Session.addOns.canInstall
            text: qsTr("Only organization owners and administrators can change add-on settings.")
        }
        ActionButton {
            objectName: "saveAddonSettingsButton"
            visible: Session.addOns.canInstall && detail.status !== ""
            text: qsTr("Save settings")
            icon: "check"
            primary: true
            usable: detail.manages && Object.keys(detail.draft).length > 0 && Object.keys(detail.invalid).length === 0
            onActivated: Session.addOns.saveSettings(detail.key, detail.draft)
        }
    }

    Card {
        objectName: "addonSpaceSettings"
        visible: detail.ruled
        Caption { Layout.fillWidth: true; text: qsTr("Space settings") }
        Label { text: qsTr("Each space follows the organization settings unless it sets its own. A space’s rule and settings cannot change while it has open reviews.") }
        Picker {
            id: spacePicker
            objectName: "addonRuleSpace"
            Layout.fillWidth: true
            Layout.maximumWidth: Theme.column * 2
            model: Session.addOns.spaces.map(function (space) { return { value: space.id, label: space.name } })
            value: Session.currentSpaceId !== "" ? Session.currentSpaceId : (Session.addOns.spaces[0]?.id ?? "")
            Accessible.name: qsTr("Space")
            onCurrentValueChanged: detail.openRule()
        }
        Label {
            visible: Session.controlledRule.busy
            text: qsTr("Working…")
        }
        Text {
            objectName: "addonRuleState"
            Layout.fillWidth: true
            visible: !Session.controlledRule.busy
            text: Session.controlledRule.ruleError === "forbidden" ? qsTr("You need management access")
                : Session.controlledRule.ruleError !== "" ? Messages.controlledFailure(Session.controlledRule.ruleError)
                : detail.rule.id === undefined ? qsTr("No rule in this space yet")
                : detail.rule.active === true ? qsTr("Space rule active") : qsTr("Space rule paused")
            font: Theme.strong(Theme.body)
            color: Theme.textPrimary
            wrapMode: Text.Wrap
        }
        Label {
            visible: Session.controlledRule.ruleError === "forbidden"
            text: Session.controlledRule.canGrantSelf
                  ? qsTr("Organization administrators manage document control only through an explicit grant: use Grant me management access.")
                  : qsTr("Ask an organization administrator to grant you the Document control managers role here.")
        }
        Label {
            visible: Session.controlledRule.readable && detail.rule.id === undefined
            text: qsTr("Saving settings or activating creates the space’s rule. Documents can be managed once it is active.")
        }
        Repeater {
            model: Session.controlledRule.readable ? detail.keys : []
            delegate: AddOnSetting {
                id: spaceSetting
                required property string modelData
                key: spaceSetting.modelData
                spec: detail.schema[spaceSetting.modelData]
                scope: "space"
                inherits: true
                inherited: detail.organizationValue(spaceSetting.modelData)
                value: detail.rule.settings?.[spaceSetting.modelData] ?? null
                draft: detail.ruleDraft[spaceSetting.modelData]
                generation: detail.ruleGeneration
                usable: !Session.controlledRule.busy
                onEdited: function (value, valid) {
                    detail.ruleInvalid = detail.flagged(detail.ruleInvalid, spaceSetting.key, valid)
                    if (valid) detail.ruleDraft = detail.edited(detail.ruleDraft, spaceSetting.key, value, spaceSetting.value)
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: Theme.gapS
            ActionButton {
                objectName: "grantRuleAccessButton"
                visible: Session.controlledRule.canGrantSelf
                text: qsTr("Grant me management access")
                icon: "user"
                usable: !Session.controlledRule.busy
                onActivated: Session.controlledRule.grantSelf()
            }
            ActionButton {
                visible: Session.controlledRule.rolesMissing
                text: qsTr("Add review roles")
                icon: "new"
                usable: !Session.controlledRule.busy
                onActivated: Session.controlledRule.addRoles()
            }
            ActionButton {
                objectName: "removeRuleButton"
                visible: Session.controlledRule.readable && detail.rule.id !== undefined
                text: qsTr("Remove space rule")
                icon: "trash"
                usable: !Session.controlledRule.busy
                onActivated: detail.removeRuleRequested()
            }
            ActionButton {
                objectName: "toggleRuleButton"
                visible: Session.controlledRule.readable
                text: detail.rule.active === true ? qsTr("Pause space rule") : qsTr("Activate space rule")
                icon: detail.rule.active === true ? "pause" : "check"
                usable: !Session.controlledRule.busy
                onActivated: Session.controlledRule.save(detail.rule.active !== true)
            }
            ActionButton {
                objectName: "saveRuleSettingsButton"
                visible: Session.controlledRule.readable
                text: qsTr("Save space settings")
                icon: "check"
                primary: true
                usable: !Session.controlledRule.busy && Object.keys(detail.ruleDraft).length > 0
                        && Object.keys(detail.ruleInvalid).length === 0
                onActivated: Session.controlledRule.save(detail.rule.active === true, detail.ruleDraft)
            }
        }
        Label {
            visible: Session.controlledRule.notice !== ""
            text: Messages.controlledNotice(Session.controlledRule.notice)
            color: Theme.accentText
        }
        Label {
            objectName: "addonRuleError"
            visible: Session.controlledRule.errorCode !== ""
            text: Messages.ruleFailure(Session.controlledRule.errorCode)
            color: Theme.failed
            Accessible.role: Accessible.AlertMessage
        }
    }
}
