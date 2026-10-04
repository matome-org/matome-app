pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// One add-on setting as its product's `settings_schema` declares it: a
// boolean as on or off, an integer as a number within its bounds, a string
// as text, a string list as distinct entries added one at a time. Under `inherits` it may follow `inherited`, the value of the
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
    readonly property bool list: setting.type === "string_list"
    readonly property var entries: setting.list && Array.isArray(setting.current) ? setting.current : []
    readonly property int fewest: setting.spec?.min_items ?? 0
    readonly property int most: setting.spec?.max_items ?? 2147483647
    readonly property string entry: field.text.trim()
    readonly property bool repeated: setting.entries.some(function (held) { return held.toLowerCase() === setting.entry.toLowerCase() })
    readonly property bool addable: setting.entry !== "" && !setting.repeated && setting.entries.length < setting.most

    signal edited(var value, bool valid)

    // Reads its inputs directly: from a change handler, `current` and
    // `following` may not have caught up yet.
    function load() {
        if (setting.list) {
            field.text = ""
            return
        }
        const current = setting.draft !== undefined ? setting.draft : setting.value
        const following = setting.inherits && (current === null || current === undefined)
        const start = following ? (setting.inherited ?? setting.spec?.default ?? setting.minimum) : current
        field.text = start === null || start === undefined ? "" : String(start)
    }
    function listed(next) {
        setting.edited(next, next.length >= setting.fewest && next.length <= setting.most)
    }
    function add() {
        if (!setting.addable) return
        setting.listed(setting.entries.concat([setting.entry]))
        field.text = ""
    }
    function remove(index) {
        setting.listed(setting.entries.filter(function (held, at) { return at !== index }))
        field.forceActiveFocus()
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
        model: (setting.inherits ? [{ value: "inherit", label: qsTr("Follow the organization: %1").arg(Messages.settingValue(setting.spec, setting.inherited)) }] : [])
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
                if (setting.list) setting.listed(Array.isArray(setting.inherited) ? setting.inherited.slice() : [])
                else setting.commit()
            }
        }
    }
    Repeater {
        model: setting.following ? [] : setting.entries
        delegate: RowLayout {
            id: held
            required property string modelData
            required property int index
            Layout.fillWidth: true
            Layout.maximumWidth: Theme.column * 2
            spacing: Theme.gapS
            Text {
                Layout.fillWidth: true
                text: held.modelData
                font: Theme.body
                color: Theme.textPrimary
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            ActionButton {
                objectName: "addonSettingRemove_" + setting.scope + "_" + setting.key + "_" + held.index
                icon: "close"
                showLabel: false
                text: qsTr("Remove %1").arg(held.modelData)
                tip: qsTr("Remove %1").arg(held.modelData)
                usable: setting.usable
                onActivated: setting.remove(held.index)
            }
        }
    }
    RowLayout {
        visible: setting.type !== "boolean" && !setting.following
        Layout.fillWidth: true
        Layout.maximumWidth: Theme.column * 2
        spacing: Theme.gapS
        Field {
            id: field
            objectName: "addonSettingValue_" + setting.scope + "_" + setting.key
            enabled: setting.usable && (!setting.list || setting.entries.length < setting.most)
            invalid: setting.type === "integer" ? !field.acceptableInput : setting.list && setting.repeated
            validator: setting.type === "integer" ? integer : null
            inputMethodHints: setting.type === "integer" ? Qt.ImhDigitsOnly : Qt.ImhNone
            maximumLength: setting.list ? 80 : 32767
            placeholderText: setting.list ? qsTr("Add to %1").arg(Messages.settingName(setting.key)) : Messages.settingName(setting.key)
            onTextEdited: if (!setting.list) setting.commit()
            onAccepted: setting.add()
        }
        ActionButton {
            objectName: "addonSettingAdd_" + setting.scope + "_" + setting.key
            visible: setting.list
            text: qsTr("Add")
            icon: "new"
            usable: setting.usable && setting.addable
            onActivated: setting.add()
        }
    }
    Label {
        visible: !setting.following && setting.type === "integer" && setting.minimum !== null && setting.maximum !== null
        text: qsTr("From %1 to %2").arg(setting.minimum).arg(setting.maximum)
    }
    Label {
        visible: !setting.following && setting.list
        text: setting.repeated ? qsTr("Already in the list.")
            : setting.spec?.max_items !== undefined ? qsTr("%1 of at most %2").arg(setting.entries.length).arg(setting.most)
            : qsTr("%n item(s)", "", setting.entries.length)
        color: setting.repeated || setting.entries.length < setting.fewest ? Theme.failed : Theme.textSecondary
    }
}
