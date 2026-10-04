pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// A detail page's overview: each fact (`{name, label, value}`) its label
// beside its value, named `name`; those without a value are left out.
GridLayout {
    id: facts

    required property var facts

    Layout.fillWidth: true
    columns: 2
    columnSpacing: Theme.gapL
    rowSpacing: Theme.gapS

    Repeater {
        model: facts.facts.filter(function (fact) { return fact.value !== "" })
        delegate: Label {
            id: fact
            required property var modelData
            required property int index
            Layout.row: fact.index
            Layout.column: 0
            Layout.fillWidth: false
            text: fact.modelData.label
        }
    }
    Repeater {
        model: facts.facts.filter(function (fact) { return fact.value !== "" })
        delegate: Text {
            id: value
            required property var modelData
            required property int index
            objectName: value.modelData.name
            Layout.row: value.index
            Layout.column: 1
            Layout.fillWidth: true
            text: value.modelData.value
            font: Theme.body
            color: Theme.textPrimary
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
    }
}
