pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// Who may do what in the organization, for Settings: people (members or
// invitations, a tab each), groups, roles, spaces, and tags, each a table
// whose rows are read only. Settings' command bar opens the selected row's
// page (so do Enter and a double click), a DetailPage whose command bar
// opens the side panel beside it for one change; so do New user, Invite,
// New group, New role, and New tag. A folder or document that access leads
// to opens its access page too, and leaving it returns to the page it was
// opened from.
FocusScope {
    id: access

    property string section
    property bool narrow: false
    // The People tab shown: "members" or "invitations".
    property string people: "members"

    // Opens the page of entry `id` under `section`, on its tab `tab` when
    // given.
    signal entryRequested(string section, string id, string name, string tab)

    // The page open: "member", "invitation", "group", or "role" `openId`,
    // or, with no kind, the space or tag `openId` under Spaces or Tags.
    property string openId
    property string openName
    property string openKind
    // The folder or document whose page access opened:
    // `{kind, spaceId, id, name, spaceName}`.
    property var place: null
    // What the side panel does (see `edit`); `subject` names what it acts
    // on, empty for something new.
    property string editing
    property string subject

    readonly property bool pageOpen: access.openId !== "" || access.place !== null
    // The Access view of the page shown, whose side panels it offers.
    readonly property AccessView view: access.place !== null ? placePage.view
                                     : access.section === "spaces" && access.openId !== "" ? spacePage.view
                                     : access.section === "tags" && access.openId !== "" ? tagPage.view : null
    // The person or group page open, whose Remove the panel confirms.
    readonly property var principalPage: access.openKind === "group" ? groupPage : userPage
    // The table of the section shown, and its row selected.
    readonly property Table list: access.section === "members" ? (access.people === "invitations" ? invitations : members)
                                : access.section === "groups" ? groupTable
                                : access.section === "roles" ? roleTable
                                : access.section === "spaces" ? spaceTable
                                : access.section === "tags" ? tagTable : null
    readonly property var selectedRow: access.list?.selectedRow ?? null
    // The name of the page a folder or document was opened from.
    readonly property string shownName: access.openKind === "member" ? userPage.title
                                      : access.openKind === "group" ? groupPage.title
                                      : access.openKind === "role" ? rolePage.title
                                      : access.openName !== "" ? access.openName : qsTr("Back")
    readonly property var subjectRole: Session.accessDirectory.roles.find(function (row) { return row.id === access.subject }) ?? null
    readonly property string createLabel: access.pageOpen ? ""
                                        : access.section === "groups" ? qsTr("New group")
                                        : access.section === "roles" ? qsTr("New role")
                                        : access.section === "tags" ? qsTr("New tag") : ""
    readonly property bool busy: Session.accessDirectory.busy || Session.accessGrants.busy || Session.orgAdmin.busy
    // The last change saved here, from whichever list saved it: one notice
    // at a time, so an earlier one never stands beside it.
    property string notice
    property string noticeFrom
    readonly property string directoryNotice: Session.accessDirectory.notice
    readonly property string principalNotice: Session.principalAccess.notice
    readonly property string holdersNotice: Session.roleHolders.notice

    // Opens the page of `id` (empty for the list), on its tab `tab` when
    // given: `kind` defaults to what the section lists. Focus moves to the
    // page, and back to its row after.
    function open(id, name, kind, tab) {
        panel.close()
        access.place = null
        access.openKind = id === "" ? "" : kind ?? ({ members: "member", groups: "group", roles: "role" })[access.section] ?? ""
        access.openName = name
        access.openId = id
        if ((tab ?? "") !== "")
            access.shownPage()?.show(tab)
        Qt.callLater(access.focusPage)
    }
    // The page shown, if one is.
    function shownPage() {
        return access.place !== null ? placePage
             : access.openKind === "member" ? userPage
             : access.openKind === "invitation" ? invitationPage
             : access.openKind === "group" ? groupPage
             : access.openKind === "role" ? rolePage
             : access.section === "spaces" && access.openId !== "" ? spacePage
             : access.section === "tags" && access.openId !== "" ? tagPage : null
    }
    // Opens the page of the row `row` of the section's table.
    function openRow(row) {
        if (access.section === "members")
            access.open(row.personId, row.label, access.people === "invitations" ? "invitation" : "member")
        else if (access.section === "groups")
            access.open(row.id, row.name, "group")
        else if (access.section === "roles")
            access.open(row.id, Messages.roleName(row.key, row.name), "role")
        else if (access.section === "spaces")
            access.open(row.spaceId, row.name, "")
        else if (access.section === "tags")
            access.open(row.id, row.name, "")
    }
    function focusPage() {
        const back = access.shownPage()?.backButton ?? null
        if (back && back.visible)
            back.forceActiveFocus(Qt.TabFocusReason)
    }
    // Back to the list, focus on the row of the page it leaves.
    function leave() {
        const kind = access.openKind
        const id = access.openId
        access.open("", "")
        const table = kind === "invitation" ? invitations : kind === "member" ? members : access.list
        const role = kind === "role" ? Session.accessDirectory.roles.find(function (row) { return row.id === id }) ?? null : null
        if (!(table && table.focusKey(role !== null && !role.custom ? role.key : id)))
            lists.forceActiveFocus()
    }
    // Opens the access of `place` (a PrincipalAccess row or a role holder's
    // place) from a page.
    function openPlace(place) {
        if (place.kind === "space") {
            access.entryRequested("spaces", place.spaceId, place.name, "access")
        } else if (place.kind === "tag") {
            access.entryRequested("tags", place.id, place.name, "access")
        } else {
            panel.close()
            access.place = { kind: place.kind, spaceId: place.spaceId, id: place.id, name: place.name, spaceName: place.spaceName }
            Qt.callLater(access.focusPage)
        }
    }
    // Opens the place an inherited access row comes from.
    function openSource(kind, id, name) {
        if (kind === "space")
            access.entryRequested("spaces", id, name, "access")
        else
            access.openPlace({ kind: kind, spaceId: Session.accessGrants.spaceId, id: id, name: name,
                               spaceName: access.place?.spaceName ?? access.openName })
    }
    // Opens the panel `kind` on `subject`; focus returns to `returnTo` after.
    function edit(kind, subject, returnTo) {
        access.editing = kind
        access.subject = subject
        panel.show(({ newUser: newUserPanel, invite: invitePanel, roles: rolesPanel, groups: memberGroupsPanel,
                      setupCode: setupCodePanel, removeMember: removeMemberPanel, cancelInvitation: cancelInvitationPanel,
                      newGroup: groupNamePanel, renameGroup: groupNamePanel, groupMembers: groupMembersPanel,
                      archiveGroup: archiveGroupPanel, newRole: rolePanel, copyRole: rolePanel, editRole: rolePanel,
                      addPeople: addPeoplePanel, archiveRole: archiveRolePanel, tag: tagEditor, editTag: tagEditor,
                      restrictTag: restrictTagPanel, archiveTag: archiveTagPanel, activation: activationPanel,
                      grantPlace: placeGrantPanel, removeHeld: removeHeldPanel, removeHolders: removeHoldersPanel,
                      renameSpace: spaceNamePanel, archiveSpace: archiveSpacePanel })[kind]
                   ?? access.view?.panels[kind] ?? null, returnTo)
    }
    function create(returnTo) {
        if (access.section === "groups") access.edit("newGroup", "", returnTo)
        else if (access.section === "roles") access.edit("newRole", "", returnTo)
        else if (access.section === "tags") access.edit("tag", "", returnTo)
    }
    // On the space page open, the panel that fixes a refusal (Permissions'
    // `explain`): Grant access with the narrowest role that holds the action
    // ticked, or the add-on's activation.
    function fix(answer) {
        spacePage.show(answer.fix === "grant" ? "access" : "addons")
        if (answer.fix === "grant") {
            spacePage.view.grantRoles = (answer.roles ?? []).slice(0, 1).map(function (role) { return role.id })
            access.edit("grantAccess", "", spacePage.backButton)
        } else if (answer.fix === "activate") {
            access.edit("activation", answer.product, spacePage.backButton)
        }
    }
    function invite(returnTo) { access.edit("invite", "", returnTo) }
    function newUser(returnTo) { access.edit("newUser", "", returnTo) }
    // Closes the panel, the folder or document, or the page, in that order.
    function dismiss() {
        if (panel.shown) {
            panel.dismiss()
            return true
        }
        if (access.place !== null) {
            access.place = null
            Qt.callLater(access.focusPage)
            return true
        }
        if (access.openId !== "") {
            access.leave()
            return true
        }
        return false
    }
    // Opens the grants of the page shown, and a space page's add-ons.
    function syncGrants() {
        if (access.visible && access.section === "spaces")
            Session.addOnActivations.open()
        if (access.visible && access.place !== null)
            Session.accessGrants.open(access.place.kind, access.place.spaceId, access.place.id,
                                      Messages.placeName(access.place.kind, access.place.name, ""))
        else if (access.visible && access.section === "spaces" && access.openId !== "")
            Session.accessGrants.open("space", access.openId, access.openId, spacePage.title || access.openName)
        else if (access.visible && access.section === "tags" && access.openId !== "")
            Session.accessGrants.open("tag", "", access.openId, access.openName)
        else
            Session.accessGrants.close()
    }
    // Reads what the person or group whose page is open holds, and who holds
    // the role whose page is open.
    function syncPrincipal() {
        const principal = !access.visible ? ""
                        : access.openKind === "member" ? "user:" + access.openId
                        : access.openKind === "group" ? "group:" + access.openId : ""
        if (principal !== "") Session.principalAccess.open(principal)
        else Session.principalAccess.close()
        if (access.visible && access.openKind === "role") Session.roleHolders.open(access.openId)
        else Session.roleHolders.close()
    }
    function noted(from, code) {
        if (code !== "") {
            access.notice = code
            access.noticeFrom = from
        } else if (access.noticeFrom === from) {
            access.notice = ""
        }
    }
    function reset() {
        panel.close()
        access.place = null
        access.openKind = ""
        access.openId = ""
    }

    onSectionChanged: {
        access.reset()
        access.people = "members"
        access.syncGrants()
    }
    onOpenIdChanged: {
        access.syncGrants()
        access.syncPrincipal()
    }
    onPlaceChanged: access.syncGrants()
    onDirectoryNoticeChanged: access.noted("directory", access.directoryNotice)
    onPrincipalNoticeChanged: access.noted("principal", access.principalNotice)
    onHoldersNoticeChanged: access.noted("holders", access.holdersNotice)
    onVisibleChanged: {
        if (access.visible)
            Session.accessDirectory.open()
        else
            access.reset()
        access.syncGrants()
        access.syncPrincipal()
    }

    // A page whose subject is gone returns to the list.
    Connections {
        target: Session.accessDirectory
        function onSaved(notice) {
            if ((notice === "tag_archived" && access.section === "tags") || (notice === "group_archived" && access.openKind === "group")
                    || (notice === "role_archived" && access.openKind === "role"))
                access.leave()
        }
    }
    Connections {
        target: Session.orgAdmin
        function onChangeSaved(notice) {
            if (notice === "removed" && access.openKind === "member")
                access.leave()
        }
    }

    Page {
        id: lists
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - (panel.reserve > 0 ? panel.reserve + Theme.gapM : 0)

        Label {
            objectName: "accessError"
            visible: !panel.shown && Session.accessDirectory.errorCode !== ""
            text: Messages.accessFailure(Session.accessDirectory.errorCode)
            color: Theme.failed
            Accessible.role: Accessible.AlertMessage
        }
        Notice {
            objectName: "accessNotice"
            code: access.notice
            place: access.section + ":" + access.openId
            text: Messages.accessNotice(access.notice)
        }
        // Only a first load says so: a reload leaves the rows where they are.
        Label {
            visible: (Session.accessDirectory.busy && Session.accessDirectory.roles.length === 0)
                     || (access.section === "members" && Session.orgAdmin.busy && members.count === 0)
            text: qsTr("Working…")
        }

        // People
        Flow {
            visible: access.section === "members" && !access.pageOpen
            Layout.fillWidth: true
            spacing: Theme.gapXs
            Accessible.role: Accessible.PageTabList
            Accessible.name: qsTr("People")
            ViewTab {
                objectName: "peopleTab_members"
                view: "members"
                current: access.people
                text: qsTr("Members")
                onPicked: function (view) { access.people = view }
            }
            ViewTab {
                objectName: "peopleTab_invitations"
                view: "invitations"
                current: access.people
                text: qsTr("Invitations")
                onPicked: function (view) { access.people = view }
            }
        }
        Table {
            id: members
            objectName: "memberList"
            visible: access.section === "members" && access.people === "members" && !access.pageOpen
            prefix: "member_"
            label: qsTr("Members")
            touch: access.narrow
            columns: [{ title: qsTr("Name"), share: 3 }, { title: qsTr("Roles"), share: 2 }]
            model: Session.orgAdmin.members
            keyOf: function (row) { return row.personId }
            cells: function (row) { return [row.label, Messages.roleNames(row.roles)] }
            emptyText: Session.orgAdmin.busy ? "" : qsTr("No members to display.")
            onOpened: function (row) { access.open(row.personId, row.label, "member") }
        }
        Table {
            id: invitations
            objectName: "invitationList"
            visible: access.section === "members" && access.people === "invitations" && !access.pageOpen
            prefix: "invitation_"
            label: qsTr("Invitations")
            touch: access.narrow
            columns: [{ title: qsTr("Email"), share: 3 }, { title: qsTr("Roles"), share: 2 }, { title: qsTr("Status"), share: 2 },
                      { title: qsTr("Access"), share: 2 }]
            model: Session.orgAdmin.invitations
            keyOf: function (row) { return row.personId }
            cells: function (row) {
                return [row.label, Messages.roleNames(row.roles),
                        row.expiresAt !== "" ? qsTr("%1 · expires %2").arg(Messages.invitationState(row.status)).arg(row.expiresAt)
                                             : Messages.invitationState(row.status),
                        Messages.invitationAccess(row.spaces)]
            }
            emptyText: Session.orgAdmin.busy ? "" : qsTr("No invitations.")
            onOpened: function (row) { access.open(row.personId, row.label, "invitation") }
        }
        UserPage {
            id: userPage
            narrow: access.narrow
            visible: access.openKind === "member" && userPage.member !== null && access.place === null
            memberId: access.openKind === "member" ? access.openId : ""
            onBackRequested: access.leave()
            onPanelRequested: function (kind, from) { access.edit(kind, access.openId, from) }
            onEntryRequested: function (section, id, name) { access.entryRequested(section, id, name, "") }
            onPlaceRequested: function (place) { access.openPlace(place) }
        }
        InvitationPage {
            id: invitationPage
            narrow: access.narrow
            visible: access.openKind === "invitation" && access.place === null
            invitationId: access.openKind === "invitation" ? access.openId : ""
            onBackRequested: access.leave()
            onPanelRequested: function (kind, from) { access.edit(kind, access.openId, from) }
            onEntryRequested: function (section, id, name) { access.entryRequested(section, id, name, "access") }
        }

        // Groups
        Table {
            id: groupTable
            visible: access.section === "groups" && !access.pageOpen
            prefix: "group_"
            label: qsTr("Groups")
            touch: access.narrow
            columns: [{ title: qsTr("Name"), share: 3 }, { title: qsTr("Members"), share: 1 }]
            model: Session.accessDirectory.groups
            cells: function (row) { return [row.name, qsTr("%n member(s)", "", row.members.length)] }
            emptyText: Session.accessDirectory.active && !Session.accessDirectory.busy ? qsTr("No groups yet.") : ""
            onOpened: function (row) { access.openRow(row) }
        }
        GroupPage {
            id: groupPage
            narrow: access.narrow
            visible: access.openKind === "group" && groupPage.group !== null && access.place === null
            groupId: access.openKind === "group" ? access.openId : ""
            onBackRequested: access.leave()
            onPanelRequested: function (kind, from) { access.edit(kind, access.openId, from) }
            onEntryRequested: function (section, id, name) { access.entryRequested(section, id, name, "") }
            onPlaceRequested: function (place) { access.openPlace(place) }
        }

        // Roles
        Table {
            id: roleTable
            visible: access.section === "roles" && !access.pageOpen
            prefix: "role_"
            label: qsTr("Roles")
            touch: access.narrow
            columns: [{ title: qsTr("Name"), share: 3 }, { title: qsTr("Type"), share: 1 }, { title: qsTr("Applies to"), share: 1 }]
            model: Session.accessDirectory.roles
            keyOf: function (row) { return row.custom ? row.id : row.key }
            cells: function (row) { return [Messages.roleName(row.key, row.name), Messages.roleKind(row), Messages.roleScope(row.appliesTo)] }
            emptyText: Session.accessDirectory.active && !Session.accessDirectory.busy ? qsTr("No roles yet.") : ""
            onOpened: function (row) { access.openRow(row) }
        }
        RolePage {
            id: rolePage
            narrow: access.narrow
            visible: access.openKind === "role" && rolePage.role !== null && access.place === null
            roleId: access.openKind === "role" ? access.openId : ""
            onBackRequested: access.leave()
            onPanelRequested: function (kind, from) { access.edit(kind, access.openId, from) }
            onEntryRequested: function (section, id, name) { access.entryRequested(section, id, name, "") }
        }

        // Spaces
        Notice {
            objectName: "activationNotice"
            code: access.section === "spaces" && !panel.shown ? Session.addOnActivations.notice : ""
            place: access.section + ":" + access.openId
            text: Messages.activationNotice(Session.addOnActivations.notice)
        }
        Table {
            id: spaceTable
            visible: access.section === "spaces" && !access.pageOpen
            prefix: "accessSpace_"
            label: qsTr("Spaces")
            touch: access.narrow
            columns: [{ title: qsTr("Name"), share: 3 }, { title: qsTr("Status"), share: 1 }]
            model: Session.spaces
            keyOf: function (row) { return row.spaceId }
            cells: function (row) { return [row.name, row.status === "archived" ? qsTr("Archived") : qsTr("Active")] }
            emptyText: qsTr("No spaces yet.")
            onOpened: function (row) { access.openRow(row) }
        }
        SpacePage {
            id: spacePage
            visible: access.section === "spaces" && access.openId !== "" && access.place === null
            spaceId: access.section === "spaces" ? access.openId : ""
            narrow: access.narrow
            view.outcome: !panel.shown
            onBackRequested: access.leave()
            onPanelRequested: function (kind, subject, from) { access.edit(kind, subject, from) }
            onSourceRequested: function (kind, id, name) { access.openSource(kind, id, name) }
            onAddOnRequested: function (key, name) { access.entryRequested("addons", key, name, "") }
            // The access read names the space as it is now.
            onTitleChanged: if (Session.accessGrants.kind === "space" && Session.accessGrants.targetId === spacePage.spaceId
                                    && spacePage.title !== "" && Session.accessGrants.name !== spacePage.title)
                                access.syncGrants()
        }

        // A folder or document access leads to
        PlacePage {
            id: placePage
            visible: access.place !== null
            title: Messages.placeName(access.place?.kind ?? "", access.place?.name ?? "", access.place?.spaceName ?? "")
            backText: access.shownName
            narrow: access.narrow
            view.outcome: !panel.shown
            onBackRequested: access.dismiss()
            onPanelRequested: function (kind, from) { access.edit(kind, "", from) }
            onSourceRequested: function (kind, id, name) { access.openSource(kind, id, name) }
        }

        // Tags
        Table {
            id: tagTable
            visible: access.section === "tags" && !access.pageOpen
            prefix: "tag_"
            label: qsTr("Tags")
            touch: access.narrow
            columns: [{ title: qsTr("Name"), share: 3 }, { title: qsTr("Documents"), share: 1 }]
            model: Session.accessDirectory.tags
            cells: function (row) { return [row.name, row.access_controlled ? qsTr("Restricted") : qsTr("Open")] }
            emptyText: Session.accessDirectory.active && !Session.accessDirectory.busy ? qsTr("No tags yet.") : ""
            onOpened: function (row) { access.openRow(row) }
        }
        TagPage {
            id: tagPage
            visible: access.section === "tags" && tagPage.tag !== null && access.place === null
            tagId: access.section === "tags" ? access.openId : ""
            narrow: access.narrow
            view.outcome: !panel.shown
            onBackRequested: access.leave()
            onPanelRequested: function (kind, from) { access.edit(kind, access.openId, from) }
        }
    }

    PanelHost {
        id: panel
        anchors.fill: parent
        narrow: access.narrow
        // A setup code shows only until the panel that issued it closes.
        // Focus goes back to the page or list when what the panel was opened
        // from went away with the change it made.
        onClosed: {
            Session.orgAdmin.clearSetupCode()
            if (access.visible && !(panel.returnTo && panel.returnTo.visible)) {
                if (access.pageOpen) access.focusPage()
                else lists.forceActiveFocus()
            }
        }
    }

    Component {
        id: newUserPanel
        NewUserPanel { narrow: access.narrow }
    }
    Component {
        id: invitePanel
        InvitePanel { narrow: access.narrow }
    }
    Component {
        id: rolesPanel
        RolesPanel {
            narrow: access.narrow
            principal: (access.openKind === "group" ? "group:" : "user:") + access.subject
            name: access.openKind === "group" ? groupPage.group?.name ?? "" : userPage.member?.label ?? ""
        }
    }
    Component {
        id: memberGroupsPanel
        MemberGroupsPanel {
            narrow: access.narrow
            memberId: access.subject
            name: userPage.member?.label ?? ""
        }
    }
    Component {
        id: setupCodePanel
        SetupCodePanel {
            narrow: access.narrow
            memberId: access.subject
            identifier: userPage.identifier
        }
    }
    Component {
        id: removeMemberPanel
        ConfirmPanel {
            objectName: "removeMemberPanel"
            title: qsTr("Remove %1?").arg(userPage.member?.label ?? "")
            detail: Messages.memberImpact(Session.principalAccess.rows, userPage.groups, Session.principalAccess.roles)
            saveText: qsTr("Remove member")
            busy: Session.orgAdmin.busy
            failure: Messages.adminFailure(Session.orgAdmin.errorCode)
            onConfirmed: Session.orgAdmin.removeMember(access.subject)
        }
    }
    Component {
        id: cancelInvitationPanel
        ConfirmPanel {
            objectName: "cancelInvitationPanel"
            title: qsTr("Cancel invitation for %1?").arg(invitationPage.invitation.label ?? "")
            detail: qsTr("The invitation link will stop working.")
            saveText: qsTr("Cancel invitation")
            busy: Session.orgAdmin.busy
            failure: Messages.adminFailure(Session.orgAdmin.errorCode)
            onConfirmed: Session.orgAdmin.cancelInvitation(access.subject)
        }
    }
    Component {
        id: groupNamePanel
        NamePanel {
            id: groupName
            objectName: "groupNamePanel"
            title: groupName.creating ? qsTr("New group") : qsTr("Rename group")
            saveText: groupName.creating ? qsTr("Create group") : qsTr("Rename")
            narrow: access.narrow
            creating: access.editing === "newGroup"
            current: groupName.creating ? "" : groupPage.group?.name ?? ""
            fieldName: "groupNameField"
            placeholder: qsTr("For example: Legal")
            busy: Session.accessDirectory.busy
            failure: Messages.accessFailure(Session.accessDirectory.errorCode)
            onNamed: function (name) {
                if (groupName.creating) Session.accessDirectory.createGroup(name)
                else Session.accessDirectory.renameGroup(access.subject, name)
            }
            // A group just made opens its page.
            Connections {
                target: Session.accessDirectory
                function onSaved(notice, id) {
                    if (groupName.sent && notice === "group_created" && id !== "") {
                        panel.close()
                        access.open(id, Session.accessDirectory.groups.find(function (row) { return row.id === id })?.name ?? "", "group")
                    }
                }
            }
        }
    }
    Component {
        id: spaceNamePanel
        NamePanel {
            objectName: "spaceNamePanel"
            title: qsTr("Rename space")
            saveText: qsTr("Rename")
            narrow: access.narrow
            current: spacePage.title
            fieldName: "spaceNameField"
            maximumLength: 160
            busy: Session.accessDirectory.busy
            failure: Messages.accessFailure(Session.accessDirectory.errorCode)
            onNamed: function (name) { Session.accessDirectory.renameSpace(access.subject, name) }
        }
    }
    Component {
        id: archiveSpacePanel
        ConfirmPanel {
            objectName: "archiveSpacePanel"
            title: qsTr("Archive %1?").arg(spacePage.title)
            detail: qsTr("The space stays readable. Nobody can change its files, folders, or name.")
            saveText: qsTr("Archive")
            busy: Session.accessDirectory.busy
            failure: Messages.accessFailure(Session.accessDirectory.errorCode)
            onConfirmed: Session.accessDirectory.archiveSpace(access.subject)
        }
    }
    Component {
        id: groupMembersPanel
        GroupMembersPanel {
            narrow: access.narrow
            groupId: access.subject
        }
    }
    Component {
        id: archiveGroupPanel
        ConfirmPanel {
            objectName: "archiveGroupPanel"
            title: qsTr("Archive %1?").arg(groupPage.group?.name ?? "")
            detail: qsTr("Members lose what is granted to the group. They stay in the organization.")
            saveText: qsTr("Archive")
            busy: Session.accessDirectory.busy
            failure: Messages.accessFailure(Session.accessDirectory.errorCode)
            onConfirmed: Session.accessDirectory.archiveGroup(access.subject)
        }
    }
    Component {
        id: rolePanel
        RolePanel {
            narrow: access.narrow
            roleId: access.editing === "editRole" ? access.subject : ""
            source: access.editing === "copyRole" ? access.subject : ""
            onCreated: function (id) {
                panel.close()
                const role = Session.accessDirectory.roles.find(function (row) { return row.id === id })
                access.open(id, role?.name ?? "", "role")
            }
        }
    }
    Component {
        id: addPeoplePanel
        AddPeoplePanel {
            narrow: access.narrow
            name: rolePage.title
            inSpace: rolePage.placed
        }
    }
    Component {
        id: removeHoldersPanel
        ConfirmPanel {
            objectName: "removeHoldersPanel"
            title: qsTr("Take back %1 from %n holder(s)?", "", rolePage.holders.selectedRows.length).arg(rolePage.title)
            detail: rolePage.holders.selectedRows.map(function (holder) {
                return Messages.grantHolder(holder) + " · " + (holder.kind === "assignment" ? Messages.accessWhere({ placeKind: "organization", idle: holder.idle })
                       : Messages.placeName(holder.resourceKind, holder.name, holder.spaceName))
            }).join("\n")
            saveText: qsTr("Remove")
            busy: Session.roleHolders.busy
            failure: Messages.accessFailure(Session.roleHolders.errorCode)
            onConfirmed: Session.roleHolders.remove(rolePage.holders.selectedKeys)
        }
    }
    Component {
        id: archiveRolePanel
        ConfirmPanel {
            objectName: "archiveRolePanel"
            title: qsTr("Archive %1?").arg(access.subjectRole === null ? "" : Messages.roleName(access.subjectRole.key, access.subjectRole.name))
            detail: qsTr("Everyone who holds this role loses what it allows. Its grants stop giving access.")
            saveText: qsTr("Archive")
            busy: Session.accessDirectory.busy
            failure: Messages.accessFailure(Session.accessDirectory.errorCode)
            onConfirmed: Session.accessDirectory.archiveRole(access.subject)
        }
    }
    Component {
        id: tagEditor
        TagEditor {
            tagId: access.editing === "editTag" ? access.subject : ""
            narrow: access.narrow
            onCreated: function (id) {
                const name = Session.accessDirectory.tags.find(function (row) { return row.id === id })?.name ?? ""
                access.open(id, name)
            }
        }
    }
    Component {
        id: restrictTagPanel
        ConfirmPanel {
            objectName: "restrictTagPanel"
            title: tagPage.restricted ? qsTr("Stop restricting %1?").arg(tagPage.tag?.name ?? "")
                                      : qsTr("Restrict %1?").arg(tagPage.tag?.name ?? "")
            detail: tagPage.restricted
                    ? qsTr("Documents with this tag become visible to everyone who can see where they are.")
                    : qsTr("Documents with this tag become hidden from everyone without access to the tag, including people who can see the space.")
            saveText: tagPage.restricted ? qsTr("Stop restricting") : qsTr("Restrict")
            busy: Session.accessDirectory.busy
            failure: Messages.accessFailure(Session.accessDirectory.errorCode)
            onConfirmed: Session.accessDirectory.updateTag(access.subject, tagPage.tag.name, !tagPage.restricted)
        }
    }
    Component {
        id: archiveTagPanel
        ConfirmPanel {
            objectName: "archiveTagPanel"
            title: qsTr("Archive %1?").arg(tagPage.tag?.name ?? "")
            detail: qsTr("The tag leaves the tag list. Documents it restricted are no longer restricted by it.")
            saveText: qsTr("Archive")
            busy: Session.accessDirectory.busy
            failure: Messages.accessFailure(Session.accessDirectory.errorCode)
            onConfirmed: Session.accessDirectory.archiveTag(access.subject)
        }
    }
    Component {
        id: placeGrantPanel
        PlaceGrantPanel {
            narrow: access.narrow
            name: access.openKind === "group" ? groupPage.group?.name ?? "" : userPage.member?.label ?? ""
        }
    }
    Component {
        id: removeHeldPanel
        ConfirmPanel {
            objectName: "removeHeldPanel"
            title: qsTr("Remove %n role(s)?", "", access.principalPage.removal.keys.length)
            subtitle: access.principalPage.title
            detail: access.principalPage.removal.lines.join("\n")
            saveText: qsTr("Remove")
            busy: Session.principalAccess.busy
            failure: Messages.accessFailure(Session.principalAccess.errorCode)
            onConfirmed: Session.principalAccess.remove(access.principalPage.removal.keys)
        }
    }
    Component {
        id: activationPanel
        ActivationPanel {
            narrow: access.narrow
            spaceId: access.openId
            productKey: access.subject
        }
    }
}
