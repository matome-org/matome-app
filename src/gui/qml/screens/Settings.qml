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
                                          : settings.section === "usage" ? Session.orgBilling.usageError
                                          : settings.section === "spaces" ? Session.spaceAccess.errorCode : ""
    readonly property var sections: [
        { value: "general", label: qsTr("General"), icon: "settings" },
        { value: "members", label: qsTr("Members"), icon: "user" },
        { value: "invitations", label: qsTr("Invitations"), icon: "new" },
        { value: "spaces", label: qsTr("Spaces"), icon: "space" },
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
        else if (grantDialog.visible)
            grantDialog.close()
        else
            Session.closeSettings()
    }
    function ask(action, id, email) {
        settings.targetId = id
        settings.targetAction = action
        confirm.title = action === "remove" ? qsTr("Remove %1?").arg(email)
                      : action === "cancel" ? qsTr("Cancel invitation for %1?").arg(email)
                      : action === "revoke" ? qsTr("Revoke this access grant?")
                      : qsTr("Remove this space rule?")
        confirm.detail = action === "remove" ? qsTr("This person will lose access to the organization.")
                       : action === "cancel" ? qsTr("The invitation link will stop working.")
                       : action === "revoke" ? qsTr("%1 loses what this role allows in the space. Access from other grants is preserved.").arg(email)
                       : qsTr("Existing controlled documents will remain blocked until the rule is reactivated or their control is removed.")
        confirm.reasonLabel = action === "remove-rule" ? qsTr("Reason for removing the space rule") : ""
        confirm.action = action === "remove" ? qsTr("Remove")
                       : action === "cancel" ? qsTr("Cancel invitation")
                       : action === "revoke" ? qsTr("Revoke") : qsTr("Remove rule")
        confirm.open()
    }
    // Space settings follow the space picked in the Spaces section.
    function openSpace(id) {
        Session.spaceAccess.open(id)
        Session.controlledRule.open(id)
    }
    function closeDialogs() {
        confirm.close()
        grantDialog.close()
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
        Session.spaceAccess.close()
        Session.controlledRule.close()
    }

    onNarrowChanged: if (!settings.narrow) navigationDrawer.close()
    onSectionChanged: if (settings.section === "spaces") {
        if (spacePicker.currentValue)
            settings.openSpace(spacePicker.currentValue)
    } else {
        Session.spaceAccess.close()
        Session.controlledRule.close()
    }

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
        target: Session.controlledRule
        function onAccessChanged() { Session.spaceAccess.refresh() }
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
                        visible: settings.section === "spaces" && Session.controlledRule.rolesMissing
                        text: qsTr("Add review roles")
                        icon: "new"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.controlledRule.busy
                        onActivated: Session.controlledRule.addRoles()
                    }
                    ActionButton {
                        visible: settings.section === "spaces" && Session.controlledRule.readable
                        text: Session.controlledRule.rule.require_version_references === true
                              ? qsTr("Let links follow new versions") : qsTr("Require pinned versions")
                        icon: "image"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.controlledRule.busy && Session.controlledRule.rule.id !== undefined
                        onActivated: Session.controlledRule.save(Session.controlledRule.rule.active === true,
                                                                 Session.controlledRule.rule.require_version_references !== true)
                    }
                    ActionButton {
                        visible: settings.section === "spaces" && Session.controlledRule.readable && Session.controlledRule.rule.id !== undefined
                        text: qsTr("Remove space rule")
                        icon: "trash"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.controlledRule.busy
                        onActivated: settings.ask("remove-rule", "", "")
                    }
                    ActionButton {
                        visible: settings.section === "spaces" && Session.controlledRule.readable
                        text: Session.controlledRule.rule.active === true ? qsTr("Pause space rule") : qsTr("Activate space rule")
                        icon: Session.controlledRule.rule.active === true ? "pause" : "check"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.controlledRule.busy
                        onActivated: Session.controlledRule.save(Session.controlledRule.rule.active !== true,
                                                                 Session.controlledRule.rule.require_version_references === true)
                    }
                    ActionButton {
                        visible: settings.section === "spaces" && Session.controlledRule.canGrantSelf
                        text: qsTr("Grant me management access")
                        icon: "user"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.controlledRule.busy
                        onActivated: Session.controlledRule.grantSelf()
                    }
                    BarRule { visible: settings.section === "spaces" && Session.controlledRule.installed }
                    ActionButton {
                        objectName: "revokeSpaceAccessButton"
                        visible: settings.section === "spaces"
                        text: qsTr("Revoke access")
                        icon: "close"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !Session.spaceAccess.busy && grants.currentGrant !== null
                        onActivated: settings.ask("revoke", grants.currentGrant.id, grants.currentGrant.email || qsTr("This group"))
                    }
                    ActionButton {
                        objectName: "grantSpaceAccessButton"
                        visible: settings.section === "spaces"
                        text: qsTr("Grant access")
                        icon: "new"
                        primary: true
                        usable: Session.spaceAccess.active && !Session.spaceAccess.busy && Session.spaceAccess.roles.length > 0
                        onActivated: grantDialog.open()
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
                    visible: settings.section === "spaces" && (Session.spaceAccess.notice !== "" || Session.controlledRule.notice !== "")
                    text: Messages.controlledNotice(Session.controlledRule.notice || Session.spaceAccess.notice)
                    color: Theme.accentText
                }
                Label {
                    visible: settings.section === "spaces" && Session.controlledRule.errorCode !== ""
                    text: Messages.controlledFailure(Session.controlledRule.errorCode)
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
                    objectName: "spacesPage"
                    visible: settings.section === "spaces"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Label { text: qsTr("Who may do what in a space, and the add-ons that work there. Pick the space to manage.") }
                    Picker {
                        id: spacePicker
                        objectName: "spacePicker"
                        Layout.fillWidth: true
                        Layout.maximumWidth: Theme.column * 2
                        model: Session.spaceAccess.spaces
                        value: Session.currentSpaceId !== "" ? Session.currentSpaceId : (Session.spaceAccess.spaces[0]?.value ?? "")
                        Accessible.name: qsTr("Space")
                        onCurrentValueChanged: if (settings.section === "spaces" && spacePicker.currentValue)
                            settings.openSpace(spacePicker.currentValue)
                    }
                    Caption { Layout.fillWidth: true; Layout.topMargin: Theme.gapM; text: qsTr("Access") }
                    Label {
                        visible: Session.spaceAccess.active && !Session.spaceAccess.busy && grants.count === 0
                        text: qsTr("Nobody has a role in this space yet. Organization owners and administrators still manage it.")
                    }
                    CursorList {
                        id: grants
                        readonly property var currentGrant: grants.currentIndex >= 0 ? Session.spaceAccess.grants[grants.currentIndex] ?? null : null
                        objectName: "spaceGrantList"
                        visible: grants.count > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: grants.contentHeight
                        interactive: false
                        activeFocusOnTab: true
                        spacing: Theme.gapS
                        rowHeight: settings.narrow ? Theme.rowTouch : Theme.controlM
                        model: Session.spaceAccess.grants
                        Accessible.role: Accessible.List
                        Accessible.name: qsTr("Access")
                        delegate: ListRow {
                            id: grantRow
                            required property var modelData
                            required property int index
                            view: grants
                            touch: settings.narrow
                            cursor: grants.currentIndex === grantRow.index
                            selected: grantRow.cursor
                            title: grantRow.modelData.email || qsTr("Group")
                            detail: grantRow.modelData.roleName
                            onClicked: grants.currentIndex = grantRow.index
                            onActivated: grants.currentIndex = grantRow.index
                        }
                    }
                    Card {
                        objectName: "controlledSpaceCard"
                        visible: Session.controlledRule.installed
                        Layout.topMargin: Theme.gapM
                        Caption { Layout.fillWidth: true; text: qsTr("Controlled documents") }
                        Text {
                            Layout.fillWidth: true
                            text: Session.controlledRule.canGrantSelf || Session.controlledRule.ruleError === "forbidden"
                                  ? qsTr("You need management access")
                                  : Session.controlledRule.rule.active === true ? qsTr("Space rule active") : qsTr("Space rule inactive or absent")
                            font: Theme.heading
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                        }
                        Label {
                            visible: Session.controlledRule.ruleError === "forbidden"
                            text: Session.controlledRule.canGrantSelf
                                  ? qsTr("Organization administrators manage document control only through an explicit grant: use Grant me management access above.")
                                  : qsTr("Ask an organization administrator to grant you the Document control managers role here.")
                        }
                        Label {
                            visible: Session.controlledRule.readable
                            text: Session.controlledRule.rule.require_version_references === true
                                  ? qsTr("Images and linked files must pin a version, so an approved document shows exactly what was reviewed.")
                                  : qsTr("Images and linked files may follow later versions of their files.")
                        }
                        Label {
                            visible: Session.controlledRule.rolesMissing
                            text: qsTr("Add review roles to grant reviewer and manager access under Access.")
                        }
                    }
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

    Dialog {
        id: grantDialog
        objectName: "grantSpaceAccessDialog"
        anchors.fill: parent
        title: qsTr("Grant access to %1").arg(spacePicker.currentText)
        action: qsTr("Grant")
        ready: grantMember.currentIndex >= 0 && grantRole.currentIndex >= 0
        initialFocus: grantMember
        onAccepted: Session.spaceAccess.grant(grantMember.currentValue, grantRole.currentValue)
        Label { text: qsTr("Member") }
        Picker {
            id: grantMember
            Layout.fillWidth: true
            model: Session.spaceAccess.members
            Accessible.name: qsTr("Member")
        }
        Label { text: qsTr("Role in this space") }
        Picker {
            id: grantRole
            Layout.fillWidth: true
            model: Session.spaceAccess.roles
            Accessible.name: qsTr("Role in this space")
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
            else if (settings.targetAction === "revoke")
                Session.spaceAccess.revoke(settings.targetId)
            else
                Session.controlledRule.remove(confirm.reason)
        }
        onVisibleChanged: if (!confirm.visible && settings.visible) settings.focusDefault()
    }
}
