pragma ComponentBehavior: Bound

import QtQuick
import matome
import "screens"
import "explorer"
import "chrome"
import "chrome/Commands.js" as Commands

Window {
    id: win
    width: 1200
    height: 760
    minimumWidth: 320
    minimumHeight: 480
    visible: true
    title: qsTr("Matome")
    color: Theme.background

    onActiveChanged: if (win.active)
        Session.refreshOrganizations()

    readonly property bool inField: {
        const item = win.activeFocusItem
        return item !== null && (item instanceof TextInput || item instanceof TextEdit)
    }

    function restoreFocus() {
        if (explorer.visible)
            explorer.focusDefault()
        else
            auth.focusDefault()
    }

    function perform(id) {
        commandSheet.close()
        keymap.close()
        const mode = Commands.themeMode(id)
        const language = Commands.language(id)
        if (mode !== "")
            Theme.mode = mode
        else if (language !== "")
            Theme.language = language
        else
            Session.runCommand(id)
    }

    // Every key a focused control leaves unhandled ends here, and Session's
    // table decides what it means. Esc first closes what floats.
    FocusScope {
        id: root
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape && explorer.visible && explorer.dismiss())
                event.accepted = true
            else if (Session.handleKey(event.key, event.modifiers, win.inField))
                event.accepted = true
        }

        Connections {
            target: Session
            function onShowKeymap() { keymap.open() }
            function onShowSheet() { commandSheet.open() }
            function onPromptDelete(folderName) {
                deleteConfirm.title = qsTr("Delete folder “%1”?").arg(folderName)
                deleteConfirm.open()
            }
        }

        Auth {
            id: auth
            objectName: "authScreen"
            anchors.fill: parent
            visible: !Session.signedIn
            enabled: auth.visible
        }

        Explorer {
            id: explorer
            objectName: "explorer"
            anchors.fill: parent
            visible: Session.signedIn
            enabled: explorer.visible
            onCommandChosen: function (id) { win.perform(id) }
        }

        CommandSheet {
            id: commandSheet
            anchors.fill: parent
            commands: Session.commandList
            onChosen: function (id) { win.perform(id) }
            onVisibleChanged: if (!commandSheet.visible)
                win.restoreFocus()
        }

        Keymap {
            id: keymap
            anchors.fill: parent
            commands: Session.commandList
            onVisibleChanged: if (!keymap.visible)
                win.restoreFocus()
        }

        Confirm {
            id: deleteConfirm
            objectName: "deleteConfirm"
            anchors.fill: parent
            detail: qsTr("This cannot be undone.")
            action: qsTr("Delete")
            onAccepted: Session.deleteFocusedFolder()
            onVisibleChanged: if (!deleteConfirm.visible)
                win.restoreFocus()
        }
    }
}
