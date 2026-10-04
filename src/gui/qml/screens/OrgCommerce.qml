pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// Plan and billing, or add-ons: the subscription and its packages, which
// the Settings command bar acts on through `canSubscribe` and `subscribe`
// once its side panel confirms, or the add-ons as a table, the selected one
// (`listedProduct`) opening its own page, whose command bar opens the side
// panel beside it for one change, and whose roles open in Roles
// (`entryRequested`).
FocusScope {
    id: commerce

    property bool billing: true
    property bool narrow: false
    property int packageIndex: -1
    property string productKey
    // What the side panel does, and the space it acts on for "activation".
    property string editing
    property string subject
    readonly property var subscription: Session.orgBilling.subscription
    readonly property bool liveSubscription: ["active", "trialing", "past_due", "unpaid", "incomplete", "paused"].includes(subscription.status)
    readonly property bool busy: Session.orgBilling.busy || Session.addOns.busy
    readonly property string loadError: billing ? Session.orgBilling.billingError || Session.orgBilling.usageError
                                               : Session.addOns.errorCode
    readonly property var selectedPackage: Session.orgBilling.packages[packageIndex] ?? null
    readonly property var selectedProduct: Session.orgBilling.products.find(function (product) { return product.key === commerce.productKey }) ?? null
    readonly property var listedProduct: productTable.selectedRow

    readonly property bool canSubscribe: selectedPackage !== null && Session.orgBilling.canManage && !busy
                                         && subscription.pending_update !== true
    readonly property bool measured: Session.addOnAccess.impact.key === commerce.productKey && !Session.addOnAccess.busy
    readonly property bool canChangeQuantity: selectedProduct !== null && Session.orgBilling.canManage && liveSubscription
                                              && !busy && subscription.pending_update !== true
                                              && (selectedProduct.skus?.length ?? 0) > 0

    // Opens the page of entry `id` under `section`, such as a role an
    // add-on adds.
    signal entryRequested(string section, string id, string name)

    function date(value) {
        if (!value) return ""
        const parsed = new Date(value)
        return isNaN(parsed.getTime()) ? "" : parsed.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }
    function version(name, number) { return qsTr("%1 · version %2").arg(name).arg(number) }
    // Asks in the side panel before selecting the package, focus returning to `returnTo`.
    function subscribe(returnTo) { if (commerce.canSubscribe) commerce.edit("package", "", returnTo) }
    function activeIn(key) {
        return Session.addOnActivations.rows.filter(function (row) { return row.product_key === key && row.status === "active" }).length
    }
    // Opens the side panel `kind` on `subject`; focus returns to `returnTo`
    // after. Pausing or uninstalling first counts who holds the roles the
    // add-on adds, which its panel then states.
    function edit(kind, subject, returnTo) {
        commerce.editing = kind
        commerce.subject = subject
        if (kind === "pause" || kind === "uninstall")
            Session.addOnAccess.measure(commerce.productKey)
        panel.show(({ install: settingsPanel, settings: settingsPanel, pause: pausePanel, uninstall: uninstallPanel,
                      plan: planPanel, responsible: responsiblePanel, activation: activationPanel,
                      package: packagePanel })[kind] ?? null, returnTo)
    }
    // Closes the side panel, else the open add-on.
    function dismiss() {
        if (panel.shown) {
            panel.dismiss()
            return true
        }
        if (!commerce.billing && commerce.productKey !== "") {
            commerce.open("")
            return true
        }
        return false
    }
    function open(key) {
        panel.close()
        const from = commerce.productKey
        commerce.productKey = key
        if (key !== "")
            Qt.callLater(function () { addOnPage.backButton.forceActiveFocus(Qt.TabFocusReason) })
        else if (from !== "")
            Qt.callLater(function () { productTable.focusKey(from) })
    }
    function reset() {
        panel.close()
        commerce.productKey = ""
    }
    // Add-ons read where each is active while they show.
    function sync() {
        if (commerce.visible && !commerce.billing)
            Session.addOnActivations.open()
    }
    onVisibleChanged: {
        if (!visible) commerce.reset()
        commerce.sync()
    }
    onBillingChanged: {
        commerce.reset()
        commerce.sync()
    }

    Page {
        id: lists
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - (panel.reserve > 0 ? panel.reserve + Theme.gapM : 0)
        Label {
            visible: commerce.loadError !== "" || Session.orgBilling.errorCode !== "" || Session.addOns.errorCode !== ""
            text: Messages.billingFailure(Session.orgBilling.errorCode || Session.addOns.errorCode || commerce.loadError)
            color: Theme.failed
            Accessible.role: Accessible.AlertMessage
        }
        Label { visible: commerce.busy; text: qsTr("Working…") }
        Label {
            visible: Session.orgBilling.notice === "billing_requested"
            text: qsTr("Change requested. Refresh after payment confirmation to see the effective subscription and allowances.")
            color: Theme.accentText
        }
        Notice {
            objectName: "activationNotice"
            code: !commerce.billing && !panel.shown ? Session.addOnActivations.notice : ""
            place: commerce.productKey
            text: Messages.activationNotice(Session.addOnActivations.notice)
        }
        Notice {
            objectName: "addonNotice"
            code: panel.shown ? "" : Session.addOns.notice
            place: commerce.billing ? "billing" : commerce.productKey
            text: Session.addOns.notice === "installation_paused" ? qsTr("Paused. Billing is unchanged.")
                : Session.addOns.notice === "installation_resumed" ? qsTr("Resumed. It is active again where spaces turned it on.")
                : Session.addOns.notice === "installation_removed" ? qsTr("Uninstalled. Billing is unchanged.")
                : Session.addOns.notice === "settings_saved" && commerce.productKey === "controlled_docs"
                ? qsTr("Settings saved. New reviews use them; open reviews keep the settings they were submitted with.")
                : Session.addOns.notice === "settings_saved" ? qsTr("Settings saved.")
                : Session.addOns.notice === "responsibility_saved" ? qsTr("Responsible member changed.")
                : qsTr("Installed. Turn it on in each space that uses it.")
        }

        ColumnLayout {
            visible: commerce.billing && commerce.loadError === ""
            Layout.fillWidth: true
            spacing: Theme.gapM
            Card {
                Caption { Layout.fillWidth: true; text: qsTr("Current plan") }
                Text {
                    Layout.fillWidth: true
                    text: Session.orgBilling.plan || qsTr("Loading plan…")
                    font: Theme.heading
                    color: Theme.textPrimary
                    wrapMode: Text.Wrap
                }
                Label { text: commerce.subscription.status ? Messages.subscriptionStatus(commerce.subscription.status) : qsTr("No paid subscription.") }
                Label {
                    visible: commerce.date(commerce.subscription.current_period_end) !== ""
                    text: qsTr("Current period ends: %1").arg(commerce.date(commerce.subscription.current_period_end))
                }
                Label {
                    visible: commerce.date(commerce.subscription.cancel_at) !== ""
                    text: qsTr("Cancellation scheduled for: %1").arg(commerce.date(commerce.subscription.cancel_at))
                }
                Label {
                    visible: commerce.subscription.pending_update === true
                    text: qsTr("A subscription change is awaiting payment confirmation.")
                }
                Label { text: qsTr("Payment methods, invoices, billing details and subscription cancellation are managed securely in Stripe.") }
                Label {
                    visible: !Session.orgBilling.canManage
                    text: managingBilling.reason
                    Gate { id: managingBilling; action: "billing.manage" }
                }
            }
            Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapS; text: qsTr("Packages") }
            Label {
                visible: Session.orgBilling.packagesError !== ""
                text: Messages.billingFailure(Session.orgBilling.packagesError)
                color: Theme.failed
            }
            Label {
                visible: !commerce.busy && Session.orgBilling.packagesError === "" && Session.orgBilling.packages.length === 0
                text: qsTr("No paid packages are available yet. Your current plan remains active.")
            }
            TileGrid {
                Repeater {
                    model: Session.orgBilling.packages
                    delegate: Tile {
                        id: offer
                        required property var modelData
                        required property int index
                        objectName: "billingPackage_" + offer.modelData.key + "_" + offer.modelData.version
                        selected: commerce.packageIndex === offer.index
                        Accessible.name: offer.modelData.name
                        onChosen: commerce.packageIndex = offer.index
                        Text {
                            Layout.fillWidth: true
                            objectName: "billingPackageTitle_" + offer.modelData.key + "_" + offer.modelData.version
                            text: commerce.version(offer.modelData.name, offer.modelData.version)
                            font: Theme.heading
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                        }
                        Label { text: qsTr("Plan: %1").arg(commerce.version(offer.modelData.plan.key, offer.modelData.plan.version)) }
                        Repeater {
                            model: offer.modelData.add_ons
                            delegate: Label {
                                required property var modelData
                                text: qsTr("%1 × %2").arg(modelData.quantity).arg(commerce.version(modelData.sku.key, modelData.sku.version))
                            }
                        }
                    }
                }
            }
            Label { text: qsTr("After returning from Stripe, refresh this page. Allowances are updated only after the server confirms the payment.") }
        }

        Table {
            id: productTable
            visible: !commerce.billing && commerce.loadError === "" && commerce.selectedProduct === null
            prefix: "addon_"
            label: qsTr("Add-ons")
            touch: commerce.narrow
            columns: [{ title: qsTr("Name"), share: 2 }, { title: qsTr("Status"), share: 1 }, { title: qsTr("Spaces"), share: 1 }]
            model: Session.orgBilling.products
            keyOf: function (product) { return product.key }
            cells: function (product) {
                const active = commerce.activeIn(product.key)
                return [product.name, Messages.addOnStatus(product.installation),
                        active > 0 ? qsTr("Active in %n space(s)", "", active) : ""]
            }
            emptyText: commerce.busy ? "" : qsTr("No add-ons available.")
            onOpened: function (product) { commerce.open(product.key) }
        }

        AddOnPage {
            id: addOnPage
            visible: !commerce.billing && commerce.loadError === "" && commerce.selectedProduct !== null
            product: commerce.selectedProduct
            narrow: commerce.narrow
            onBackRequested: commerce.open("")
            onPanelRequested: function (kind, subject, from) { commerce.edit(kind, subject, from) }
            onEntryRequested: function (section, id, name) { commerce.entryRequested(section, id, name) }
        }
    }

    PanelHost {
        id: panel
        anchors.fill: parent
        narrow: commerce.narrow
        onClosed: if (commerce.visible && !(panel.returnTo && panel.returnTo.visible) && addOnPage.visible)
                      addOnPage.backButton.forceActiveFocus(Qt.TabFocusReason)
    }

    Component {
        id: settingsPanel
        AddOnSettingsPanel {
            narrow: commerce.narrow
            product: commerce.selectedProduct
            installing: commerce.editing === "install"
        }
    }
    Component {
        id: pausePanel
        ConfirmPanel {
            objectName: "pauseAddonPanel"
            title: qsTr("Pause %1?").arg(commerce.selectedProduct?.name ?? "")
            detail: Messages.addOnImpact(Session.addOnAccess.impact, "pause", commerce.productKey, addOnPage.addOnRoles.length > 0,
                                         addOnPage.activeIn)
            saveText: qsTr("Pause")
            ready: commerce.measured
            busy: Session.addOns.busy
            failure: Messages.billingFailure(Session.addOns.errorCode)
            onConfirmed: Session.addOns.pause(commerce.productKey)
        }
    }
    Component {
        id: uninstallPanel
        ConfirmPanel {
            id: uninstallBody
            objectName: "uninstallAddonPanel"
            title: qsTr("Uninstall %1?").arg(commerce.selectedProduct?.name ?? "")
            detail: Messages.addOnImpact(Session.addOnAccess.impact, "uninstall", commerce.productKey, addOnPage.addOnRoles.length > 0,
                                         addOnPage.activeIn)
            reasonLabel: commerce.productKey === "controlled_docs" ? qsTr("Reason for uninstalling") : ""
            saveText: qsTr("Uninstall")
            ready: commerce.measured
            busy: Session.addOns.busy
            failure: Messages.billingFailure(Session.addOns.errorCode)
            onConfirmed: Session.addOns.uninstall(commerce.productKey, uninstallBody.reason)
        }
    }
    Component {
        id: planPanel
        PlanPanel {
            narrow: commerce.narrow
            product: commerce.selectedProduct
            canChange: commerce.canChangeQuantity
        }
    }
    Component {
        id: responsiblePanel
        ResponsiblePanel {
            narrow: commerce.narrow
            product: commerce.selectedProduct
        }
    }
    Component {
        id: activationPanel
        ActivationPanel {
            narrow: commerce.narrow
            spaceId: commerce.subject
            productKey: commerce.productKey
        }
    }

    Component {
        id: packagePanel
        ConfirmPanel {
            objectName: "selectPackagePanel"
            title: qsTr("Select %1?").arg(commerce.selectedPackage ? commerce.version(commerce.selectedPackage.name, commerce.selectedPackage.version) : "")
            detail: qsTr("This package replaces the subscription plan and purchased add-ons with the items shown. Independent grants are preserved. Stripe handles charges; paid changes require payment confirmation.")
            saveText: qsTr("Select package")
            ready: commerce.selectedPackage !== null
            busy: Session.orgBilling.busy
            failure: Messages.billingFailure(Session.orgBilling.errorCode)
            onConfirmed: Session.orgBilling.selectPackage(commerce.selectedPackage.key, commerce.selectedPackage.version)
        }
    }
}
