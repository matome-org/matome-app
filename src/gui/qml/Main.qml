pragma ComponentBehavior: Bound

import QtQuick
import matome
import "screens"
import "explorer"
import "documents"
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
        if (Session.documentView.active) Session.runCommand("refresh")
    }

    readonly property bool inField: {
        const item = win.activeFocusItem
        return item !== null && (item instanceof TextInput || item instanceof TextEdit)
    }

    function restoreFocus() {
        if (documentScreen.visible)
            documentScreen.focusDefault()
        else if (settingsScreen.visible)
            settingsScreen.focusDefault()
        else if (explorer.visible)
            explorer.focusDefault()
        else
            auth.focusDefault()
    }

    // Opens Settings at the page of space `id`, where its access is given.
    function openSpaceSettings(id, name) {
        Session.openSettings()
        settingsScreen.openEntry("spaces", id, name, "access")
    }

    // Opens Settings where a refusal (Permissions' `explain`) is fixed.
    function fix(answer) {
        Session.openSettings()
        settingsScreen.fix(answer)
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
            if (event.key === Qt.Key_Escape && documentScreen.visible) {
                documentScreen.dismiss()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape && settingsScreen.visible) {
                settingsScreen.dismiss()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape && explorer.visible && explorer.dismiss()) {
                event.accepted = true
            } else {
                event.accepted = Session.handleKey(event.key, event.modifiers, win.inField)
            }
        }

        Connections {
            target: Session
            function onShowKeymap() { keymap.open() }
            function onShowSheet() { commandSheet.open() }
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
            visible: Session.signedIn && !Session.settingsActive && !Session.documentView.active
            enabled: explorer.visible
            onCommandChosen: function (id) { win.perform(id) }
            onSpaceSettingsRequested: function (id, name) { win.openSpaceSettings(id, name) }
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

        DocumentScreen {
            id: documentScreen
            objectName: "documentScreen"
            anchors.fill: parent
            visible: Session.signedIn && !Session.settingsActive && Session.documentView.active
            enabled: visible
            onVisibleChanged: if (!visible && explorer.visible) explorer.focusDefault()
            onFixRequested: function (answer) { win.fix(answer) }
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
    }
}
