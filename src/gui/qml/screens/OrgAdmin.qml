pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

FocusScope {
    id: admin

    readonly property bool narrow: admin.width < 600
    property string section: "general"
    property string targetId
    property string targetRole
    property string targetAction
    readonly property string sectionError: admin.section === "general" ? Session.orgAdmin.generalError
                                          : admin.section === "members" ? Session.orgAdmin.membersError
                                          : admin.section === "invitations" ? Session.orgAdmin.invitationsError
                                          : Session.orgAdmin.usageError
    readonly property var sections: [
        { value: "general", label: qsTr("General"), icon: "org" },
        { value: "members", label: qsTr("Members"), icon: "user" },
        { value: "invitations", label: qsTr("Invitations"), icon: "new" },
        { value: "usage", label: qsTr("Usage"), icon: "space" }
    ]

    function focusDefault() { back.forceActiveFocus() }
    function dismiss() {
        if (confirm.visible)
            confirm.close()
        else
            Session.orgAdmin.close()
    }
    function ask(action, id, email, role) {
        admin.targetId = id
        admin.targetRole = role
        admin.targetAction = action
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

    onVisibleChanged: if (admin.visible) {
        admin.section = "general"
        admin.focusDefault()
    } else {
        confirm.close()
        invitationEmail.clear()
    }

    Connections {
        target: Session.orgAdmin
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
                    objectName: "closeOrgAdminButton"
                    text: qsTr("Back to files")
                    icon: "back"
                    showLabel: !admin.narrow
                    tip: text
                    onActivated: Session.orgAdmin.close()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gapXs
                    Caption {
                        Layout.fillWidth: true
                        text: qsTr("Organization administration")
                        color: Theme.accentText
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Session.orgAdmin.name !== "" ? Session.orgAdmin.name : qsTr("Organization")
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
                    usable: !Session.orgAdmin.busy
                    onActivated: Session.orgAdmin.refresh()
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

        Flickable {
            visible: admin.narrow
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
                    model: admin.sections
                    delegate: ActionButton {
                        required property var modelData
                        text: modelData.label
                        primary: admin.section === modelData.value
                        onActivated: admin.section = modelData.value
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                visible: !admin.narrow
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
                        model: admin.sections
                        delegate: ActionButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label
                            icon: modelData.icon
                            color: admin.section === modelData.value ? Theme.accentSoft : "transparent"
                            onActivated: admin.section = modelData.value
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: admin.narrow ? Theme.gapM : Theme.gapXl
                spacing: Theme.gapM

                Text {
                    Layout.fillWidth: true
                    text: admin.sections.find(function (s) { return s.value === admin.section }).label
                    font: Theme.heading
                    color: Theme.textPrimary
                    Accessible.role: Accessible.Heading
                }
                Label {
                    objectName: "orgAdminError"
                    visible: Session.orgAdmin.errorCode !== "" || admin.sectionError !== ""
                    text: Messages.adminFailure(Session.orgAdmin.errorCode || admin.sectionError)
                    color: Theme.failed
                    Accessible.role: Accessible.AlertMessage
                }
                Label {
                    objectName: "orgAdminNotice"
                    visible: Session.orgAdmin.notice !== ""
                    text: Messages.adminNotice(Session.orgAdmin.notice)
                    color: Theme.accentText
                }
                Label {
                    visible: Session.orgAdmin.busy
                    text: qsTr("Working…")
                }

                Flickable {
                    visible: admin.section === "general" && admin.sectionError === ""
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
                    visible: admin.section === "invitations" && admin.sectionError === ""
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
                    visible: admin.section === "members" && admin.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    narrow: admin.narrow
                    onRoleRequested: function (id, email, role) { admin.ask("role", id, email, role) }
                    onRemovalRequested: function (id, email) { admin.ask("remove", id, email, "") }
                }
                OrgAdminPeople {
                    id: invitations
                    visible: admin.section === "invitations" && admin.sectionError === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    invitations: true
                    narrow: admin.narrow
                    onCancellationRequested: function (id, email) { admin.ask("cancel", id, email, "") }
                }
                Label {
                    visible: !Session.orgAdmin.busy && admin.sectionError === ""
                             && ((admin.section === "members" && members.count === 0)
                                 || (admin.section === "invitations" && invitations.count === 0))
                    text: admin.section === "members" ? qsTr("No members to display.") : qsTr("No invitations yet.")
                }

                Flickable {
                    visible: admin.section === "usage" && admin.sectionError === ""
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
                Item { Layout.fillHeight: true; visible: admin.sectionError !== "" }
            }
        }
    }

    Confirm {
        id: confirm
        objectName: "orgAdminConfirm"
        anchors.fill: parent
        onAccepted: {
            if (admin.targetAction === "remove")
                Session.orgAdmin.removeMember(admin.targetId)
            else if (admin.targetAction === "cancel")
                Session.orgAdmin.cancelInvitation(admin.targetId)
            else
                Session.orgAdmin.changeRole(admin.targetId, admin.targetRole)
        }
        onVisibleChanged: if (!confirm.visible && admin.visible) admin.focusDefault()
    }
}
