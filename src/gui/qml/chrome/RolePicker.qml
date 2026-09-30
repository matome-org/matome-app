pragma ComponentBehavior: Bound

import QtQuick
import matome

Picker {
    id: picker

    property bool allowOwner: true

    objectName: "rolePicker"
    model: picker.allowOwner ? Session.orgAdmin.roles
                             : Session.orgAdmin.roles.filter(function (role) { return role.value !== "owner" })
    value: "member"
    Accessible.name: qsTr("Organization role")
}
