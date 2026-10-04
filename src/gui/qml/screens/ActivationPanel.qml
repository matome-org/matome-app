pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages
import "Drafts.js" as Drafts

// A side panel's body that turns the add-on `productKey` on or off in the
// space `spaceId` and sets the space's own values of its settings, each
// following the organization's until set; for controlled documents, the
// space's review settings. The same panel opens from the space's page and
// from the add-on's.
PanelBody {
    id: panel

    required property string spaceId
    required property string productKey
    readonly property var row: Session.addOnActivations.rows.find(function (row) {
        return row.space_id === panel.spaceId && row.product_key === panel.productKey
    }) ?? null
    readonly property var product: Session.orgBilling.products.find(function (product) { return product.key === panel.productKey }) ?? null
    readonly property var schema: panel.product?.settings_schema ?? ({})
    readonly property var keys: Object.keys(panel.schema)
    readonly property bool on: panel.row?.status === "active"
    readonly property bool usable: panel.row !== null && panel.row.installation_status === "active"
                                   && !Session.addOnActivations.busy
    // Drafts reset when the activation they were edited from changes.
    readonly property string stamp: panel.spaceId + ":" + panel.productKey + ":" + (panel.row?.revision ?? 0)
    property bool wanted: false
    property var draft: ({})
    property var invalid: ({})
    property int generation: 0
    property bool sent: false

    function reset() {
        panel.wanted = panel.on
        panel.draft = ({})
        panel.invalid = ({})
        ++panel.generation
    }

    title: panel.product?.name ?? panel.productKey
    subtitle: panel.row?.space_name ?? ""
    saveText: qsTr("Save")
    saveUsable: panel.usable && Object.keys(panel.invalid).length === 0
                && (panel.wanted !== panel.on || (panel.wanted && Object.keys(panel.draft).length > 0))
    objectName: "activationPanel"

    onStampChanged: panel.reset()
    Component.onCompleted: panel.reset()
    onSaveRequested: {
        panel.sent = true
        if (panel.wanted) Session.addOnActivations.activate(panel.spaceId, panel.productKey, panel.draft)
        else Session.addOnActivations.deactivate(panel.spaceId, panel.productKey)
    }

    Connections {
        target: Session.addOnActivations
        function onChanged() {
            if (panel.sent && !Session.addOnActivations.busy) {
                panel.sent = false
                if (Session.addOnActivations.errorCode === "") panel.finished()
            }
        }
    }

    Label {
        objectName: "activationError"
        visible: Session.addOnActivations.errorCode !== ""
        text: Messages.ruleFailure(Session.addOnActivations.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Label {
        objectName: "activationPaused"
        visible: panel.row !== null && panel.row.installation_status !== "active"
        text: qsTr("Paused in the organization.")
    }
    NavigationRow {
        objectName: "activationSwitch"
        touch: panel.narrow
        text: qsTr("Active in this space")
        icon: panel.wanted ? "checkbox-checked" : "checkbox"
        checkable: true
        selected: panel.wanted
        usable: panel.usable
        onActivated: panel.wanted = !panel.wanted
    }
    Caption {
        visible: panel.wanted && panel.keys.length > 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.gapS
        text: qsTr("Space settings")
    }
    Repeater {
        model: panel.wanted ? panel.keys : []
        delegate: AddOnSetting {
            id: setting
            required property string modelData
            key: setting.modelData
            spec: panel.schema[setting.modelData]
            scope: "space"
            inherits: true
            inherited: Drafts.organizationValue(panel.product, setting.modelData)
            value: panel.row?.settings?.[setting.modelData] ?? null
            draft: panel.draft[setting.modelData]
            generation: panel.generation
            usable: panel.usable
            onEdited: function (value, valid) {
                panel.invalid = Drafts.flagged(panel.invalid, setting.key, valid)
                if (valid) panel.draft = Drafts.edited(panel.draft, setting.key, value, setting.value)
            }
        }
    }
}
