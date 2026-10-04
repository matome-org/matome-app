pragma ComponentBehavior: Bound

import QtQuick
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// A side panel's body that chooses the member the add-on `product` acts
// for when it calls Core itself: its delivery tokens carry only what that
// member holds.
PanelBody {
    id: panel

    required property var product
    property string chosen
    property bool sent: false
    readonly property string held: panel.product?.installation?.responsible_membership_id ?? ""

    title: qsTr("Responsible member")
    subtitle: panel.product?.name ?? ""
    saveText: qsTr("Save")
    saveUsable: !Session.addOns.busy && panel.chosen !== "" && panel.chosen !== panel.held
    objectName: "responsiblePanel"

    Component.onCompleted: panel.chosen = panel.held
    onSaveRequested: {
        panel.sent = true
        Session.addOns.assign(panel.product.key, panel.chosen)
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
        objectName: "responsibleError"
        visible: Session.addOns.errorCode !== ""
        text: Messages.billingFailure(Session.addOns.errorCode)
        color: Theme.failed
        Accessible.role: Accessible.AlertMessage
    }
    Repeater {
        model: Session.addOns.members
        delegate: NavigationRow {
            id: person
            required property var modelData
            objectName: "responsible_" + person.modelData.value
            touch: panel.narrow
            text: person.modelData.label
            icon: panel.chosen === person.modelData.value ? "checkbox-checked" : "checkbox"
            checkable: true
            selected: panel.chosen === person.modelData.value
            usable: !Session.addOns.busy
            onActivated: panel.chosen = person.modelData.value
            Keys.onDownPressed: person.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
            Keys.onUpPressed: person.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
        }
    }
}
