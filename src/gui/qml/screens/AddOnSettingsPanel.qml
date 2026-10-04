pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages
import "Drafts.js" as Drafts

// A side panel's body with the organization settings of the add-on
// `product`, as its catalog `settings_schema` declares them: while
// `installing`, Install installs it with them, available in every space and
// active in none; otherwise Save sends only what changed.
PanelBody {
    id: panel

    required property var product
    property bool installing: false
    property bool sent: false
    readonly property string key: panel.product?.key ?? ""
    readonly property var schema: panel.product?.settings_schema ?? ({})
    readonly property var keys: Object.keys(panel.schema)
    // Required settings with no value yet: Core refuses the installation without them.
    readonly property var missing: panel.keys.filter(function (key) {
        const spec = panel.schema[key]
        const value = panel.draft[key] !== undefined ? panel.draft[key] : panel.product?.installation?.settings?.[key]
        return spec?.required === true && (value === null || value === undefined || value === ""
                                           || (Array.isArray(value) && value.length < Math.max(1, spec.min_items ?? 1)))
    })
    property var draft: ({})
    property var invalid: ({})

    title: panel.installing ? qsTr("Install") : qsTr("Settings")
    subtitle: panel.product?.name ?? ""
    saveText: panel.installing ? qsTr("Install") : qsTr("Save")
    saveUsable: !Session.addOns.busy && panel.missing.length === 0 && Object.keys(panel.invalid).length === 0
                && (panel.installing ? panel.product?.entitled === true && panel.product?.catalogued === true
                                     : Object.keys(panel.draft).length > 0)
    objectName: "addonSettingsPanel"

    onSaveRequested: {
        panel.sent = true
        if (panel.installing) Session.addOns.install(panel.key, panel.draft)
        else Session.addOns.saveSettings(panel.key, panel.draft)
    }

    Connections {
        target: Session.addOns
        function onChanged() {
            if (panel.sent && !Session.addOns.busy) {
                panel.sent = false
                if (Session.addOns.errorCode === "") panel.finished()
            }
        }
    }

    Label {
        objectName: "addonSettingsError"
        visible: Session.addOns.errorCode !== ""
        text: Messages.billingFailure(Session.addOns.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Repeater {
        model: panel.keys
        delegate: AddOnSetting {
            id: setting
            required property string modelData
            key: setting.modelData
            spec: panel.schema[setting.modelData]
            scope: "organization"
            value: Drafts.organizationValue(panel.product, setting.modelData)
            draft: panel.draft[setting.modelData]
            usable: !Session.addOns.busy
            onEdited: function (value, valid) {
                panel.invalid = Drafts.flagged(panel.invalid, setting.key, valid)
                if (valid) panel.draft = Drafts.edited(panel.draft, setting.key, value, setting.value)
            }
        }
    }
    Label {
        objectName: "addonSettingsMissing"
        visible: panel.missing.length > 0
        text: qsTr("Required: %1.").arg(panel.missing.map(Messages.settingName).join(", "))
        color: Theme.failed
    }
}
