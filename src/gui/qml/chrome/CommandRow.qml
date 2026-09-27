pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "Commands.js" as Commands

// One command in a list: icon, title, and its first key as a chip, or a
// check on the theme mode and the language in use. The command sheet and
// the context menu both draw their rows with it.
FocusableControl {
    id: row

    required property var command
    property bool cursor: false
    property bool touch: false

    readonly property string key: Commands.keys(row.command)[0] ?? ""
    readonly property string mode: Commands.themeMode(row.command.id)
    readonly property string language: Commands.language(row.command.id)
    readonly property bool checked: row.mode === Theme.mode || row.language === Theme.language

    tabFocusable: false
    ringOffset: 0
    color: row.cursor ? Theme.accentSoft : "transparent"
    hoverColor: row.cursor ? Theme.accentSoft : Theme.subtleFill
    Accessible.role: Accessible.MenuItem
    Accessible.name: row.command.title
    Accessible.checkable: row.mode !== "" || row.language !== ""
    Accessible.checked: row.checked

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.gapS
        anchors.rightMargin: Theme.gapS
        spacing: Theme.gapM

        Icon {
            name: row.language !== "" ? "language" : row.command.icon
            color: Theme.textSecondary
        }
        Text {
            Layout.fillWidth: true
            text: row.command.title
            color: Theme.textPrimary
            font: row.touch ? Theme.bodyLarge : Theme.body
            elide: Text.ElideRight
        }
        KeyChip {
            visible: row.key !== ""
            text: row.key
        }
        Icon {
            objectName: "checkMark"
            visible: row.checked
            name: "check"
            color: Theme.accentText
        }
    }
}
