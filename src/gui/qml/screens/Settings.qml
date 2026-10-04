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
    readonly property bool accessSection: ["members", "groups", "roles", "spaces", "tags"].includes(section)
    readonly property bool organizationSection: section !== "appearance" && section !== "tokens"
    readonly property string sectionError: settings.section === "general" ? Session.orgAdmin.generalError
                                          : settings.section === "members" ? Session.orgAdmin.membersError || Session.orgAdmin.invitationsError
                                          : settings.section === "usage" ? Session.orgBilling.usageError : ""
    readonly property var sections: [
        { value: "general", label: qsTr("General"), icon: "settings" },
        { value: "members", label: qsTr("People"), icon: "user" },
        { value: "groups", label: qsTr("Groups"), icon: "group" },
        { value: "roles", label: qsTr("Roles"), icon: "role" },
        { value: "spaces", label: qsTr("Spaces"), icon: "access" },
        { value: "tags", label: qsTr("Tags"), icon: "tag" },
        { value: "usage", label: qsTr("Usage"), icon: "space" },
        { value: "billing", label: qsTr("Plan and billing"), icon: "settings" },
        { value: "addons", label: qsTr("Add-ons"), icon: "new" }
    ]

    function setOrganizationExpanded(id, expanded) {
        const groups = Object.assign({}, settings.expandedOrganizations)
        groups[id] = expanded
        settings.expandedOrganizations = groups
    }
    // Core does not push membership changes: People reloads on entry and when
    // the window is back in front, so an accepted invitation shows.
    function refreshPeople() {
        if (settings.visible && settings.section === "members")
            Session.orgAdmin.refresh()
    }
    // The sections of organization `id` its catalog lets the person open.
    function sectionsOf(id) {
        return Session.permissions.revision >= 0 ? Session.permissions.sections(id) : []
    }
    function chooseSection(id, value) {
        if (id !== "" && id !== Session.currentOrgId)
            Session.navigate("org", id)
        if (id === "" || (Session.currentOrgId === id && settings.sectionsOf(id).includes(value))) {
            const entering = settings.section !== value
            settings.section = value
            if (entering) settings.refreshPeople()
            if (id !== "") settings.setOrganizationExpanded(id, true)
        }
        navigationDrawer.close()
    }
    function openOrganizations(id) {
        Session.closeSettings()
        Session.navigate(id === "" ? "root" : "org", id)
    }
    function focusDefault() { header.backButton.forceActiveFocus() }
    // Opens the page of entry `id` under `section`, such as a person under
    // People, a space under Spaces, or an add-on under Add-ons, on its tab
    // `tab` when given.
    function openEntry(section, id, name, tab) {
        settings.chooseSection(Session.currentOrgId, section)
        if (settings.section === section && section === "addons")
            commerce.open(id)
        else if (settings.section === section)
            accessAdmin.open(id, name, undefined, tab)
    }
    // Opens what fixes a refusal (Permissions' `explain`): the plan, the
    // add-on, or the space where access is given or the add-on turned on.
    function fix(answer) {
        if (answer.fix === "plan")
            settings.chooseSection(Session.currentOrgId, "billing")
        else if (answer.fix === "install" || answer.fix === "resume")
            settings.openEntry("addons", answer.product, Messages.productName(answer.product, answer.productName), "")
        else {
            settings.openEntry("spaces", answer.spaceId, answer.spaceName, "")
            accessAdmin.fix(answer)
        }
    }
    function dismiss() {
        if (navigationDrawer.visible)
            navigationDrawer.close()
        else if (renamePanel.shown)
            renamePanel.dismiss()
        else if (commerce.dismiss() || accessAdmin.dismiss() || apiTokens.dismiss())
            return
        else
            Session.closeSettings()
    }

    onVisibleChanged: if (settings.visible) {
        settings.section = "appearance"
        settings.expandedOrganizations = ({})
        if (Session.currentOrgId !== "") settings.setOrganizationExpanded(Session.currentOrgId, true)
        settings.focusDefault()
    } else {
        navigationDrawer.close()
        renamePanel.close()
    }

    onNarrowChanged: if (!settings.narrow) navigationDrawer.close()

    Connections {
        target: Session.orgAdmin
        function onChanged() {
            if (!Session.orgAdmin.active && settings.organizationSection && !settings.commerceSection && settings.section !== "usage") {
                settings.section = "appearance"
                renamePanel.close()
            }
        }
    }

    // A section the catalog no longer opens closes.
    Connections {
        target: Session.permissions
        function onChanged() {
            if (settings.organizationSection && Session.permissions.known(Session.currentOrgId)
                    && !settings.sectionsOf(Session.currentOrgId).includes(settings.section))
                settings.section = "appearance"
        }
    }

    Connections {
        target: settings.Window.window
        function onActiveChanged() { if (settings.Window.window.active) settings.refreshPeople() }
    }

    Connections {
        target: Session.orgBilling
        function onChanged() {
            if (!Session.orgBilling.active && (settings.commerceSection || settings.section === "usage"))
                settings.section = "appearance"
        }
    }

    // A row of the navigation, focused within it while selected.
    component NavigationStop: NavigationRow {
        tabFocusable: false
        Accessible.focusable: true
        focus: selected
    }
    // The navigation is one stop in the tab order, on its selected row: the
    // arrows move between its rows, and Tab goes on to the section.
    component Navigation: Page {
        id: navigation
        topMargin: Theme.gapM
        bottomMargin: Theme.gapM
        leftMargin: Theme.gapS
        rightMargin: Theme.gapS
        Component.onCompleted: if (settings.narrow) appearanceNavigation.forceActiveFocus()

        // Its rows, top to bottom, as they show.
        function rows() {
            const found = []
            const walk = function (item) {
                for (const child of item.children) {
                    if (!child.visible)
                        continue
                    if (child instanceof NavigationStop)
                        found.push(child)
                    else
                        walk(child)
                }
            }
            walk(stops)
            return found
        }
        function step(by) {
            const rows = navigation.rows()
            const at = rows.indexOf(navigation.Window.activeFocusItem)
            const next = rows[Math.max(0, Math.min(rows.length - 1, at + by))]
            if (next)
                next.forceActiveFocus(Qt.TabFocusReason)
        }

        FocusScope {
            id: scope
            objectName: "settingsNavigation"
            Layout.fillWidth: true
            implicitHeight: stops.implicitHeight
            activeFocusOnTab: true
            Accessible.role: Accessible.Grouping
            Accessible.name: qsTr("Settings")
            Keys.onUpPressed: navigation.step(-1)
            Keys.onDownPressed: navigation.step(1)
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                    navigation.step(event.key === Qt.Key_Home ? -navigation.rows().length : navigation.rows().length)
                    event.accepted = true
                }
            }

            ColumnLayout {
                id: stops
                width: parent.width
                spacing: Theme.gapXs

                NavigationStop {
                    id: appearanceNavigation
                    touch: settings.narrow
                    objectName: "settingsAppearanceNavigation"
                    checkable: true
                    text: qsTr("Appearance")
                    icon: "settings"
                    selected: settings.section === "appearance"
                    onActivated: settings.chooseSection("", "appearance")
                }
                NavigationStop {
                    touch: settings.narrow
                    objectName: "settingsTokensNavigation"
                    checkable: true
                    text: qsTr("API tokens")
                    icon: "access"
                    selected: settings.section === "tokens"
                    onActivated: settings.chooseSection("", "tokens")
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
                        readonly property bool expanded: settings.expandedOrganizations[orgId] === true
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.gapS
                        spacing: Theme.gapXs
                        NavigationStop {
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
                                return settings.sectionsOf(organization.orgId).includes(s.value)
                            }) : []
                            delegate: NavigationStop {
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
                        NavigationStop {
                            objectName: "settingsOpenOrganization_" + organization.orgId
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
                NavigationStop {
                    objectName: "settingsOpenOrganizations"
                    Layout.topMargin: Theme.gapM
                    touch: settings.narrow
                    text: qsTr("Open organizations")
                    icon: "org"
                    onActivated: settings.openOrganizations("")
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ScreenHeader {
            id: header
            Layout.fillWidth: true
            narrow: settings.narrow
            caption: settings.organizationSection ? Session.orgBilling.name : Session.identifier
            title: qsTr("Settings")
            backText: qsTr("Back to files")
            navigationName: "settingsNavigationButton"
            backName: "closeSettingsButton"
            refreshName: "refreshOrgAdminButton"
            refreshUsable: settings.commerceSection || settings.section === "usage" ? !Session.orgBilling.busy
                           : settings.organizationSection ? !Session.orgAdmin.busy
                           : settings.section === "tokens" ? !Session.apiTokens.busy : !Session.organizationsBusy
            onNavigationRequested: navigationDrawer.open()
            onBackRequested: Session.closeSettings()
            onRefreshRequested: if (settings.commerceSection || settings.section === "usage") {
                                    Session.orgBilling.refresh()
                                    if (settings.section === "addons") Session.addOnActivations.refresh()
                                } else if (settings.organizationSection) {
                                    Session.orgAdmin.refresh()
                                    if (settings.accessSection) {
                                        Session.accessDirectory.open()
                                        Session.accessGrants.refresh()
                                        Session.principalAccess.refresh()
                                        Session.roleHolders.refresh()
                                    }
                                    if (settings.section === "spaces") Session.addOnActivations.refresh()
                                } else if (settings.section === "tokens") {
                                    Session.apiTokens.refresh()
                                } else {
                                    Session.refreshOrganizations()
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

                // A detail page heads itself.
                SectionHead {
                    visible: !(settings.accessSection && accessAdmin.pageOpen) && !(settings.section === "addons" && commerce.selectedProduct !== null)
                    title: settings.section === "appearance" ? qsTr("Appearance")
                           : settings.section === "tokens" ? qsTr("API tokens")
                           : settings.sections.find(function (s) { return s.value === settings.section })?.label ?? ""

                    ActionButton {
                        id: renameButton
                        objectName: "renameOrganizationButton"
                        visible: settings.section === "general"
                        text: qsTr("Rename organization")
                        icon: "rename"
                        primary: true
                        usable: !Session.orgAdmin.busy && settings.sectionError === "" && renaming.allowed
                        reason: renaming.reason
                        onActivated: renamePanel.openFor(renameButton)
                        Gate { id: renaming; action: "organization.update_policy" }
                    }

                    ActionButton {
                        id: newUserButton
                        objectName: "newUserButton"
                        visible: settings.section === "members" && !accessAdmin.pageOpen
                        text: qsTr("New user")
                        icon: "new"
                        primary: true
                        usable: !Session.orgAdmin.busy && settings.sectionError === "" && creatingUsers.allowed
                        reason: creatingUsers.reason
                        onActivated: accessAdmin.newUser(newUserButton)
                        Gate { id: creatingUsers; action: "membership.create" }
                    }

                    ActionButton {
                        id: inviteButton
                        objectName: "sendInvitationButton"
                        visible: settings.section === "members" && !accessAdmin.pageOpen
                        text: qsTr("Invite")
                        icon: "user"
                        usable: !Session.orgAdmin.busy && settings.sectionError === "" && inviting.allowed
                        reason: inviting.reason
                        onActivated: accessAdmin.invite(inviteButton)
                        Gate { id: inviting; action: "membership.invite" }
                    }

                    ActionButton {
                        objectName: "newApiTokenButton"
                        visible: settings.section === "tokens" && apiTokens.createLabel !== ""
                        text: apiTokens.createLabel
                        icon: "new"
                        primary: true
                        usable: Session.apiTokens.active && !Session.apiTokens.busy
                        onActivated: apiTokens.create()
                    }

                    ActionButton {
                        id: createButton
                        objectName: "accessCreateButton"
                        visible: settings.accessSection && accessAdmin.createLabel !== ""
                        text: accessAdmin.createLabel
                        icon: "new"
                        primary: true
                        usable: !accessAdmin.busy && Session.accessDirectory.active && creating.allowed
                        reason: creating.reason
                        onActivated: accessAdmin.create(createButton)
                        Gate {
                            id: creating
                            action: ({ groups: "group.create", roles: "role.create", tags: "tag.create" })[settings.section] ?? ""
                        }
                    }

                    ActionButton {
                        objectName: "accessOpenButton"
                        visible: settings.accessSection && !accessAdmin.pageOpen
                        text: qsTr("Open")
                        icon: "forward"
                        showLabel: !settings.narrow
                        tip: settings.narrow ? text : ""
                        usable: accessAdmin.selectedRow !== null
                        reason: qsTr("Select one row.")
                        onActivated: accessAdmin.openRow(accessAdmin.selectedRow)
                    }

                    ActionButton {
                        objectName: "addonOpenButton"
                        visible: settings.section === "addons" && commerce.selectedProduct === null
                        text: qsTr("Open")
                        icon: "forward"
                        showLabel: !settings.narrow
                        tip: settings.narrow ? text : ""
                        usable: commerce.listedProduct !== null
                        reason: qsTr("Select one row.")
                        onActivated: commerce.open(commerce.listedProduct.key)
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
                        visible: settings.section === "billing"
                        text: qsTr("Manage billing")
                        icon: "settings"
                        showLabel: !settings.narrow
                        tip: text
                        usable: !commerce.busy && Session.orgBilling.canManage
                        reason: managingBilling.reason
                        onActivated: Session.orgBilling.createPortal()
                    }
                    ActionButton {
                        id: subscribeButton
                        objectName: "subscribePackageButton"
                        visible: settings.section === "billing"
                        text: commerce.liveSubscription ? qsTr("Switch package") : qsTr("Subscribe")
                        icon: "check"
                        primary: true
                        usable: commerce.canSubscribe
                        reason: !Session.orgBilling.canManage ? managingBilling.reason
                              : commerce.selectedPackage === null ? qsTr("Select a package.") : ""
                        onActivated: commerce.subscribe(subscribeButton)
                    }
                    Gate { id: managingBilling; action: "billing.manage" }

                }
                // A change's refusal shows in the side panel that made it.
                Label {
                    objectName: "orgAdminError"
                    visible: settings.sectionError !== ""
                    text: Messages.adminFailure(settings.sectionError)
                    color: Theme.failed
                    Accessible.role: Accessible.AlertMessage
                }
                Notice {
                    objectName: "orgAdminNotice"
                    code: Session.orgAdmin.notice
                    place: Session.currentOrgId + ":" + settings.section
                    text: Messages.adminNotice(Session.orgAdmin.notice)
                }
                Label {
                    visible: settings.section === "usage" ? Session.orgBilling.busy
                             : settings.organizationSection && !settings.commerceSection && !settings.accessSection
                               && Session.orgAdmin.busy
                    text: qsTr("Working…")
                }

                OrgCommerce {
                    id: commerce
                    visible: settings.commerceSection
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    billing: settings.section === "billing"
                    narrow: settings.narrow
                    onEntryRequested: function (section, id, name) { settings.openEntry(section, id, name, "") }
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

                ApiTokens {
                    id: apiTokens
                    visible: settings.section === "tokens"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    narrow: settings.narrow
                }

                AccessAdmin {
                    id: accessAdmin
                    visible: settings.accessSection && settings.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    section: settings.accessSection ? settings.section : ""
                    narrow: settings.narrow
                    onEntryRequested: function (section, id, name, tab) { settings.openEntry(section, id, name, tab) }
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

    SidePanel {
        id: renamePanel
        objectName: "renameOrganizationPanel"
        property bool sent: false
        function openFor(returnTo) {
            organizationName.text = Session.orgAdmin.name
            renamePanel.sent = false
            renamePanel.open(returnTo)
            organizationName.selectAll()
        }
        anchors.fill: parent
        narrow: settings.narrow
        title: qsTr("Rename organization")
        saveText: qsTr("Save changes")
        saveUsable: !Session.orgAdmin.busy && organizationName.text.trim() !== "" && organizationName.text.trim() !== Session.orgAdmin.name
        initialFocus: organizationName
        onSaveRequested: {
            renamePanel.sent = true
            Session.orgAdmin.rename(organizationName.text)
        }

        Connections {
            target: Session.orgAdmin
            function onChanged() {
                if (renamePanel.sent && !Session.orgAdmin.busy) {
                    renamePanel.sent = false
                    if (Session.orgAdmin.errorCode === "") renamePanel.close()
                }
            }
        }
        Label {
            objectName: "renameOrganizationError"
            visible: renamePanel.sent === false && Session.orgAdmin.errorCode !== ""
            text: Messages.adminFailure(Session.orgAdmin.errorCode)
            color: Theme.failed
            Accessible.role: Accessible.AlertMessage
        }
        Field {
            id: organizationName
            objectName: "organizationNameField"
            placeholderText: qsTr("Organization name")
            onAccepted: if (renamePanel.saveUsable) renamePanel.saveRequested()
        }
    }
}
