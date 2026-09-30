pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

FocusScope {
    id: settings

    readonly property bool narrow: settings.width < 600
    signal commandChosen(string id)

    property string section: "appearance"
    property var expandedOrganizations: ({})
    readonly property bool commerceSection: section === "billing" || section === "addons"
    readonly property bool organizationSection: section !== "appearance"
    property string targetId
    property string targetAction
    readonly property string sectionError: settings.section === "general" ? Session.orgAdmin.generalError
                                          : settings.section === "members" ? Session.orgAdmin.membersError
                                          : settings.section === "invitations" ? Session.orgAdmin.invitationsError
                                          : settings.section === "usage" ? Session.orgBilling.usageError : ""
    readonly property var sections: [
        { value: "general", label: qsTr("General"), icon: "settings" },
        { value: "members", label: qsTr("Members"), icon: "user" },
        { value: "invitations", label: qsTr("Invitations"), icon: "new" },
        { value: "usage", label: qsTr("Usage"), icon: "space", billing: true },
        { value: "billing", label: qsTr("Plan and billing"), icon: "settings", billing: true },
        { value: "addons", label: qsTr("Add-ons"), icon: "new", billing: true }
    ]

    function setOrganizationExpanded(id, expanded) {
        const groups = Object.assign({}, settings.expandedOrganizations)
        groups[id] = expanded
        settings.expandedOrganizations = groups
    }
    function chooseSection(id, value) {
        if (id !== "" && id !== Session.currentOrgId)
            Session.navigate("org", id)
        if (id === "" || (Session.currentOrgId === id && (value === "billing" || value === "addons" || value === "usage"
                    ? Session.orgBilling.available : Session.orgAdmin.available))) {
            settings.section = value
            if (id !== "") settings.setOrganizationExpanded(id, true)
        }
        navigationDrawer.close()
    }
    function openOrganizations(id) {
        Session.closeSettings()
        Session.navigate(id === "" ? "root" : "org", id)
    }
    function focusDefault() { header.backButton.forceActiveFocus() }
    function dismiss() {
        if (navigationDrawer.visible)
            navigationDrawer.close()
        else if (commerce.dismiss())
            return
        else if (confirm.visible)
            confirm.close()
        else if (renameDialog.visible)
            renameDialog.close()
        else if (roleDialog.visible)
            roleDialog.close()
        else if (inviteDialog.visible)
            inviteDialog.close()
        else
            Session.closeSettings()
    }
    function ask(action, id, email) {
        settings.targetId = id
        settings.targetAction = action
        confirm.title = action === "remove" ? qsTr("Remove %1?").arg(email) : qsTr("Cancel invitation for %1?").arg(email)
        confirm.detail = action === "remove" ? qsTr("This person will lose access to the organization.")
                                             : qsTr("The invitation link will stop working.")
        confirm.action = action === "remove" ? qsTr("Remove") : qsTr("Cancel invitation")
        confirm.open()
    }
    function closeDialogs() {
        confirm.close()
        renameDialog.close()
        roleDialog.close()
        inviteDialog.close()
    }
    function openRole() {
        if (members.currentId === "" || Session.orgAdmin.busy)
            return
        memberRole.value = members.currentRole
        roleDialog.open()
    }

    onVisibleChanged: if (settings.visible) {
        settings.section = "appearance"
        settings.expandedOrganizations = ({})
        if (Session.currentOrgId !== "") settings.setOrganizationExpanded(Session.currentOrgId, true)
        settings.focusDefault()
    } else {
        navigationDrawer.close()
        settings.closeDialogs()
    }

    onNarrowChanged: if (!settings.narrow) navigationDrawer.close()

    Connections {
        target: Session.orgAdmin
        function onChanged() {
            if (!Session.orgAdmin.active && settings.organizationSection && !settings.commerceSection && settings.section !== "usage") {
                settings.section = "appearance"
                settings.closeDialogs()
            }
        }
    }

    Connections {
        target: Session.orgBilling
        function onChanged() {
            if (!Session.orgBilling.active && (settings.commerceSection || settings.section === "usage"))
                settings.section = "appearance"
        }
    }

    component Navigation: Page {
        topMargin: Theme.gapM
        bottomMargin: Theme.gapM
        leftMargin: Theme.gapS
        rightMargin: Theme.gapS
        spacing: Theme.gapXs
        Component.onCompleted: if (settings.narrow) appearanceNavigation.forceActiveFocus()

        NavigationRow {
            id: appearanceNavigation
            touch: settings.narrow
            objectName: "settingsAppearanceNavigation"
            checkable: true
            text: qsTr("Appearance")
            icon: "settings"
            selected: settings.section === "appearance"
            onActivated: settings.chooseSection("", "appearance")
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
                required property bool canReadBilling
                readonly property bool expanded: settings.expandedOrganizations[orgId] === true
                Layout.fillWidth: true
                Layout.topMargin: Theme.gapS
                spacing: Theme.gapXs
                NavigationRow {
                    objectName: "settingsOrganization_" + organization.orgId
                    touch: settings.narrow
                    text: organization.name
                    icon: "org"
                    strong: true
                    expandable: true
                    expanded: organization.expanded
                    selected: Session.currentOrgId === organization.orgId && settings.organizationSection
                              && !organization.expanded
                    onActivated: settings.setOrganizationExpanded(organization.orgId, !organization.expanded)
                    Keys.onRightPressed: settings.setOrganizationExpanded(organization.orgId, true)
                    Keys.onLeftPressed: settings.setOrganizationExpanded(organization.orgId, false)
                    }
                Repeater {
                    model: organization.expanded ? settings.sections.filter(function (s) {
                        return s.billing === true ? organization.canReadBilling : organization.canAdminister
                    }) : []
                    delegate: NavigationRow {
                        required property var modelData
                        touch: settings.narrow
                        checkable: true
                        objectName: "settingsOrganization_" + organization.orgId + "_" + modelData.value
                        text: modelData.label
                        icon: modelData.icon
                        indented: true
                        selected: Session.currentOrgId === organization.orgId && settings.section === modelData.value
                        onActivated: settings.chooseSection(organization.orgId, modelData.value)
                            }
                }
                NavigationRow {
                    visible: organization.expanded
                    touch: settings.narrow
                    text: qsTr("Open organization")
                    icon: "forward"
                    indented: true
                    onActivated: settings.openOrganizations(organization.orgId)
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
            touch: settings.narrow
            text: qsTr("Open organizations")
            icon: "org"
            onActivated: settings.openOrganizations("")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ScreenHeader {
            id: header
            Layout.fillWidth: true
            narrow: settings.narrow
            caption: settings.organizationSection ? Session.orgBilling.name : Session.email
            title: qsTr("Settings")
            backText: qsTr("Back to files")
            navigationName: "settingsNavigationButton"
            backName: "closeSettingsButton"
            refreshName: "refreshOrgAdminButton"
            refreshUsable: settings.commerceSection || settings.section === "usage" ? !Session.orgBilling.busy
                           : settings.organizationSection ? !Session.orgAdmin.busy : !Session.organizationsBusy
            onNavigationRequested: navigationDrawer.open()
            onBackRequested: Session.closeSettings()
            onRefreshRequested: if (settings.commerceSection || settings.section === "usage") Session.orgBilling.refresh()
                                else if (settings.organizationSection) Session.orgAdmin.refresh()
                                else Session.refreshOrganizations()
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

                SectionHead {
                    title: settings.section === "appearance" ? qsTr("Appearance")
                           : settings.sections.find(function (s) { return s.value === settings.section })?.label ?? ""

                    ActionButton {
                        objectName: "renameOrganizationButton"
                        visible: settings.section === "general"
                        text: qsTr("Rename organization")
                        icon: "rename"
                        primary: true
                        usable: !Session.orgAdmin.busy && settings.sectionError === ""
                        onActivated: renameDialog.open()
                    }

                    ActionButton {
                        objectName: "changeRoleButton"
                        visible: settings.section === "members"
                        text: qsTr("Change role")
                        icon: "user"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.orgAdmin.busy && members.currentId !== ""
                        onActivated: settings.openRole()
                    }
                    ActionButton {
                        objectName: "removeMemberButton"
                        visible: settings.section === "members"
                        text: qsTr("Remove member")
                        icon: "trash"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.orgAdmin.busy && members.currentId !== ""
                        onActivated: settings.ask("remove", members.currentId, members.currentEmail)
                    }

                    ActionButton {
                        objectName: "cancelInvitationButton"
                        visible: settings.section === "invitations"
                        text: qsTr("Cancel invitation")
                        icon: "close"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.orgAdmin.busy && invitations.currentStatus === "pending"
                        onActivated: settings.ask("cancel", invitations.currentId, invitations.currentEmail)
                    }
                    ActionButton {
                        objectName: "sendInvitationButton"
                        visible: settings.section === "invitations"
                        text: qsTr("Invite member")
                        icon: "new"
                        primary: true
                        usable: !Session.orgAdmin.busy && settings.sectionError === ""
                        onActivated: inviteDialog.open()
                    }

                    ActionButton {
                        objectName: "openBillingPortalButton"
                        visible: settings.section === "billing" && Session.orgBilling.paymentUrl !== ""
                        text: Session.orgBilling.notice === "checkout" ? qsTr("Continue to checkout") : qsTr("Open Stripe portal")
                        icon: "forward"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !commerce.busy && Session.orgBilling.canManage
                        onActivated: Qt.openUrlExternally(Session.orgBilling.paymentUrl)
                    }
                    ActionButton {
                        objectName: "billingPortalButton"
                        visible: settings.section === "billing" && Session.orgBilling.canManage
                        text: qsTr("Manage billing")
                        icon: "settings"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !commerce.busy
                        onActivated: Session.orgBilling.createPortal()
                    }
                    ActionButton {
                        objectName: "subscribePackageButton"
                        visible: settings.section === "billing" && Session.orgBilling.canManage
                        text: commerce.liveSubscription ? qsTr("Switch package") : qsTr("Subscribe")
                        icon: "check"
                        primary: true
                        usable: commerce.canSubscribe
                        onActivated: commerce.subscribe()
                    }

                    ActionButton {
                        objectName: "changeQuantityButton"
                        visible: settings.section === "addons" && Session.orgBilling.canManage
                        text: qsTr("Change quantity")
                        icon: "rename"
                        showLabel: !settings.narrow
                        tip: text
                        usable: commerce.canChangeQuantity
                        onActivated: commerce.changeQuantity()
                    }
                    ActionButton {
                        objectName: "pauseAddonButton"
                        visible: settings.section === "addons" && Session.addOns.canInstall
                        text: qsTr("Pause installation")
                        icon: "pause"
                        showLabel: !settings.narrow
                        tip: text
                        usable: commerce.canPause
                        onActivated: commerce.pause()
                    }
                    ActionButton {
                        objectName: "uninstallAddonButton"
                        visible: settings.section === "addons" && Session.addOns.canInstall
                        text: qsTr("Uninstall")
                        icon: "trash"
                        showLabel: !settings.narrow
                        tip: text
                        usable: commerce.canUninstall
                        onActivated: commerce.uninstall()
                    }
                    ActionButton {
                        objectName: "installAddonButton"
                        visible: settings.section === "addons" && Session.addOns.canInstall
                        text: commerce.installLabel
                        icon: "check"
                        primary: true
                        usable: commerce.canInstall
                        onActivated: commerce.install()
                    }
                }
                Label {
                    objectName: "orgAdminError"
                    visible: (settings.organizationSection && !settings.commerceSection && Session.orgAdmin.errorCode !== "") || settings.sectionError !== ""
                    text: Messages.adminFailure((settings.organizationSection && !settings.commerceSection ? Session.orgAdmin.errorCode : "") || settings.sectionError)
                    color: Theme.failed
                    Accessible.role: Accessible.AlertMessage
                }
                Label {
                    objectName: "orgAdminNotice"
                    visible: settings.organizationSection && !settings.commerceSection && Session.orgAdmin.notice !== ""
                    text: Messages.adminNotice(Session.orgAdmin.notice)
                    color: Theme.accentText
                }
                Label {
                    visible: settings.section === "usage" ? Session.orgBilling.busy
                             : settings.organizationSection && !settings.commerceSection && Session.orgAdmin.busy
                    text: qsTr("Working…")
                }

                OrgCommerce {
                    id: commerce
                    visible: settings.commerceSection
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    billing: settings.section === "billing"
                    narrow: settings.narrow
                }

                Page {
                    visible: settings.section === "appearance"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    measure: Theme.measure
                    Label { text: qsTr("Theme") }
                    Picker {
                        id: themePicker
                        objectName: "themePicker"
                        Layout.fillWidth: true
                        model: [{ value: "light", label: qsTr("Light") },
                                { value: "dark", label: qsTr("Dark") },
                                { value: "system", label: qsTr("Same as the system") }]
                        value: Theme.mode
                        Accessible.name: qsTr("Theme")
                        onActivated: settings.commandChosen("theme-" + themePicker.currentValue)
                    }
                    Label { text: qsTr("Language") }
                    Picker {
                        id: languagePicker
                        objectName: "languagePicker"
                        Layout.fillWidth: true
                        model: Theme.languages.map(function (choice) { return { value: choice.code, label: choice.name } })
                        value: Theme.language
                        Accessible.name: qsTr("Language")
                        onActivated: settings.commandChosen("lang-" + languagePicker.currentValue)
                    }
                }

                Page {
                    visible: settings.section === "general" && settings.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TileGrid {
                        Card {
                            Layout.alignment: Qt.AlignTop
                            Caption { Layout.fillWidth: true; text: qsTr("Organization name") }
                            Text {
                                objectName: "organizationName"
                                Layout.fillWidth: true
                                text: Session.orgAdmin.name
                                font: Theme.heading
                                color: Theme.textPrimary
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }

                OrgAdminPeople {
                    id: members
                    visible: settings.section === "members" && settings.sectionError === "" && members.count > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    touch: settings.narrow
                    onOpened: settings.openRole()
                }
                OrgAdminPeople {
                    id: invitations
                    visible: settings.section === "invitations" && settings.sectionError === "" && invitations.count > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    invitations: true
                    touch: settings.narrow
                    onOpened: if (invitations.currentStatus === "pending")
                        settings.ask("cancel", invitations.currentId, invitations.currentEmail)
                }
                Label {
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignTop
                    visible: !Session.orgAdmin.busy && settings.sectionError === ""
                             && ((settings.section === "members" && members.count === 0)
                                 || (settings.section === "invitations" && invitations.count === 0))
                    text: settings.section === "members" ? qsTr("No members to display.") : qsTr("No invitations yet. Use Invite member to send one.")
                }

                Page {
                    visible: settings.section === "usage" && settings.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Label { text: qsTr("Plan: %1").arg(Session.orgBilling.plan) }
                    TileGrid {
                        Repeater {
                            model: Session.orgBilling.usage
                            delegate: Card {
                                id: metric
                                required property var modelData
                                Layout.alignment: Qt.AlignTop
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
                Item { Layout.fillHeight: true; visible: settings.sectionError !== "" }
            }
        }
    }

    NavigationDrawer {
        id: navigationDrawer
        objectName: "settingsNavigationDrawer"
        navigation: Navigation {}
        onClosed: if (settings.visible && settings.narrow) header.navigationButton.forceActiveFocus()
    }

    Dialog {
        id: renameDialog
        objectName: "renameOrganizationDialog"
        anchors.fill: parent
        title: qsTr("Rename organization")
        action: qsTr("Save changes")
        ready: organizationName.text.trim() !== "" && organizationName.text.trim() !== Session.orgAdmin.name
        initialFocus: organizationName
        onVisibleChanged: if (renameDialog.visible) {
            organizationName.text = Session.orgAdmin.name
            organizationName.selectAll()
        }
        onAccepted: Session.orgAdmin.rename(organizationName.text)
        Field {
            id: organizationName
            objectName: "organizationNameField"
            placeholderText: qsTr("Organization name")
            onAccepted: renameDialog.accept()
        }
    }

    Dialog {
        id: roleDialog
        objectName: "changeRoleDialog"
        anchors.fill: parent
        title: qsTr("Change the role of %1").arg(members.currentEmail)
        action: qsTr("Change role")
        ready: memberRole.currentIndex >= 0 && memberRole.currentValue !== members.currentRole
        initialFocus: memberRole
        onAccepted: Session.orgAdmin.changeRole(members.currentId, memberRole.currentValue)
        Label { text: qsTr("Their organization permissions will change.") }
        RolePicker {
            id: memberRole
            Layout.fillWidth: true
        }
    }

    Dialog {
        id: inviteDialog
        objectName: "inviteDialog"
        anchors.fill: parent
        title: qsTr("Invite member")
        action: qsTr("Send invitation")
        ready: invitationEmail.text.trim() !== "" && invitationRole.currentIndex >= 0
        initialFocus: invitationEmail
        onVisibleChanged: if (inviteDialog.visible) {
            invitationEmail.clear()
            invitationRole.value = "member"
        }
        onAccepted: Session.orgAdmin.invite(invitationEmail.text, invitationRole.currentValue)
        Label { text: qsTr("They receive an email with a link to join this organization.") }
        Field {
            id: invitationEmail
            objectName: "invitationEmailField"
            placeholderText: qsTr("Email address")
            inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
            onAccepted: inviteDialog.accept()
        }
        RolePicker {
            id: invitationRole
            Layout.fillWidth: true
            allowOwner: false
        }
    }

    Confirm {
        id: confirm
        objectName: "orgAdminConfirm"
        anchors.fill: parent
        onAccepted: {
            if (settings.targetAction === "remove")
                Session.orgAdmin.removeMember(settings.targetId)
            else
                Session.orgAdmin.cancelInvitation(settings.targetId)
        }
        onVisibleChanged: if (!confirm.visible && settings.visible) settings.focusDefault()
    }
}
