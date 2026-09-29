pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages
import "../chrome/Commands.js" as Commands

FocusScope {
    id: settings

    readonly property bool narrow: settings.width < 600
    signal commandChosen(string id)

    property string section: "appearance"
    readonly property bool organizationSection: section !== "appearance" && section !== "organizations"
    property string targetId
    property string targetRole
    property string targetAction
    readonly property string sectionError: settings.section === "general" ? Session.orgAdmin.generalError
                                          : settings.section === "members" ? Session.orgAdmin.membersError
                                          : settings.section === "invitations" ? Session.orgAdmin.invitationsError
                                          : settings.section === "usage" ? Session.orgAdmin.usageError
                                          : settings.section === "organizations" ? Session.organizationsError : ""
    readonly property var sections: [
        { value: "appearance", label: qsTr("Appearance"), icon: "settings" },
        { value: "organizations", label: qsTr("Organizations"), icon: "org" }
    ].concat(Session.orgAdmin.available ? [
        { value: "general", label: qsTr("Organization"), icon: "org" },
        { value: "members", label: qsTr("Members"), icon: "user" },
        { value: "invitations", label: qsTr("Invitations"), icon: "new" },
        { value: "usage", label: qsTr("Usage"), icon: "space" }
    ] : [])

    function configureOrganization(id) {
        Session.navigate("org", id)
        if (Session.orgAdmin.available) {
            settings.section = "general"
            settings.focusDefault()
        }
    }
    function openOrganizations(id) {
        Session.closeSettings()
        Session.navigate(id === "" ? "root" : "org", id)
    }
    function focusDefault() { back.forceActiveFocus() }
    function dismiss() {
        if (confirm.visible)
            confirm.close()
        else
            Session.closeSettings()
    }
    function ask(action, id, email, role) {
        settings.targetId = id
        settings.targetRole = role
        settings.targetAction = action
        confirm.title = action === "remove" ? qsTr("Remove %1?").arg(email)
                      : action === "cancel" ? qsTr("Cancel invitation for %1?").arg(email)
                      : qsTr("Change the role of %1?").arg(email)
        confirm.detail = action === "remove" ? qsTr("This person will lose access to the organization.")
                       : action === "cancel" ? qsTr("The invitation link will stop working.")
                       : qsTr("Their organization permissions will change.")
        confirm.action = action === "remove" ? qsTr("Remove")
                       : action === "cancel" ? qsTr("Cancel invitation") : qsTr("Change role")
        confirm.open()
    }

    onVisibleChanged: if (settings.visible) {
        settings.section = "appearance"
        settings.focusDefault()
    } else {
        confirm.close()
        invitationEmail.clear()
    }

    Connections {
        target: Session.orgAdmin
        function onChanged() {
            if (!Session.orgAdmin.active && settings.organizationSection) {
                settings.section = "organizations"
                confirm.close()
                invitationEmail.clear()
            }
        }
        function onInvitationSent() { invitationEmail.clear() }
    }

    component Label: Text {
        Layout.fillWidth: true
        font: Theme.body
        color: Theme.textSecondary
        wrapMode: Text.Wrap
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: header.implicitHeight + 2 * Theme.gapM
            color: Theme.background
            RowLayout {
                id: header
                anchors.fill: parent
                anchors.margins: Theme.gapM
                spacing: Theme.gapM
                ActionButton {
                    id: back
                    objectName: "closeSettingsButton"
                    text: qsTr("Back to files")
                    icon: "back"
                    showLabel: !settings.narrow
                    tip: text
                    onActivated: Session.closeSettings()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gapXs
                    Caption {
                        Layout.fillWidth: true
                        text: settings.organizationSection ? Session.orgAdmin.name : Session.email
                        color: Theme.accentText
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Settings")
                        color: Theme.textPrimary
                        font: Theme.title
                        elide: Text.ElideRight
                        Accessible.role: Accessible.Heading
                    }
                }
                ActionButton {
                    objectName: "refreshOrgAdminButton"
                    visible: settings.section !== "appearance"
                    text: qsTr("Refresh")
                    icon: "refresh"
                    showLabel: false
                    tip: text
                    usable: settings.section === "organizations" ? !Session.organizationsBusy : !Session.orgAdmin.busy
                    onActivated: if (settings.section === "organizations") Session.refreshOrganizations()
                                 else Session.orgAdmin.refresh()
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

        Flickable {
            visible: settings.narrow
            Layout.fillWidth: true
            implicitHeight: tabs.implicitHeight + 2 * Theme.gapS
            contentWidth: tabs.implicitWidth + 2 * Theme.gapS
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: tabs
                x: Theme.gapS
                y: Theme.gapS
                spacing: Theme.gapXs
                Repeater {
                    model: settings.sections
                    delegate: ActionButton {
                        required property var modelData
                        text: modelData.label
                        primary: settings.section === modelData.value
                        onActivated: settings.section = modelData.value
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                visible: !settings.narrow
                Layout.preferredWidth: Theme.column
                Layout.fillHeight: true
                color: Theme.surface
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.gapM
                    spacing: Theme.gapS
                    Repeater {
                        model: settings.sections
                        delegate: ActionButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label
                            icon: modelData.icon
                            color: settings.section === modelData.value ? Theme.accentSoft : "transparent"
                            onActivated: settings.section = modelData.value
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: settings.narrow ? Theme.gapM : Theme.gapXl
                spacing: Theme.gapM

                Text {
                    Layout.fillWidth: true
                    text: settings.sections.find(function (s) { return s.value === settings.section })?.label ?? ""
                    font: Theme.heading
                    color: Theme.textPrimary
                    Accessible.role: Accessible.Heading
                }
                Label {
                    objectName: "orgAdminError"
                    visible: (settings.organizationSection && Session.orgAdmin.errorCode !== "") || settings.sectionError !== ""
                    text: Messages.adminFailure((settings.organizationSection ? Session.orgAdmin.errorCode : "") || settings.sectionError)
                    color: Theme.failed
                    Accessible.role: Accessible.AlertMessage
                }
                Label {
                    objectName: "orgAdminNotice"
                    visible: settings.organizationSection && Session.orgAdmin.notice !== ""
                    text: Messages.adminNotice(Session.orgAdmin.notice)
                    color: Theme.accentText
                }
                Label {
                    visible: settings.section === "organizations" ? Session.organizationsBusy
                             : settings.organizationSection && Session.orgAdmin.busy
                    text: qsTr("Working…")
                }

                RowLayout {
                    visible: settings.section === "organizations"
                    Layout.fillWidth: true
                    spacing: Theme.gapM
                    Label { text: qsTr("Choose an organization to manage.") }
                    ActionButton {
                        objectName: "openOrganizationsButton"
                        text: qsTr("Open organizations")
                        icon: "org"
                        showLabel: !settings.narrow
                        tip: text
                        onActivated: settings.openOrganizations("")
                    }
                }
                ListView {
                    id: organizations
                    objectName: "settingsOrganizationsList"
                    visible: settings.section === "organizations"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: Session.organizations
                    clip: true
                    spacing: Theme.gapS
                    boundsBehavior: Flickable.StopAtBounds
                    C.ScrollBar.vertical: ThinScrollBar {}
                    delegate: Rectangle {
                        id: organization
                        required property string orgId
                        required property string name
                        required property string role
                        required property bool canAdminister
                        width: organizations.width
                        implicitHeight: organizationContent.implicitHeight + 2 * Theme.gapM
                        color: Theme.surface
                        radius: Theme.rounding
                        border.color: Theme.border
                        ColumnLayout {
                            id: organizationContent
                            anchors.fill: parent
                            anchors.margins: Theme.gapM
                            spacing: Theme.gapS
                            Text {
                                Layout.fillWidth: true
                                text: organization.name
                                font: Theme.strong(Theme.body)
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Label {
                                text: Session.orgAdmin.roles.find(function (choice) {
                                    return choice.value === organization.role
                                })?.label ?? organization.role
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.gapS
                                ActionButton {
                                    objectName: "configureOrganization_" + organization.orgId
                                    visible: organization.canAdminister
                                    text: qsTr("Configure")
                                    icon: "settings"
                                    primary: true
                                    onActivated: settings.configureOrganization(organization.orgId)
                                }
                                ActionButton {
                                    objectName: "openOrganization_" + organization.orgId
                                    text: qsTr("Open organization")
                                    icon: "forward"
                                    onActivated: settings.openOrganizations(organization.orgId)
                                }
                            }
                        }
                    }
                }
                Label {
                    visible: settings.section === "organizations" && organizations.count === 0
                             && !Session.organizationsBusy && settings.sectionError === ""
                    text: qsTr("No organizations yet.")
                }

                Flickable {
                    visible: settings.section === "appearance"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: appearance.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    C.ScrollBar.vertical: ThinScrollBar {}
                    ColumnLayout {
                        id: appearance
                        width: Math.min(parent.width, Theme.measure)
                        spacing: Theme.gapM
                        Label { text: qsTr("Theme") }
                        Repeater {
                            model: ["theme-light", "theme-dark", "theme-system"]
                            delegate: ActionButton {
                                required property string modelData
                                Layout.fillWidth: true
                                objectName: "settings_" + modelData
                                text: Commands.find(Session.commandList, modelData).title
                                primary: Theme.mode === Commands.themeMode(modelData)
                                onActivated: settings.commandChosen(modelData)
                            }
                        }
                        Label { text: qsTr("Language") }
                        Repeater {
                            model: Theme.languages
                            delegate: ActionButton {
                                required property var modelData
                                Layout.fillWidth: true
                                objectName: "settings_lang-" + modelData.code
                                text: modelData.name
                                primary: Theme.language === modelData.code
                                onActivated: settings.commandChosen("lang-" + modelData.code)
                            }
                        }
                    }
                }

                Flickable {
                    visible: settings.section === "general" && settings.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: general.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    C.ScrollBar.vertical: ThinScrollBar {}
                    ColumnLayout {
                        id: general
                        width: Math.min(parent.width, Theme.measure)
                        spacing: Theme.gapM
                        Label { text: qsTr("Organization name") }
                        Field {
                            id: organizationName
                            objectName: "organizationNameField"
                            text: Session.orgAdmin.name
                            placeholderText: qsTr("Organization name")
                            enabled: !Session.orgAdmin.busy
                            onAccepted: if (saveName.usable) Session.orgAdmin.rename(text)
                        }
                        ActionButton {
                            id: saveName
                            objectName: "saveOrganizationButton"
                            text: qsTr("Save changes")
                            primary: true
                            usable: !Session.orgAdmin.busy && organizationName.text.trim() !== ""
                                    && organizationName.text.trim() !== Session.orgAdmin.name
                            onActivated: Session.orgAdmin.rename(organizationName.text)
                        }
                    }
                }

                ColumnLayout {
                    visible: settings.section === "invitations" && settings.sectionError === ""
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    Field {
                        id: invitationEmail
                        objectName: "invitationEmailField"
                        placeholderText: qsTr("Email address")
                        inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                        enabled: !Session.orgAdmin.busy
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gapS
                        RolePicker { id: invitationRole; Layout.fillWidth: true; allowOwner: false; enabled: !Session.orgAdmin.busy }
                        ActionButton {
                            objectName: "sendInvitationButton"
                            primary: true
                            text: qsTr("Invite")
                            usable: !Session.orgAdmin.busy && invitationEmail.text.trim() !== ""
                            onActivated: Session.orgAdmin.invite(invitationEmail.text, invitationRole.currentValue)
                        }
                    }
                }
                OrgAdminPeople {
                    id: members
                    visible: settings.section === "members" && settings.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    narrow: settings.narrow
                    onRoleRequested: function (id, email, role) { settings.ask("role", id, email, role) }
                    onRemovalRequested: function (id, email) { settings.ask("remove", id, email, "") }
                }
                OrgAdminPeople {
                    id: invitations
                    visible: settings.section === "invitations" && settings.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    invitations: true
                    narrow: settings.narrow
                    onCancellationRequested: function (id, email) { settings.ask("cancel", id, email, "") }
                }
                Label {
                    visible: !Session.orgAdmin.busy && settings.sectionError === ""
                             && ((settings.section === "members" && members.count === 0)
                                 || (settings.section === "invitations" && invitations.count === 0))
                    text: settings.section === "members" ? qsTr("No members to display.") : qsTr("No invitations yet.")
                }

                Flickable {
                    visible: settings.section === "usage" && settings.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: usage.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    C.ScrollBar.vertical: ThinScrollBar {}
                    ColumnLayout {
                        id: usage
                        width: parent.width
                        spacing: Theme.gapM
                        Label { text: qsTr("Plan: %1").arg(Session.orgAdmin.plan) }
                        Repeater {
                            model: Session.orgAdmin.usage
                            delegate: Rectangle {
                                id: metric
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: amount.implicitHeight + 2 * Theme.gapM
                                color: Theme.surface
                                border.color: Theme.border
                                radius: Theme.rounding
                                ColumnLayout {
                                    id: amount
                                    anchors.fill: parent
                                    anchors.margins: Theme.gapM
                                    spacing: Theme.gapS
                                    Label { text: Messages.usageName(metric.modelData.dimension) }
                                    Text {
                                        Layout.fillWidth: true
                                        text: Messages.usageAmount(metric.modelData.used, metric.modelData.dimension)
                                              + " / " + (metric.modelData.limit === null || metric.modelData.limit === undefined
                                                         ? qsTr("Unlimited")
                                                         : Messages.usageAmount(metric.modelData.limit, metric.modelData.dimension))
                                        color: Theme.textPrimary
                                        font: Theme.heading
                                        wrapMode: Text.Wrap
                                    }
                                    Label {
                                        visible: metric.modelData.reserved > 0
                                        text: qsTr("Reserved: %1").arg(Messages.usageAmount(metric.modelData.reserved, metric.modelData.dimension))
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: Theme.gapXs
                                        visible: metric.modelData.limit > 0
                                        color: Theme.border
                                        radius: Theme.rounding
                                        Rectangle {
                                            height: parent.height
                                            width: parent.width * Math.min(1, (metric.modelData.used + metric.modelData.reserved) / metric.modelData.limit)
                                            color: Theme.accent
                                            radius: parent.radius
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true; visible: settings.sectionError !== "" }
            }
        }
    }

    Confirm {
        id: confirm
        objectName: "orgAdminConfirm"
        anchors.fill: parent
        onAccepted: {
            if (settings.targetAction === "remove")
                Session.orgAdmin.removeMember(settings.targetId)
            else if (settings.targetAction === "cancel")
                Session.orgAdmin.cancelInvitation(settings.targetId)
            else
                Session.orgAdmin.changeRole(settings.targetId, settings.targetRole)
        }
        onVisibleChanged: if (!confirm.visible && settings.visible) settings.focusDefault()
    }
}
