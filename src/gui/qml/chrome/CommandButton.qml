pragma ComponentBehavior: Bound

import QtQuick
import matome
import "Commands.js" as Commands

// A button bound to one row of Session.commandList: title, icon, first key,
// and usable flag come from the same table as the keys and the sheet.
ActionButton {
    id: button

    required property string commandId
    readonly property var command: Commands.find(Session.commandList, button.commandId)

    objectName: button.commandId + "Button"
    icon: button.command.icon
    text: button.command.title
    usable: button.command.usable
    tip: button.command.title
    key: Commands.keys(button.command)[0] ?? ""
    onActivated: Session.runCommand(button.commandId)
}
