pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// One add-on setting as its product's `settings_schema` declares it: a
// boolean as on or off, an integer as a number within its bounds, a string
// as text. Under `inherits` it may follow `inherited`, the value of the
// layer below, which a null value stands for.
ColumnLayout {
    id: setting

    required property string key
    required property var spec
    property string scope
    property var value
    property bool inherits: false
    property var inherited
    // The edited value, undefined while the setting is unedited.
    property var draft
    property int generation
    property bool usable: true
    readonly property var current: setting.draft !== undefined ? setting.draft : setting.value
    readonly property bool following: setting.inherits && (setting.current === null || setting.current === undefined)
    readonly property string type: setting.spec?.type ?? "string"
    readonly property var minimum: setting.spec?.minimum ?? null
    readonly property var maximum: setting.spec?.maximum ?? null

    signal edited(var value, bool valid)

    function shown(value) {
        if (setting.type === "boolean") return value === true ? qsTr("On") : qsTr("Off")
        return value === null || value === undefined || value === "" ? qsTr("Not set") : String(value)
    }
    // Reads its inputs directly: from a change handler, `current` and
    // `following` may not have caught up yet.
    function load() {
        const current = setting.draft !== undefined ? setting.draft : setting.value
        const following = setting.inherits && (current === null || current === undefined)
        const start = following ? (setting.inherited ?? setting.spec?.default ?? setting.minimum) : current
        field.text = start === null || start === undefined ? "" : String(start)
    }
    function commit() {
        if (setting.type === "integer")
            setting.edited(field.acceptableInput ? Number(field.text) : field.text, field.acceptableInput)
        else
            setting.edited(field.text, true)
    }

    onGenerationChanged: setting.load()
    onValueChanged: setting.load()
    onInheritedChanged: setting.load()
    Component.onCompleted: setting.load()

    Layout.fillWidth: true
    spacing: Theme.gapXs

    IntValidator {
        id: integer
        bottom: setting.minimum ?? -2147483647
        top: setting.maximum ?? 2147483647
    }

    Text {
        Layout.fillWidth: true
        text: Messages.settingName(setting.key)
        font: Theme.strong(Theme.body)
        color: Theme.textPrimary
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }
    Label {
        visible: text !== ""
        text: Messages.settingDetail(setting.key)
    }
    Picker {
        id: mode
        objectName: "addonSettingMode_" + setting.scope + "_" + setting.key
        visible: setting.type === "boolean" || setting.inherits
        enabled: setting.usable
        Layout.fillWidth: true
        Layout.maximumWidth: Theme.column * 2
        model: (setting.inherits ? [{ value: "inherit", label: qsTr("Follow the organization: %1").arg(setting.shown(setting.inherited)) }] : [])
               .concat(setting.type === "boolean" ? [{ value: "on", label: qsTr("On") }, { value: "off", label: qsTr("Off") }]
                                                  : [{ value: "custom", label: qsTr("Set for this space") }])
        value: setting.following ? "inherit" : setting.type !== "boolean" ? "custom" : setting.current === true ? "on" : "off"
        Accessible.name: Messages.settingName(setting.key)
        onActivated: {
            if (mode.currentValue === "inherit") {
                setting.edited(null, true)
            } else if (mode.currentValue === "on" || mode.currentValue === "off") {
                setting.edited(mode.currentValue === "on", true)
            } else if (setting.following) {
                setting.load()
                setting.commit()
            }
        }
    }
    Field {
        id: field
        objectName: "addonSettingValue_" + setting.scope + "_" + setting.key
        visible: setting.type !== "boolean" && !setting.following
        enabled: setting.usable
        Layout.maximumWidth: Theme.column * 2
        invalid: setting.type === "integer" && !field.acceptableInput
        validator: setting.type === "integer" ? integer : null
        inputMethodHints: setting.type === "integer" ? Qt.ImhDigitsOnly : Qt.ImhNone
        placeholderText: Messages.settingName(setting.key)
        onTextEdited: setting.commit()
    }
    Label {
        visible: field.visible && setting.type === "integer" && setting.minimum !== null && setting.maximum !== null
        text: qsTr("From %1 to %2").arg(setting.minimum).arg(setting.maximum)
    }
}
