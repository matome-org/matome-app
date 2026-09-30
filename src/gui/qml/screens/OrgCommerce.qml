pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// Plan and billing, or add-ons: the subscription and its packages, or the
// add-ons, as tiles to select. The Settings command bar acts on the
// selection through the `can…` flags and the functions below; each verb
// asks in a dialog before it reaches Stripe or Core.
FocusScope {
    id: commerce
    property bool billing: true
    property bool narrow: false
    property int packageIndex: -1
    property int productIndex: -1
    property string targetAction
    readonly property var subscription: Session.orgBilling.subscription
    readonly property bool liveSubscription: ["active", "trialing", "past_due", "unpaid", "incomplete", "paused"].includes(subscription.status)
    readonly property bool busy: Session.orgBilling.busy || Session.addOns.busy
    readonly property string loadError: billing ? Session.orgBilling.billingError || Session.orgBilling.usageError
                                               : Session.addOns.errorCode
    readonly property var selectedPackage: Session.orgBilling.packages[packageIndex] ?? null
    readonly property var selectedProduct: Session.orgBilling.products[productIndex] ?? null
    readonly property var installation: selectedProduct?.installation ?? ({})

    readonly property bool canSubscribe: selectedPackage !== null && Session.orgBilling.canManage && !busy
                                         && subscription.pending_update !== true
    readonly property bool canInstall: selectedProduct !== null && Session.addOns.canInstall && !busy
                                       && selectedProduct.entitled === true && selectedProduct.catalogued === true
    readonly property bool canPause: selectedProduct !== null && Session.addOns.canInstall && !busy
                                     && installation.status === "active"
    readonly property bool canUninstall: selectedProduct !== null && Session.addOns.canInstall && !Session.addOns.busy
                                         && selectedProduct.key === "controlled_docs" && installation.status !== undefined
    readonly property bool canChangeQuantity: selectedProduct !== null && Session.orgBilling.canManage && liveSubscription
                                              && !busy && subscription.pending_update !== true
                                              && (selectedProduct.skus?.length ?? 0) > 0
    readonly property string installLabel: installation.status === "active" ? qsTr("Choose spaces")
                                         : installation.status === "paused" ? qsTr("Resume") : qsTr("Install")

    function date(value) {
        if (!value) return ""
        const parsed = new Date(value)
        return isNaN(parsed.getTime()) ? "" : parsed.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }
    function version(name, number) { return qsTr("%1 · version %2").arg(name).arg(number) }
    function ask(action) {
        commerce.targetAction = action
        confirmation.title = action === "package" ? qsTr("Select %1?").arg(commerce.version(commerce.selectedPackage.name, commerce.selectedPackage.version))
                           : action === "uninstall" ? qsTr("Uninstall document control?")
                           : qsTr("Pause this installation?")
        confirmation.detail = action === "package"
                ? qsTr("This package replaces the subscription plan and purchased add-ons with the items shown. Independent grants are preserved. Stripe handles charges; paid changes require payment confirmation.")
                : action === "uninstall" ? qsTr("All open reviews will be cancelled and document control will be removed throughout this organization. Published versions and purchased allowances remain. Resuming does not restore document control.")
                : commerce.selectedProduct.key === "controlled_docs" ? qsTr("New proposals and approvals will stop. Published documents, reviews, and control rules remain. Billing is unchanged.")
                : qsTr("Processing will stop. This does not cancel the purchased add-on or its billing.")
        confirmation.reasonLabel = action === "uninstall" ? qsTr("Reason for uninstalling document control") : ""
        confirmation.action = action === "pause" ? qsTr("Pause")
                            : action === "uninstall" ? qsTr("Uninstall") : qsTr("Confirm")
        confirmation.open()
    }
    function subscribe() { if (commerce.canSubscribe) commerce.ask("package") }
    function pause() { if (commerce.canPause) commerce.ask("pause") }
    function uninstall() { if (commerce.canUninstall) commerce.ask("uninstall") }
    function install() {
        if (!commerce.canInstall) return
        const chosen = commerce.installation.space_ids ?? []
        spacesDialog.chosen = chosen.slice()
        coverage.value = chosen.length > 0 ? "selected" : "all"
        spacesDialog.open()
    }
    function changeQuantity() {
        if (!commerce.canChangeQuantity) return
        skuPicker.value = commerce.selectedProduct.skus[0].key
        quantityDialog.open()
    }
    function dismiss() {
        for (const dialog of [confirmation, spacesDialog, quantityDialog]) {
            if (dialog.visible) {
                dialog.close()
                return true
            }
        }
        return false
    }
    function closeDialogs() {
        confirmation.close()
        spacesDialog.close()
        quantityDialog.close()
    }
    onVisibleChanged: if (!visible) closeDialogs()
    onBillingChanged: closeDialogs()
    Connections {
        target: Session
        function onChanged() { commerce.closeDialogs() }
    }

    Page {
        anchors.fill: parent
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
        Label {
            visible: !commerce.billing && Session.addOns.notice !== ""
            text: Session.addOns.notice === "installation_paused" ? qsTr("Installation paused. Billing is unchanged.")
                : Session.addOns.notice === "installation_removed" ? qsTr("Document control uninstalled. Billing is unchanged.")
                : qsTr("Installation saved.")
            color: Theme.accentText
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
                    text: qsTr("Only organization owners and billing members can change billing.")
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

        ColumnLayout {
            visible: !commerce.billing && commerce.loadError === ""
            Layout.fillWidth: true
            spacing: Theme.gapM
            Label { text: qsTr("Select an add-on, then choose what to do in the bar above. Installation controls where an add-on runs; it does not control billing.") }
            Label {
                visible: !commerce.liveSubscription
                text: qsTr("Purchasing add-ons requires an active paid subscription. Included add-ons can still be installed.")
            }
            Label {
                visible: !commerce.busy && Session.orgBilling.products.length === 0
                text: qsTr("No add-ons available.")
            }
            TileGrid {
                Repeater {
                    model: Session.orgBilling.products
                    delegate: Tile {
                        id: product
                        required property var modelData
                        required property int index
                        readonly property var installation: modelData.installation || ({})
                        objectName: "addon_" + product.modelData.key
                        selected: commerce.productIndex === product.index
                        Accessible.name: product.modelData.name
                        onChosen: commerce.productIndex = product.index
                        Text {
                            Layout.fillWidth: true
                            text: product.modelData.name
                            font: Theme.heading
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                        }
                        Label {
                            color: product.installation.status === "active" ? Theme.accentText : Theme.textSecondary
                            text: product.installation.status === "active"
                                  ? (product.installation.space_ids?.length > 0 ? qsTr("Installed in %n space(s)", "", product.installation.space_ids.length)
                                                                                : qsTr("Installed in all spaces"))
                                  : product.installation.status === "paused" ? qsTr("Installation paused") : qsTr("Not installed")
                        }
                        Label {
                            visible: product.modelData.meter_dimension !== null && product.modelData.allowance !== undefined
                            text: qsTr("Used: %1 · Reserved: %2 · Allowance: %3")
                                    .arg(product.modelData.usage?.confirmed ?? 0)
                                    .arg(product.modelData.usage?.reserved ?? 0)
                                    .arg(product.modelData.allowance?.limit ?? qsTr("Unlimited"))
                        }
                        Repeater {
                            model: product.modelData.skus
                            delegate: ColumnLayout {
                                id: sku
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.gapXs
                                spacing: Theme.gapXs
                                Caption { Layout.fillWidth: true; text: commerce.version(sku.modelData.key, sku.modelData.version) }
                                Label { text: qsTr("Purchased: %1 · Total assigned: %2").arg(sku.modelData.purchased).arg(sku.modelData.assigned) }
                                Repeater {
                                    model: Object.keys(sku.modelData.limits)
                                    delegate: Label {
                                        required property string modelData
                                        text: Messages.usageName(modelData) + ": " + Messages.usageAmount(sku.modelData.limits[modelData], modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: spacesDialog
        objectName: "addonSpacesDialog"
        anchors.fill: parent
        property var chosen: []
        title: commerce.installLabel
        action: commerce.installLabel
        ready: coverage.currentValue === "all" || spacesDialog.chosen.length > 0
        initialFocus: coverage
        onAccepted: Session.addOns.install(commerce.selectedProduct.key, coverage.currentValue === "all" ? [] : spacesDialog.chosen)
        Label { text: qsTr("The add-on will be enabled where you choose. Existing add-on settings are preserved.") }
        Picker {
            id: coverage
            Layout.fillWidth: true
            model: [{ value: "all", label: qsTr("All spaces") }, { value: "selected", label: qsTr("Only the selected spaces") }]
            Accessible.name: qsTr("Spaces")
        }
        Repeater {
            model: coverage.currentValue === "selected" ? Session.addOns.spaces : []
            delegate: NavigationRow {
                id: space
                required property var modelData
                readonly property bool checked: spacesDialog.chosen.includes(space.modelData.id)
                text: space.modelData.name
                icon: space.checked ? "check" : "space"
                checkable: true
                selected: space.checked
                touch: commerce.narrow
                onActivated: {
                    const others = spacesDialog.chosen.filter(function (id) { return id !== space.modelData.id })
                    spacesDialog.chosen = space.checked ? others : others.concat([space.modelData.id])
                }
            }
        }
    }

    Dialog {
        id: quantityDialog
        objectName: "addonQuantityDialog"
        anchors.fill: parent
        readonly property var sku: (commerce.selectedProduct?.skus ?? []).find(function (item) { return item.key === skuPicker.currentValue }) ?? null
        title: qsTr("Change purchased quantity")
        action: qsTr("Apply")
        ready: quantityDialog.sku !== null && quantity.acceptableInput && Number(quantity.text) !== quantityDialog.sku.purchased
        initialFocus: quantity
        onVisibleChanged: if (quantityDialog.visible && quantityDialog.sku) quantity.text = String(quantityDialog.sku.purchased)
        onAccepted: Session.orgBilling.setQuantity(quantityDialog.sku.key, Number(quantity.text))
        Label { text: qsTr("This changes your subscription. Stripe handles charges and proration. Paid changes take effect after payment confirmation; removing a purchased add-on can reduce its allowance immediately.") }
        Picker {
            id: skuPicker
            Layout.fillWidth: true
            model: (commerce.selectedProduct?.skus ?? []).map(function (item) {
                return { value: item.key, label: commerce.version(item.key, item.version) }
            })
            onActivated: quantity.text = String(quantityDialog.sku.purchased)
            Accessible.name: qsTr("Add-on package")
        }
        Field {
            id: quantity
            objectName: "addonQuantity"
            placeholderText: qsTr("Purchased quantity")
            validator: IntValidator { bottom: 0; top: quantityDialog.sku?.stackable ? 2147483647 : 1 }
            inputMethodHints: Qt.ImhDigitsOnly
            onAccepted: quantityDialog.accept()
        }
    }

    Confirm {
        id: confirmation
        objectName: "orgCommerceConfirm"
        anchors.fill: parent
        onAccepted: {
            if (commerce.targetAction === "uninstall") Session.addOns.uninstallControlledDocs(confirmation.reason)
            else if (commerce.targetAction === "package") Session.orgBilling.selectPackage(commerce.selectedPackage.key, commerce.selectedPackage.version)
            else Session.addOns.pause(commerce.selectedProduct.key)
        }
    }
}
