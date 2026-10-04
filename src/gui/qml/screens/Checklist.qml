pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// Ticks any number of `choices` (`{value, label, detail}`): `checked` holds
// the values ticked. A click, tap, Enter, or Space ticks or clears one, and
// the arrows move between them; from `searchFrom` choices on, a search
// narrows them first.
ColumnLayout {
    id: list

    required property var choices
    property var checked: []
    // Names each row `prefix` + its value.
    property string prefix: "check_"
    property string searchLabel: qsTr("Search")
    property string emptyText: qsTr("Nothing to choose from.")
    property int searchFrom: 8
    property bool touch: false
    property bool usable: true
    readonly property string needle: search.text.trim().toLowerCase()
    readonly property var matches: list.choices.filter(function (choice) {
        return list.needle === "" || choice.label.toLowerCase().includes(list.needle)
    })

    // Whether the values ticked are other than `values`.
    function differsFrom(values) {
        return list.checked.length !== values.length || list.checked.some(function (value) { return !values.includes(value) })
    }
    function toggle(value) {
        list.checked = list.checked.includes(value) ? list.checked.filter(function (held) { return held !== value })
                                                    : list.checked.concat([value])
    }

    Layout.fillWidth: true
    spacing: Theme.gapXs

    Field {
        id: search
        objectName: list.prefix + "search"
        visible: list.choices.length >= list.searchFrom
        placeholderText: list.searchLabel
        onAccepted: if (list.matches.length === 1) list.toggle(list.matches[0].value)
    }
    Repeater {
        model: list.matches
        delegate: NavigationRow {
            id: choice
            required property var modelData
            readonly property bool held: list.checked.includes(choice.modelData.value)
            objectName: list.prefix + choice.modelData.value
            touch: list.touch
            text: choice.modelData.label
            detail: choice.modelData.detail ?? ""
            icon: choice.held ? "checkbox-checked" : "checkbox"
            checkable: true
            selected: choice.held
            usable: list.usable
            onActivated: list.toggle(choice.modelData.value)
            Keys.onDownPressed: choice.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
            Keys.onUpPressed: choice.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
        }
    }
    Label {
        visible: list.matches.length === 0
        text: list.choices.length === 0 ? list.emptyText : qsTr("Nothing matches “%1”.").arg(search.text.trim())
    }
}
