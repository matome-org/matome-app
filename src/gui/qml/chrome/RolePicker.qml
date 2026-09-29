pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import matome

C.ComboBox {
    id: picker

    property string roleName: "member"
    property bool allowOwner: true

    objectName: "rolePicker"
    model: picker.allowOwner ? Session.orgAdmin.roles
                             : Session.orgAdmin.roles.filter(function (role) { return role.value !== "owner" })
    textRole: "label"
    valueRole: "value"
    currentIndex: picker.indexOfValue(picker.roleName)
    onRoleNameChanged: currentIndex = picker.indexOfValue(picker.roleName)
    onModelChanged: currentIndex = picker.indexOfValue(picker.roleName)
    implicitHeight: Theme.controlL
    implicitWidth: Theme.column
    font: Theme.body
    palette.text: Theme.textPrimary
    palette.buttonText: Theme.textPrimary
    palette.base: Theme.surface
    palette.button: Theme.surface
    palette.window: Theme.surface
    palette.highlight: Theme.accentSoft
    palette.highlightedText: Theme.textPrimary
    Accessible.name: qsTr("Organization role")

    background: Rectangle {
        color: Theme.surface
        radius: Theme.rounding
        border.color: picker.activeFocus ? Theme.accentLine : Theme.border
    }
}
