pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// Sign in, create an account, and recover a password, in the landing's voice:
// the mark writes itself over the wordmark and slogan, the form is a column of
// hairline fields under a gold pill, and everything else is a quiet link. The
// Core URL waits behind "Server…" until it is wanted or unreachable.
FocusScope {
    id: auth

    property string pane: "signIn"
    property bool serverOpen: false
    property bool resendingConfirmation: false

    readonly property bool confirmationPending: Session.confirmationPending
    readonly property bool confirmationResent: Session.confirmationResent
    readonly property bool done: (Session.resetSent || (auth.pane === "confirm" && Session.errorCode === ""))
                                 && !Session.busy
    readonly property string statusMessage: {
        if (Session.busy) {
            if (auth.pane === "forgot")
                return qsTr("Sending reset…")
            if (auth.pane === "reset")
                return qsTr("Updating password…")
            if (auth.pane === "register")
                return qsTr("Creating account…")
            if (auth.pane === "confirm")
                return auth.resendingConfirmation ? qsTr("Sending confirmation…")
                                                   : qsTr("Confirming email…")
            return qsTr("Signing in…")
        }
        if (Session.errorCode !== "")
            return Messages.rejected(Session.errorFields) || Messages.failure(Session.errorCode, "auth")
        if (Session.resetSent)
            return qsTr("If that account exists, Core sent a reset token.")
        if (auth.pane === "confirm")
            return Session.confirmationResent
                    ? qsTr("A new confirmation token was sent to %1.").arg(Session.email)
                    : qsTr("Enter the confirmation token sent to %1 to activate your account.").arg(Session.email)
        return ""
    }
    readonly property string modeName: Theme.mode === "light" ? qsTr("Light")
                                      : Theme.mode === "dark" ? qsTr("Dark") : qsTr("System")
    readonly property Item focused: auth.Window.activeFocusItem
    readonly property string errorCode: Session.errorCode

    // The remembered email and server, written once when the form shows: a
    // binding would put them back over what was typed on every change. The
    // password and a reset token never outlive the session they opened. The
    // form opens on sign-in, or on reset with the token of the reset link the
    // web page was opened at.
    function prefill() {
        emailField.text = Session.email
        apiField.text = Session.apiBaseUrl
        passwordField.clear()
        tokenField.text = Session.takeResetLink()
        confirmationField.clear()
        auth.pane = Session.confirmationPending ? "confirm"
                  : tokenField.text !== "" ? "reset" : "signIn"
    }

    function focusDefault() {
        if (auth.pane === "confirm")
            confirmationField.forceActiveFocus()
        else if (auth.pane !== "reset")
            emailField.forceActiveFocus()
        else if (tokenField.text !== "")
            passwordField.forceActiveFocus()
        else
            tokenField.forceActiveFocus()
    }

    function submit() {
        if (auth.pane === "register")
            Session.registerAccount(emailField.text, passwordField.text, apiField.text)
        else if (auth.pane === "confirm") {
            auth.resendingConfirmation = false
            Session.confirmEmail(confirmationField.text)
        }
        else if (auth.pane === "forgot")
            Session.requestPasswordReset(emailField.text, apiField.text)
        else if (auth.pane === "reset")
            Session.resetPassword(tokenField.text, passwordField.text, apiField.text)
        else
            Session.signIn(emailField.text, passwordField.text, apiField.text)
    }

    function showPane(name) {
        auth.pane = name
        focusDefault()
    }

    // Light, then dark, then the desktop's own.
    function cycleTheme() {
        Theme.mode = Theme.mode === "light" ? "dark" : Theme.mode === "dark" ? "system" : "light"
    }

    // A field wrong for the last answer from Core: every one on a bad login,
    // the ones Core named (`name` is Core's) when it refused their values,
    // else the empty ones when something required was missing.
    function invalid(field, name) {
        if (Session.errorCode === "unauthenticated")
            return true
        if (Session.errorCode !== "invalid_request")
            return false
        return Session.errorFields.length > 0 ? Session.errorFields.includes(name) : field.text === ""
    }

    // Keeps the focused control in sight when the window is too short.
    function reveal(item) {
        if (!item || !flick.interactive)
            return
        for (let at = item; at; at = at.parent) {
            if (at === column) {
                const top = item.mapToItem(column, 0, 0).y + column.y
                if (top - Theme.gapXl < flick.contentY)
                    flick.contentY = Math.max(0, top - Theme.gapXl)
                else if (top + item.height + Theme.gapXl > flick.contentY + flick.height)
                    flick.contentY = top + item.height + Theme.gapXl - flick.height
                return
            }
        }
    }

    // Esc (Android's Back) returns to sign-in; on sign-in it is not taken,
    // so Back leaves the app.
    Keys.onEscapePressed: function (event) {
        event.accepted = auth.pane !== "signIn"
        if (event.accepted) {
            if (auth.pane === "confirm")
                Session.signOut()
            showPane("signIn")
        }
    }

    onVisibleChanged: if (auth.visible) {
        auth.prefill()
        auth.focusDefault()
    }
    onFocusedChanged: auth.reveal(auth.focused)
    onConfirmationPendingChanged: if (auth.confirmationPending)
        auth.showPane("confirm")
    onConfirmationResentChanged: if (auth.confirmationResent) {
        confirmationField.clear()
        confirmationField.forceActiveFocus()
    }
    onErrorCodeChanged: if (auth.errorCode === "network")
        auth.serverOpen = true
    Component.onCompleted: {
        auth.prefill()
        if (auth.visible)
            auth.focusDefault()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: flick.width
        contentHeight: Math.max(flick.height, column.implicitHeight + 2 * Theme.gapXxl)
        interactive: flick.contentHeight > flick.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column
            width: Math.min(flick.width - 2 * Theme.gapXl, Theme.measure)
            x: (flick.width - column.width) / 2
            y: Math.max(Theme.gapXxl, (flick.height - column.implicitHeight) / 2)
            spacing: 0

            Logo {
                objectName: "authLogo"
                animated: true
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(Math.max(56, Math.min(112, auth.height * 0.13)))
                Layout.preferredHeight: Layout.preferredWidth
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.gapXl
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Matome")
                color: Theme.textPrimary
                font: Theme.display
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.gapS
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Where everything comes together.")
                color: Theme.textSecondary
                font: Theme.slogan
            }

            Caption {
                objectName: "paneTitle"
                Layout.fillWidth: true
                Layout.topMargin: Theme.gapXxl
                horizontalAlignment: Text.AlignHCenter
                color: Theme.accentText
                text: auth.pane === "register" ? qsTr("Create account")
                    : auth.pane === "confirm" ? qsTr("Confirm your email")
                    : auth.pane === "forgot" ? qsTr("Forgot password")
                    : auth.pane === "reset" ? qsTr("Set a new password")
                    : qsTr("Sign in")
            }

            Field {
                id: emailField
                objectName: "emailField"
                Layout.topMargin: Theme.gapS
                line: true
                focus: auth.pane !== "reset" && auth.pane !== "confirm"
                visible: auth.pane !== "reset" && auth.pane !== "confirm"
                invalid: auth.invalid(emailField, "email")
                placeholderText: qsTr("Email")
                Keys.onReturnPressed: auth.submit()
                Keys.onEnterPressed: auth.submit()
            }

            Field {
                id: tokenField
                objectName: "tokenField"
                line: true
                focus: auth.pane === "reset"
                visible: auth.pane === "reset"
                invalid: auth.invalid(tokenField, "token")
                placeholderText: qsTr("Reset link or token")
                Keys.onReturnPressed: auth.submit()
                Keys.onEnterPressed: auth.submit()
            }

            Field {
                id: confirmationField
                objectName: "confirmationField"
                line: true
                focus: auth.pane === "confirm"
                visible: auth.pane === "confirm"
                invalid: auth.invalid(confirmationField, "token")
                placeholderText: qsTr("Confirmation token")
                Keys.onReturnPressed: auth.submit()
                Keys.onEnterPressed: auth.submit()
            }

            Field {
                id: passwordField
                objectName: "passwordField"
                line: true
                visible: auth.pane !== "forgot" && auth.pane !== "confirm"
                invalid: auth.invalid(passwordField, "password")
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                Keys.onReturnPressed: auth.submit()
                Keys.onEnterPressed: auth.submit()
            }

            ActionButton {
                objectName: "submitButton"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.gapXl
                implicitHeight: Theme.controlXl
                horizontalPadding: Theme.gapXxl
                primary: true
                usable: !Session.busy
                text: auth.pane === "register" ? qsTr("Create account")
                    : auth.pane === "confirm" ? qsTr("Confirm email")
                    : auth.pane === "forgot" ? qsTr("Send reset")
                    : auth.pane === "reset" ? qsTr("Set password")
                    : qsTr("Sign in")
                onActivated: auth.submit()
            }

            Text {
                objectName: "statusMessage"
                visible: auth.statusMessage !== ""
                Layout.fillWidth: true
                Layout.topMargin: Theme.gapL
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: auth.statusMessage
                color: Session.errorCode !== "" ? Theme.failed
                     : auth.done ? Theme.accentText : Theme.textMuted
                font: auth.done ? Theme.slogan : Theme.caption
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }

            Row {
                visible: auth.pane === "signIn"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.gapL

                TextLink {
                    objectName: "registerLink"
                    text: qsTr("Create account")
                    onActivated: auth.showPane("register")
                }
                TextLink {
                    objectName: "forgotLink"
                    text: qsTr("Forgot password")
                    onActivated: auth.showPane("forgot")
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: auth.pane === "signIn" ? 0 : Theme.gapL

                TextLink {
                    objectName: "resendConfirmation"
                    visible: auth.pane === "confirm"
                    enabled: !Session.busy
                    text: qsTr("Send a new token")
                    onActivated: {
                        auth.resendingConfirmation = true
                        Session.resendConfirmation()
                    }
                }
                TextLink {
                    objectName: "resetLink"
                    visible: auth.pane === "forgot" || auth.pane === "signIn"
                    text: qsTr("I have a reset link")
                    onActivated: auth.showPane("reset")
                }
                TextLink {
                    objectName: "backToSignIn"
                    visible: auth.pane !== "signIn"
                    text: qsTr("Back to sign in")
                    onActivated: {
                        if (auth.pane === "confirm")
                            Session.signOut()
                        auth.showPane("signIn")
                    }
                }
            }

            TextLink {
                objectName: "serverToggle"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.gapS
                text: auth.serverOpen ? qsTr("Hide server") : qsTr("Server…")
                Accessible.name: auth.serverOpen ? qsTr("Hide the Core server address")
                                                 : qsTr("Show the Core server address")
                onActivated: auth.serverOpen = !auth.serverOpen
            }

            Field {
                id: apiField
                objectName: "apiField"
                visible: auth.serverOpen
                line: true
                placeholderText: qsTr("Core server address")
                Keys.onReturnPressed: auth.submit()
                Keys.onEnterPressed: auth.submit()
            }
        }
    }

    // The landing's bar tools: the languages, then the theme.
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.gapL
        spacing: Theme.gapXs

        Row {
            objectName: "languageSwitcher"
            Accessible.role: Accessible.Grouping
            Accessible.name: qsTr("Language")

            Repeater {
                id: languages
                model: Theme.languages

                delegate: Row {
                    id: choice
                    required property var modelData
                    required property int index

                    Text {
                        visible: choice.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "·"
                        color: Theme.textMuted
                        font: Theme.link
                        Accessible.ignored: true
                    }
                    TextLink {
                        id: mark
                        objectName: "language_" + choice.modelData.code
                        text: choice.modelData.mark
                        checkable: true
                        checked: Theme.language === choice.modelData.code
                        Accessible.name: choice.modelData.name
                        onActivated: Theme.language = choice.modelData.code
                        // Arrows walk the group; Tab walks it too, then on.
                        Keys.onLeftPressed: if (choice.index > 0)
                            mark.nextItemInFocusChain(false).forceActiveFocus()
                        Keys.onRightPressed: if (choice.index < languages.count - 1)
                            mark.nextItemInFocusChain(true).forceActiveFocus()
                    }
                }
            }
        }

        TextLink {
            objectName: "themeToggle"
            icon: "theme"
            text: auth.modeName
            Accessible.name: qsTr("Theme: %1. Switch theme").arg(auth.modeName)
            onActivated: auth.cycleTheme()
        }
    }
}
