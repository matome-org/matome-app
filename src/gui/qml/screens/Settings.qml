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
    readonly property bool organizationSection: section !== "appearance"
    property string targetId
    property string targetRole
    property string targetAction
    readonly property string sectionError: settings.section === "general" ? Session.orgAdmin.generalError
                                          : settings.section === "members" ? Session.orgAdmin.membersError
                                          : settings.section === "invitations" ? Session.orgAdmin.invitationsError
                                          : settings.section === "usage" ? Session.orgAdmin.usageError : ""
    readonly property var sections: [
        { value: "general", label: qsTr("General"), icon: "settings" },
        { value: "members", label: qsTr("Members"), icon: "user" },
        { value: "invitations", label: qsTr("Invitations"), icon: "new" },
        { value: "usage", label: qsTr("Usage"), icon: "space" }
    ]

    function chooseSection(id, value) {
        if (id !== "" && id !== Session.currentOrgId)
            Session.navigate("org", id)
        if (id === "" || (Session.currentOrgId === id && Session.orgAdmin.available))
            settings.section = value
        navigationDrawer.close()
    }
    function openOrganizations(id) {
        Session.closeSettings()
        Session.navigate(id === "" ? "root" : "org", id)
    }
    function focusDefault() { back.forceActiveFocus() }
    function dismiss() {
        if (navigationDrawer.visible)
            navigationDrawer.close()
        else if (confirm.visible)
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
        navigationDrawer.close()
        confirm.close()
        invitationEmail.clear()
    }

    onNarrowChanged: if (!settings.narrow) navigationDrawer.close()

    Connections {
        target: Session.orgAdmin
        function onChanged() {
            if (!Session.orgAdmin.active && settings.organizationSection) {
                settings.section = "appearance"
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

    component NavigationRow: FocusableControl {
        id: row
        property string text
        property string icon
        property bool selected: false
        property bool checkable: false
        property bool indented: false
        property bool strong: false
        Layout.fillWidth: true
        implicitHeight: settings.narrow ? Theme.rowTouch : Theme.controlM
        color: row.selected ? Theme.accentSoft : "transparent"
        radius: Theme.rounding
        Accessible.role: Accessible.Button
        Accessible.name: row.text
        Accessible.checkable: row.checkable
        Accessible.checked: row.selected
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: row.indented ? 2 * Theme.gapM : Theme.gapM
            anchors.rightMargin: Theme.gapM
            spacing: Theme.gapS
            Icon { name: row.icon; color: row.selected ? Theme.accentText : Theme.textSecondary }
            Text {
                Layout.fillWidth: true
                text: row.text
                font: row.strong ? Theme.strong(Theme.body) : Theme.body
                color: row.selected ? Theme.accentText : Theme.textPrimary
                elide: Text.ElideRight
            }
        }
    }

    component Navigation: Flickable {
        id: navigation
        clip: true
        contentHeight: navigationColumn.implicitHeight + 2 * Theme.gapM
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: ThinScrollBar {}
        Component.onCompleted: if (settings.narrow) appearanceNavigation.forceActiveFocus()

        function reveal(item) {
            const top = item.mapToItem(navigationColumn, 0, 0).y + Theme.gapM
            if (top < contentY)
                contentY = top
            else if (top + item.height > contentY + height)
                contentY = top + item.height - height
        }

        ColumnLayout {
            id: navigationColumn
            x: Theme.gapS
            y: Theme.gapM
            width: navigation.width - 2 * Theme.gapS
            spacing: Theme.gapXs
            NavigationRow {
                id: appearanceNavigation
                objectName: "settingsAppearanceNavigation"
                checkable: true
                text: qsTr("Appearance")
                icon: "settings"
                selected: settings.section === "appearance"
                onActivated: settings.chooseSection("", "appearance")
                onActiveFocusChanged: if (activeFocus) navigation.reveal(this)
            }
            Caption {
                Layout.fillWidth: true
                Layout.topMargin: Theme.gapM
                Layout.leftMargin: Theme.gapM
                text: qsTr("Organizations")
            }
            Label {
                Layout.margins: Theme.gapS
                visible: Session.organizationsBusy || Session.organizationsError !== ""
                text: Session.organizationsError !== "" ? Messages.adminFailure(Session.organizationsError)
                                                       : qsTr("Working…")
                color: Session.organizationsError !== "" ? Theme.failed : Theme.textSecondary
            }
            Repeater {
                id: organizationGroups
                model: Session.organizations
                delegate: ColumnLayout {
                    id: organization
                    required property string orgId
                    required property string name
                    required property bool canAdminister
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.gapS
                    spacing: Theme.gapXs
                    NavigationRow {
                        objectName: "settingsOrganization_" + organization.orgId
                        text: organization.name
                        icon: "org"
                        strong: true
                        onActivated: if (organization.canAdminister)
                                         settings.chooseSection(organization.orgId, "general")
                                     else settings.openOrganizations(organization.orgId)
                        onActiveFocusChanged: if (activeFocus) navigation.reveal(this)
                    }
                    Repeater {
                        model: organization.canAdminister ? settings.sections : []
                        delegate: NavigationRow {
                            required property var modelData
                            checkable: true
                            objectName: "settingsOrganization_" + organization.orgId + "_" + modelData.value
                            text: modelData.label
                            icon: modelData.icon
                            indented: true
                            selected: Session.currentOrgId === organization.orgId && settings.section === modelData.value
                            onActivated: settings.chooseSection(organization.orgId, modelData.value)
                            onActiveFocusChanged: if (activeFocus) navigation.reveal(this)
                        }
                    }
                    NavigationRow {
                        text: qsTr("Open organization")
                        icon: "forward"
                        indented: true
                        onActivated: settings.openOrganizations(organization.orgId)
                        onActiveFocusChanged: if (activeFocus) navigation.reveal(this)
                    }
                }
            }
            Label {
                Layout.margins: Theme.gapM
                visible: organizationGroups.count === 0 && !Session.organizationsBusy
                         && Session.organizationsError === ""
                text: qsTr("No organizations yet.")
            }
            NavigationRow {
                Layout.topMargin: Theme.gapM
                text: qsTr("Open organizations")
                icon: "org"
                onActivated: settings.openOrganizations("")
                onActiveFocusChanged: if (activeFocus) navigation.reveal(this)
            }
        }
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
                    id: navigationToggle
                    objectName: "settingsNavigationButton"
                    visible: settings.narrow
                    text: qsTr("Navigation")
                    icon: "menu"
                    showLabel: false
                    tip: text
                    onActivated: navigationDrawer.open()
                }
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
                    text: qsTr("Refresh")
                    icon: "refresh"
                    showLabel: false
                    tip: text
                    usable: settings.organizationSection ? !Session.orgAdmin.busy : !Session.organizationsBusy
                    onActivated: if (settings.organizationSection) Session.orgAdmin.refresh()
                                 else Session.refreshOrganizations()
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                visible: !settings.narrow
                Layout.preferredWidth: Theme.column
                Layout.fillHeight: true
                color: Theme.surface
                Loader {
                    anchors.fill: parent
                    active: settings.visible && !settings.narrow
                    sourceComponent: Navigation {}
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: settings.narrow ? Theme.gapM : Theme.gapXl
                spacing: Theme.gapM

                Text {
                    Layout.fillWidth: true
                    text: settings.section === "appearance" ? qsTr("Appearance")
                          : settings.sections.find(function (s) { return s.value === settings.section })?.label ?? ""
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
                    visible: settings.organizationSection && Session.orgAdmin.busy
                    text: qsTr("Working…")
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

    C.Drawer {
        id: navigationDrawer
        objectName: "settingsNavigationDrawer"
        width: Math.min(Theme.column + 2 * Theme.gapM, settings.width - Theme.gapXl)
        height: settings.height
        edge: Qt.LeftEdge
        modal: true
        focus: true
        padding: 0
        background: Rectangle { color: Theme.surface }
        C.Overlay.modal: Rectangle {
            color: Theme.dark ? Theme.fill(Theme.background, 0.66) : Theme.fill(Theme.textPrimary, 0.32)
        }
        contentItem: Loader {
            active: navigationDrawer.visible
            sourceComponent: Navigation {}
        }
        onClosed: if (settings.visible && settings.narrow) navigationToggle.forceActiveFocus()
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
