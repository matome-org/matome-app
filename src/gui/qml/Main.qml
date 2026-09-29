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

    onActiveChanged: if (win.active) {
        Session.refreshOrganizations()
        Session.addOns.refresh()
        if (Session.controlledDocs.active) Session.controlledDocs.refresh()
    }

    readonly property bool inField: {
        const item = win.activeFocusItem
        return item !== null && (item instanceof TextInput || item instanceof TextEdit)
    }

    function restoreFocus() {
        if (controlledScreen.visible)
            controlledScreen.focusDefault()
        else if (settingsScreen.visible)
            settingsScreen.focusDefault()
        else if (explorer.visible)
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
        objectName: "safeContent"
        anchors.fill: parent
        anchors.topMargin: win.SafeArea.margins.top
        anchors.leftMargin: win.SafeArea.margins.left
        anchors.rightMargin: win.SafeArea.margins.right
        anchors.bottomMargin: win.SafeArea.margins.bottom
        focus: true

        Keys.onPressed: function (event) {
            if (controlledScreen.visible && event.key === Qt.Key_Escape) {
                controlledScreen.dismiss()
                event.accepted = true
            } else if (controlledScreen.visible && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                event.accepted = true
            } else if (settingsScreen.visible && event.key === Qt.Key_Escape) {
                settingsScreen.dismiss()
                event.accepted = true
            } else if (settingsScreen.visible && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                event.accepted = true
            } else if (event.key === Qt.Key_Escape && explorer.visible && explorer.dismiss())
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
            visible: Session.signedIn && !Session.settingsActive && !Session.controlledDocs.active
            enabled: explorer.visible
            onCommandChosen: function (id) { win.perform(id) }
        }

        Settings {
            id: settingsScreen
            objectName: "settingsScreen"
            anchors.fill: parent
            visible: Session.signedIn && Session.settingsActive
            enabled: visible
            onCommandChosen: function (id) { win.perform(id) }
            onVisibleChanged: if (!settingsScreen.visible && explorer.visible) explorer.focusDefault()
        }

        ControlledDocuments {
            id: controlledScreen
            objectName: "controlledDocumentsScreen"
            anchors.fill: parent
            visible: Session.signedIn && Session.controlledDocs.active
            enabled: visible
            onVisibleChanged: if (!visible && explorer.visible) explorer.focusDefault()
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
