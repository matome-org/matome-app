pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

FocusScope {
    id: commerce
    property bool billing: true
    property string targetProduct
    property string targetSku
    property int targetQuantity
    property var targetSpaces: []
    property string targetAction
    readonly property var subscription: Session.orgBilling.subscription
    readonly property bool liveSubscription: ["active", "trialing", "past_due", "unpaid", "incomplete", "paused"].includes(subscription.status)
    readonly property string loadError: billing ? Session.orgBilling.billingError || Session.orgBilling.usageError
                                               : Session.orgBilling.productsError

    function date(value) {
        if (!value) return ""
        const parsed = new Date(value)
        return isNaN(parsed.getTime()) ? "" : parsed.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }
    function request(action, product, sku, quantity, spaces) {
        commerce.targetAction = action
        commerce.targetProduct = product
        commerce.targetSku = sku
        commerce.targetQuantity = quantity
        commerce.targetSpaces = spaces.slice()
        confirmation.title = action === "package" ? qsTr("Select %1?").arg(product)
                           : action === "quantity" ? qsTr("Change purchased quantity to %1?").arg(quantity)
                           : action === "pause" ? qsTr("Pause this installation?") : qsTr("Save this installation?")
        confirmation.detail = action === "package"
                ? qsTr("This package replaces the subscription plan and purchased add-ons with the items shown. Independent grants are preserved. Stripe handles charges; paid changes require payment confirmation.")
                : action === "quantity"
                ? qsTr("This changes your subscription. Stripe handles charges and proration. Paid changes take effect after payment confirmation; removing a purchased add-on can reduce its allowance immediately.")
                : action === "pause" ? qsTr("Processing will stop. This does not cancel the purchased add-on or its billing.")
                : qsTr("The add-on will be enabled for the selected spaces. No selection applies to all spaces. Existing add-on settings are preserved.")
        confirmation.action = action === "pause" ? qsTr("Pause") : qsTr("Confirm")
        confirmation.open()
    }
    function dismiss() {
        if (!confirmation.visible) return false
        confirmation.close()
        return true
    }
    onVisibleChanged: if (!visible) confirmation.close()
    onBillingChanged: confirmation.close()
    Connections {
        target: Session
        function onChanged() { confirmation.close() }
    }

    component Label: Text {
        Layout.fillWidth: true
        font: Theme.body
        color: Theme.textSecondary
        wrapMode: Text.Wrap
    }
    component Card: Rectangle {
        Layout.fillWidth: true
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.rounding
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: ThinScrollBar {}
        ColumnLayout {
            id: content
            width: scroll.width
            spacing: Theme.gapM
            Label {
                visible: commerce.loadError !== "" || Session.orgBilling.errorCode !== ""
                text: Messages.billingFailure(Session.orgBilling.errorCode || commerce.loadError)
                color: Theme.failed
                Accessible.role: Accessible.AlertMessage
            }
            Label { visible: Session.orgBilling.busy; text: qsTr("Working…") }
            Label {
                visible: Session.orgBilling.notice !== "" && Session.orgBilling.notice !== "portal" && Session.orgBilling.notice !== "checkout"
                text: Session.orgBilling.notice === "billing_requested"
                      ? qsTr("Change requested. Refresh after payment confirmation to see the effective subscription and allowances.")
                      : Session.orgBilling.notice === "installation_paused" ? qsTr("Installation paused. Billing is unchanged.")
                      : qsTr("Installation saved.")
                color: Theme.accentText
            }
            ColumnLayout {
                visible: commerce.billing && commerce.loadError === ""
                Layout.fillWidth: true
                spacing: Theme.gapM
                Card {
                    implicitHeight: summary.implicitHeight + 2 * Theme.gapM
                    ColumnLayout {
                        id: summary
                        anchors.fill: parent
                        anchors.margins: Theme.gapM
                        spacing: Theme.gapS
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
                    }
                }
                Label { text: qsTr("Payment methods, invoices, billing details and subscription cancellation are managed securely in Stripe.") }
                ActionButton {
                    objectName: "billingPortalButton"
                    text: qsTr("Manage billing")
                    primary: true
                    visible: Session.orgBilling.canManage
                    usable: !Session.orgBilling.busy
                    onActivated: Session.orgBilling.createPortal()
                }
                ActionButton {
                    objectName: "openBillingPortalButton"
                    text: Session.orgBilling.notice === "checkout" ? qsTr("Continue to checkout") : qsTr("Open Stripe portal")
                    visible: Session.orgBilling.paymentUrl !== ""
                    usable: !Session.orgBilling.busy && Session.orgBilling.canManage
                    onActivated: Qt.openUrlExternally(Session.orgBilling.paymentUrl)
                }
                Label {
                    visible: !Session.orgBilling.canManage
                    text: qsTr("Only organization owners and billing members can change billing.")
                }
                Label {
                    visible: Session.orgBilling.packagesError !== ""
                    text: Messages.billingFailure(Session.orgBilling.packagesError)
                    color: Theme.failed
                }
                Label {
                    visible: !Session.orgBilling.busy && Session.orgBilling.packagesError === ""
                             && Session.orgBilling.packages.length === 0
                    text: qsTr("No paid packages are available yet. Your current plan remains active.")
                }
                Repeater {
                    model: Session.orgBilling.packages
                    delegate: Card {
                        id: offer
                        required property var modelData
                        implicitHeight: offerContent.implicitHeight + 2 * Theme.gapM
                        ColumnLayout {
                            id: offerContent
                            anchors.fill: parent
                            anchors.margins: Theme.gapM
                            spacing: Theme.gapS
                            Text {
                                Layout.fillWidth: true
                                text: offer.modelData.name
                                font: Theme.heading
                                color: Theme.textPrimary
                                wrapMode: Text.Wrap
                            }
                            Label { text: qsTr("Plan: %1").arg(offer.modelData.plan.key) }
                            Repeater {
                                model: offer.modelData.add_ons
                                delegate: Label {
                                    required property var modelData
                                    text: qsTr("%1 × %2").arg(modelData.quantity).arg(modelData.sku.key)
                                }
                            }
                            ActionButton {
                                text: commerce.liveSubscription ? qsTr("Switch package") : qsTr("Subscribe")
                                visible: Session.orgBilling.canManage
                                primary: true
                                usable: !Session.orgBilling.busy && commerce.subscription.pending_update !== true
                                onActivated: commerce.request("package", offer.modelData.name, offer.modelData.key, offer.modelData.version, [])
                            }
                        }
                    }
                }
                Label { text: qsTr("Use the Usage section to view your effective limits and reservations.") }
                Label { text: qsTr("After returning from Stripe, refresh this page. Allowances are updated only after the server confirms the payment.") }
            }
            ColumnLayout {
                visible: !commerce.billing && commerce.loadError === ""
                Layout.fillWidth: true
                spacing: Theme.gapM
                Label { text: qsTr("Purchased quantities and included allowances are shown separately. Installation controls where an add-on runs; it does not control billing.") }
                Label {
                    visible: !commerce.liveSubscription
                    text: qsTr("Purchasing add-ons requires an active paid subscription. Included add-ons can still be installed.")
                }
                Label {
                    visible: !Session.orgBilling.busy && Session.orgBilling.products.length === 0
                    text: qsTr("No add-ons available.")
                }
                Repeater {
                    model: Session.orgBilling.products
                    delegate: Card {
                        id: product
                        required property var modelData
                        readonly property var installation: modelData.installation || ({})
                        property var selectedSpaces: installation.space_ids ? installation.space_ids.slice() : []
                        implicitHeight: productContent.implicitHeight + 2 * Theme.gapM
                        function toggleSpace(id, checked) {
                            const selected = selectedSpaces.filter(function (value) { return value !== id })
                            if (checked) selected.push(id)
                            selectedSpaces = selected
                        }
                        ColumnLayout {
                            id: productContent
                            anchors.fill: parent
                            anchors.margins: Theme.gapM
                            spacing: Theme.gapS
                            Text {
                                Layout.fillWidth: true
                                text: product.modelData.name
                                font: Theme.heading
                                color: Theme.textPrimary
                                wrapMode: Text.Wrap
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
                                    spacing: Theme.gapS
                                    Label { text: qsTr("%1 · version %2").arg(sku.modelData.key).arg(sku.modelData.version) }
                                    Label { text: qsTr("Purchased: %1 · Total assigned: %2").arg(sku.modelData.purchased).arg(sku.modelData.assigned) }
                                    Repeater {
                                        model: Object.keys(sku.modelData.limits)
                                        delegate: Label {
                                            required property string modelData
                                            text: Messages.usageName(modelData) + ": " + Messages.usageAmount(sku.modelData.limits[modelData], modelData)
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: Session.orgBilling.canManage && commerce.liveSubscription
                                        spacing: Theme.gapS
                                        Field {
                                            id: quantity
                                            objectName: "addonQuantity_" + sku.modelData.key
                                            placeholderText: qsTr("Purchased quantity")
                                            text: String(sku.modelData.purchased)
                                            validator: IntValidator { bottom: 0; top: sku.modelData.stackable ? 2147483647 : 1 }
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            enabled: !Session.orgBilling.busy && commerce.subscription.pending_update !== true
                                        }
                                        ActionButton {
                                            text: qsTr("Apply")
                                            usable: !Session.orgBilling.busy && commerce.subscription.pending_update !== true
                                                    && quantity.acceptableInput && Number(quantity.text) !== sku.modelData.purchased
                                            onActivated: commerce.request("quantity", product.modelData.key, sku.modelData.key, Number(quantity.text), [])
                                        }
                                    }
                                }
                            }
                            Label {
                                text: product.installation.status === "active" ? qsTr("Installation active")
                                    : product.installation.status === "paused" ? qsTr("Installation paused") : qsTr("Not installed")
                            }
                            ColumnLayout {
                                visible: Session.orgBilling.canInstall && (product.modelData.assignments?.length ?? 0) > 0
                                Layout.fillWidth: true
                                spacing: Theme.gapS
                                Label { text: qsTr("Spaces · no selection means all spaces") }
                                Repeater {
                                    model: Session.orgBilling.spaces
                                    delegate: C.CheckBox {
                                        required property var modelData
                                        text: modelData.name
                                        checked: product.selectedSpaces.includes(modelData.id)
                                        enabled: !Session.orgBilling.busy
                                        font: Theme.body
                                        palette.windowText: Theme.textPrimary
                                        palette.highlight: Theme.accent
                                        onToggled: product.toggleSpace(modelData.id, checked)
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.gapS
                                    ActionButton {
                                        text: product.installation.status === "active" ? qsTr("Save spaces") : qsTr("Install / resume")
                                        primary: true
                                        usable: !Session.orgBilling.busy
                                        onActivated: commerce.request("install", product.modelData.key, "", 0, product.selectedSpaces)
                                    }
                                    ActionButton {
                                        visible: product.installation.status === "active"
                                        text: qsTr("Pause installation")
                                        usable: !Session.orgBilling.busy
                                        onActivated: commerce.request("pause", product.modelData.key, "", 0, [])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Confirm {
        id: confirmation
        objectName: "orgCommerceConfirm"
        anchors.fill: parent
        onAccepted: {
            if (commerce.targetAction === "package") Session.orgBilling.selectPackage(commerce.targetSku, commerce.targetQuantity)
            else if (commerce.targetAction === "quantity") Session.orgBilling.setQuantity(commerce.targetSku, commerce.targetQuantity)
            else if (commerce.targetAction === "pause") Session.orgBilling.pause(commerce.targetProduct)
            else Session.orgBilling.install(commerce.targetProduct, commerce.targetSpaces)
        }
    }
}
