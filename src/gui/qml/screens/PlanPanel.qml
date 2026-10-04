pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body with what the organization bought of the add-on
// `product`: its usage against the allowance and each package with its
// limits. While `canChange`, Apply sets how many of one package the
// subscription holds; Stripe handles the charges.
PanelBody {
    id: panel

    required property var product
    property bool canChange: false
    property bool sent: false
    readonly property var skus: panel.product?.skus ?? []
    readonly property var sku: panel.skus.find(function (item) { return item.key === skuPicker.currentValue }) ?? null

    function version(name, number) { return qsTr("%1 · version %2").arg(name).arg(number) }

    title: qsTr("Plan and usage")
    subtitle: panel.product?.name ?? ""
    saveText: panel.canChange && panel.skus.length > 0 ? qsTr("Apply") : ""
    saveUsable: panel.canChange && !Session.orgBilling.busy && panel.sku !== null && quantity.acceptableInput
                && Number(quantity.text) !== panel.sku.purchased
    objectName: "planPanel"

    onSaveRequested: {
        panel.sent = true
        Session.orgBilling.setQuantity(panel.sku.key, Number(quantity.text))
    }

    Connections {
        target: Session.orgBilling
        function onChanged() {
            if (panel.sent && !Session.orgBilling.busy) {
                panel.sent = false
                if (Session.orgBilling.errorCode === "") panel.finished()
            }
        }
    }

    Label {
        objectName: "planError"
        visible: panel.sent && Session.orgBilling.errorCode !== ""
        text: Messages.billingFailure(Session.orgBilling.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Label {
        objectName: "planAllowance"
        visible: (panel.product?.meter_dimension ?? null) !== null && panel.product?.allowance !== undefined
        text: Messages.allowance(panel.product)
    }
    Repeater {
        model: panel.skus
        delegate: ColumnLayout {
            id: item
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.gapXs
            Caption { Layout.fillWidth: true; text: panel.version(item.modelData.key, item.modelData.version) }
            Label { text: qsTr("Purchased: %1 · Total assigned: %2").arg(item.modelData.purchased).arg(item.modelData.assigned) }
            Repeater {
                model: Object.keys(item.modelData.limits ?? {})
                delegate: Label {
                    required property string modelData
                    text: Messages.usageName(modelData) + ": " + Messages.usageAmount(item.modelData.limits[modelData], modelData)
                }
            }
        }
    }
    ColumnLayout {
        visible: panel.canChange && panel.skus.length > 0
        Layout.fillWidth: true
        spacing: Theme.gapS
        Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapS; text: qsTr("Purchased quantity") }
        Picker {
            id: skuPicker
            objectName: "planSku"
            Layout.fillWidth: true
            model: panel.skus.map(function (item) { return { value: item.key, label: panel.version(item.key, item.version) } })
            onCurrentValueChanged: if (panel.sku) quantity.text = String(panel.sku.purchased)
            Accessible.name: qsTr("Add-on package")
        }
        Field {
            id: quantity
            objectName: "addonQuantity"
            placeholderText: qsTr("Purchased quantity")
            validator: IntValidator { bottom: 0; top: panel.sku?.stackable ? 2147483647 : 1 }
            inputMethodHints: Qt.ImhDigitsOnly
            onAccepted: if (panel.saveUsable) panel.saveRequested()
        }
        Label { text: qsTr("Stripe handles charges and proration; paid changes apply after payment.") }
    }
}
