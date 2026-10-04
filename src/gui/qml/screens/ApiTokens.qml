pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The signed-in user's personal API tokens, for Settings: each token with
// its expiry, last use and access, and the page that makes a new one. A
// token's access is a list of actions, each in one organization: across it,
// in one space, or in every space the user can reach when it is used.
FocusScope {
    id: tokens

    property bool narrow: false
    property bool creating: false
    // The access the new token will hold: `{scope, label}`, `scope` as Core takes it.
    property var chosen: []
    // Actions picked at the current organization and target.
    property var picked: []
    property string orgId
    property string target: "organization"
    property var revoking: null

    readonly property string createLabel: tokens.creating || Session.apiTokens.secret !== "" ? "" : qsTr("New token")
    readonly property var areas: Session.apiTokens.actions.reduce(function (found, action) {
        return found.includes(action.area) ? found : found.concat([action.area])
    }, [])
    readonly property var targets: [{ value: "organization", label: qsTr("Across the organization") },
                                    { value: "all", label: qsTr("Every space I can reach") }]
                                   .concat(Session.apiTokens.spaces)
    readonly property bool ready: nameField.text.trim() !== "" && tokens.chosen.length > 0
                                  && (!Session.apiTokens.needsPassword || passwordField.text !== "")
                                  && !Session.apiTokens.busy

    function create() {
        nameField.clear()
        passwordField.clear()
        lifetime.value = 30
        lifetime.sync()
        tokens.chosen = []
        tokens.picked = []
        tokens.creating = true
        tokens.choose(Session.currentOrgId !== "" ? Session.currentOrgId : (Session.apiTokens.organizations[0]?.value ?? ""),
                      "organization")
        nameField.forceActiveFocus()
    }
    function choose(orgId, target) {
        tokens.orgId = orgId
        tokens.target = target
        tokens.picked = []
        Session.apiTokens.choose(orgId, target === "organization" ? "" : target === "all" ? "*" : target)
    }
    function where() {
        return tokens.targets.find(function (choice) { return choice.value === tokens.target })?.label ?? ""
    }
    function add() {
        const organization = Session.apiTokens.organizations.find(function (choice) { return choice.value === tokens.orgId })?.label ?? ""
        const next = tokens.chosen.slice()
        for (const key of tokens.picked) {
            const scope = { organization_id: tokens.orgId, action: key }
            if (tokens.target === "all") scope.all_spaces = true
            else if (tokens.target !== "organization") scope.space_id = tokens.target
            const same = function (entry) { return JSON.stringify(entry.scope) === JSON.stringify(scope) }
            const action = Session.apiTokens.actions.find(function (row) { return row.key === key })
            if (!next.some(same))
                next.push({ scope: scope, label: qsTr("%1 · %2 · %3").arg(organization).arg(tokens.where())
                                                     .arg(Messages.actionArea(action.area) + ": " + Messages.actionLabel(action)) })
        }
        tokens.chosen = next
        tokens.picked = []
    }
    function submit() {
        if (!tokens.ready) return
        Session.apiTokens.create(nameField.text, lifetime.currentValue,
                                 tokens.chosen.map(function (entry) { return entry.scope }), passwordField.text)
    }
    // Asks in the side panel before revoking `token`, focus returning to `returnTo`.
    function revoke(token, returnTo) {
        tokens.revoking = token
        panel.show(revokePanel, returnTo)
    }
    // Closes the side panel, else the new token's page or secret.
    function dismiss() {
        if (panel.shown) {
            panel.dismiss()
            return true
        }
        if (Session.apiTokens.secret !== "") {
            Session.apiTokens.forgetSecret()
            return true
        }
        if (tokens.creating) {
            tokens.creating = false
            return true
        }
        return false
    }
    function when(value) {
        return value ? new Date(value).toLocaleString(Qt.locale(), Locale.ShortFormat) : ""
    }

    onVisibleChanged: if (tokens.visible) {
        Session.apiTokens.open()
    } else {
        tokens.creating = false
        panel.close()
        Session.apiTokens.close()
    }

    Connections {
        target: Session.apiTokens
        function onSecretChanged() {
            if (Session.apiTokens.secret !== "") {
                tokens.creating = false
                secretField.forceActiveFocus()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: panel.reserve > 0 ? panel.reserve + Theme.gapM : 0
        spacing: Theme.gapM

        Label {
            objectName: "apiTokensError"
            visible: Session.apiTokens.errorCode !== ""
            text: Messages.tokenFailure(Session.apiTokens.errorCode)
            color: Theme.failed
            Accessible.role: Accessible.AlertMessage
        }
        Label {
            visible: Session.apiTokens.notice !== "" && Session.apiTokens.secret === ""
            text: Session.apiTokens.notice === "token_revoked" ? qsTr("Token revoked. Requests with it now fail.")
                                                               : qsTr("Token created.")
            color: Theme.accentText
        }

        Card {
            objectName: "apiTokenSecret"
            visible: Session.apiTokens.secret !== ""
            Layout.fillWidth: true
            Caption { Layout.fillWidth: true; text: qsTr("Your new token") }
            Label { text: qsTr("Copy it now and keep it somewhere safe. It is not shown again.") }
            Field {
                id: secretField
                objectName: "apiTokenSecretField"
                text: Session.apiTokens.secret
                readOnly: true
                font: Theme.mono
                placeholderText: qsTr("Token")
                onActiveFocusChanged: if (secretField.activeFocus) secretField.selectAll()
            }
            Flow {
                Layout.fillWidth: true
                spacing: Theme.gapS
                ActionButton {
                    objectName: "copyApiTokenButton"
                    text: qsTr("Copy")
                    icon: "paste"
                    onActivated: {
                        secretField.selectAll()
                        secretField.copy()
                    }
                }
                ActionButton {
                    objectName: "doneApiTokenButton"
                    text: qsTr("Done")
                    icon: "check"
                    primary: true
                    onActivated: Session.apiTokens.forgetSecret()
                }
            }
        }

        Page {
            objectName: "apiTokenForm"
            visible: tokens.creating
            Layout.fillWidth: true
            Layout.fillHeight: true
            measure: Theme.measure

            ActionButton {
                text: qsTr("All tokens")
                icon: "back"
                onActivated: tokens.creating = false
            }
            Label { text: qsTr("Name") }
            Field {
                id: nameField
                objectName: "apiTokenNameField"
                placeholderText: qsTr("Where it is used, such as a laptop or an integration")
                maximumLength: 255
                onAccepted: tokens.submit()
            }
            Label { text: qsTr("Expires") }
            Picker {
                id: lifetime
                objectName: "apiTokenLifetime"
                Layout.fillWidth: true
                model: [{ value: 7, label: qsTr("In 7 days") }, { value: 30, label: qsTr("In 30 days") },
                        { value: 90, label: qsTr("In 90 days") }]
                value: 30
                Accessible.name: qsTr("Expires")
            }

            Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapM; text: qsTr("Access") }
            Label { text: qsTr("A token never does more than you can. Pick an organization, where the actions apply, and the actions; then add them.") }
            Picker {
                id: organizationPicker
                objectName: "apiTokenOrganization"
                Layout.fillWidth: true
                model: Session.apiTokens.organizations
                value: tokens.orgId
                Accessible.name: qsTr("Organization")
                onActivated: tokens.choose(organizationPicker.currentValue, "organization")
            }
            Picker {
                id: targetPicker
                objectName: "apiTokenTarget"
                Layout.fillWidth: true
                model: tokens.targets
                value: tokens.target
                Accessible.name: qsTr("Where")
                onActivated: tokens.choose(tokens.orgId, targetPicker.currentValue)
            }
            Label {
                visible: !Session.apiTokens.busy && Session.apiTokens.actions.length === 0
                text: qsTr("You hold no actions a token can take here.")
            }
            Repeater {
                model: tokens.areas
                delegate: ColumnLayout {
                    id: area
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: Theme.gapXs
                    Caption { Layout.fillWidth: true; text: Messages.actionArea(area.modelData) }
                    Repeater {
                        model: Session.apiTokens.actions.filter(function (action) { return action.area === area.modelData })
                        delegate: NavigationRow {
                            id: action
                            required property var modelData
                            readonly property bool held: tokens.picked.includes(action.modelData.key)
                            objectName: "apiTokenAction_" + action.modelData.key
                            touch: tokens.narrow
                            text: Messages.actionLabel(action.modelData)
                            icon: action.held ? "check" : ""
                            checkable: true
                            selected: action.held
                            usable: !Session.apiTokens.busy
                            onActivated: tokens.picked = action.held
                                         ? tokens.picked.filter(function (key) { return key !== action.modelData.key })
                                         : tokens.picked.concat([action.modelData.key])
                        }
                    }
                }
            }
            ActionButton {
                objectName: "addApiTokenAccessButton"
                text: qsTr("Add to token")
                icon: "new"
                usable: tokens.picked.length > 0
                onActivated: tokens.add()
            }

            Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapM; text: qsTr("This token can") }
            Label {
                visible: tokens.chosen.length === 0
                text: qsTr("Nothing yet. Add at least one action.")
            }
            Repeater {
                model: tokens.chosen
                delegate: RowLayout {
                    id: entry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    Text {
                        Layout.fillWidth: true
                        text: entry.modelData.label
                        font: Theme.body
                        color: Theme.textPrimary
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                    ActionButton {
                        objectName: "removeApiTokenAccess_" + entry.index
                        icon: "close"
                        showLabel: false
                        text: qsTr("Remove %1").arg(entry.modelData.label)
                        tip: qsTr("Remove")
                        onActivated: tokens.chosen = tokens.chosen.filter(function (other, at) { return at !== entry.index })
                    }
                }
            }

            Label {
                visible: Session.apiTokens.needsPassword
                Layout.topMargin: Theme.gapM
                text: qsTr("Confirm your password: tokens are only made within 15 minutes of signing in.")
            }
            Field {
                id: passwordField
                objectName: "apiTokenPasswordField"
                visible: Session.apiTokens.needsPassword
                echoMode: TextInput.Password
                placeholderText: qsTr("Password")
                onAccepted: tokens.submit()
            }
            ActionButton {
                objectName: "createApiTokenButton"
                Layout.topMargin: Theme.gapM
                text: qsTr("Create token")
                icon: "check"
                primary: true
                usable: tokens.ready
                onActivated: tokens.submit()
            }
        }

        Page {
            objectName: "apiTokenList"
            visible: !tokens.creating && Session.apiTokens.secret === ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            Label { text: qsTr("Personal tokens let scripts and integrations call Matome as you, limited to the actions you choose.") }
            Label {
                visible: Session.apiTokens.busy
                text: qsTr("Working…")
            }
            Label {
                visible: !Session.apiTokens.busy && Session.apiTokens.tokens.length === 0
                text: qsTr("No tokens yet. Use New token to make one.")
            }
            TileGrid {
                Repeater {
                    model: Session.apiTokens.tokens
                    delegate: Card {
                        id: token
                        required property var modelData
                        readonly property var organizations: token.modelData.scopes.reduce(function (found, scope) {
                            return found.includes(scope.organizationName) ? found : found.concat([scope.organizationName])
                        }, [])
                        objectName: "apiToken_" + token.modelData.id
                        Layout.alignment: Qt.AlignTop
                        Text {
                            Layout.fillWidth: true
                            text: token.modelData.name
                            font: Theme.heading
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                        Label { text: token.modelData.prefix + "…" }
                        Label { text: qsTr("Expires %1").arg(tokens.when(token.modelData.expiresAt)) }
                        Label {
                            text: token.modelData.lastUsedAt !== "" ? qsTr("Last used %1").arg(tokens.when(token.modelData.lastUsedAt))
                                                                     : qsTr("Never used")
                        }
                        Label {
                            text: qsTr("%n action(s)", "", token.modelData.scopes.length)
                                  + (token.organizations.length > 0 ? " · " + token.organizations.join(", ") : "")
                        }
                        ActionButton {
                            id: revokeButton
                            objectName: "revokeApiToken_" + token.modelData.id
                            text: qsTr("Revoke")
                            icon: "trash"
                            usable: !Session.apiTokens.busy
                            onActivated: tokens.revoke(token.modelData, revokeButton)
                        }
                    }
                }
            }
        }
    }

    PanelHost {
        id: panel
        anchors.fill: parent
        narrow: tokens.narrow
        // The revoked token's card goes with its button: focus stays here.
        onClosed: if (tokens.visible && !(panel.returnTo && panel.returnTo.visible)) tokens.forceActiveFocus()
    }
    Component {
        id: revokePanel
        ConfirmPanel {
            objectName: "revokeApiTokenPanel"
            title: qsTr("Revoke %1?").arg(tokens.revoking?.name ?? "")
            detail: qsTr("Anything using this token loses access on its next request.")
            saveText: qsTr("Revoke")
            busy: Session.apiTokens.busy
            failure: Messages.tokenFailure(Session.apiTokens.errorCode)
            onConfirmed: Session.apiTokens.revoke(tokens.revoking.id)
        }
    }
}
