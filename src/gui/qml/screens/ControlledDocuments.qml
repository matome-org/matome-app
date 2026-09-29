pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

FocusScope {
    id: screen
    readonly property var control: Session.controlledDocs
    readonly property bool narrow: width < 600
    readonly property bool unavailable: control.availability.known === true && control.availability.available !== true
    property string tab: "reviews"
    property string pendingAction
    property string pendingGrant
    property string pendingText
    property string submittedText
    property bool dirty: markdown.text !== control.source && markdown.text !== submittedText

    function dismiss() {
        if (confirmation.visible) { confirmation.close(); return }
        if (dirty) ask("close")
        else control.close()
    }
    function ask(action) {
        pendingAction = action
        confirmation.title = action === "approve" ? qsTr("Publish this proposal?")
                           : action === "reject" ? qsTr("Reject this proposal?")
                           : action === "cancel" ? qsTr("Cancel this review?")
                           : action === "remove-control" ? qsTr("Remove document control?")
                           : action === "remove-rule" ? qsTr("Remove this space rule?")
                           : action === "revoke-access" ? qsTr("Revoke this access grant?")
                           : qsTr("Discard your draft?")
        confirmation.detail = action === "approve" ? qsTr("The exact candidate shown in this review will become the published version.")
                            : action === "remove-control" ? qsTr("Open reviews will be cancelled. Future versions will publish immediately.")
                            : action === "remove-rule" ? qsTr("Existing controlled documents will remain blocked until the rule is reactivated or their control is removed.")
                            : action === "revoke-access" ? qsTr("This removes the selected space role grant. Access from other grants is preserved.")
                            : action === "close" ? qsTr("Your unsent Markdown changes will be discarded.")
                            : qsTr("The published version will remain unchanged.")
        confirmation.action = action === "approve" ? qsTr("Publish") : qsTr("Confirm")
        confirmation.open()
    }
    function focusDefault() { back.forceActiveFocus() }
    onVisibleChanged: if (visible) focusDefault()

    Connections {
        target: Session.controlledDocs
        function onSourceChanged() {
            markdown.text = screen.control.source
            screen.submittedText = screen.control.source
        }
        function onProposalSubmitted() {
            screen.submittedText = screen.pendingText
            screen.tab = "reviews"
        }
        function onChanged() {
            if (!screen.control.active) {
                confirmation.close()
                markdown.text = ""
                reason.text = ""
                removalReason.text = ""
                comment.text = ""
                screen.tab = "reviews"
                screen.submittedText = ""
            }
        }
    }

    component Label: Text {
        Layout.fillWidth: true
        font: Theme.body
        color: Theme.textSecondary
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }
    component Editor: C.TextArea {
        Layout.fillWidth: true
        font: Theme.body
        color: Theme.textPrimary
        placeholderTextColor: Theme.textMuted
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.textPrimary
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        selectByMouse: true
        clip: true
        activeFocusOnTab: true
        background: Rectangle { color: Theme.surface; border.color: Theme.border; radius: Theme.rounding }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: screen.narrow ? Theme.gapM : Theme.gapL
        spacing: Theme.gapM
        RowLayout {
            Layout.fillWidth: true
            ActionButton { id: back; text: qsTr("Back"); onActivated: screen.dismiss() }
            Text {
                Layout.fillWidth: true
                text: qsTr("Controlled documents")
                color: Theme.textPrimary
                font: Theme.heading
                elide: Text.ElideRight
            }
            ActionButton { text: qsTr("Refresh"); usable: !screen.control.busy; onActivated: screen.control.refresh() }
        }
        Label { text: screen.control.title; font: Theme.bodyLarge }
        Label {
            visible: screen.unavailable
            text: qsTr("This add-on is paused, unavailable, or outside this space. Published documents remain readable; proposals and approvals are blocked.")
        }
        Label {
            visible: !screen.control.availability.known
            text: qsTr("Availability and permissions are verified by the server when you perform an action.")
        }
        Label { visible: screen.control.busy; text: qsTr("Loading…") }
        Label { visible: screen.control.errorCode !== ""; color: Theme.failed; text: Messages.controlledFailure(screen.control.errorCode) }
        Label { visible: screen.control.notice !== ""; color: Theme.accentText; text: Messages.controlledNotice(screen.control.notice) }
        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: Theme.gapS
            ActionButton { text: qsTr("Reviews"); primary: screen.tab === "reviews"; onActivated: screen.tab = "reviews" }
            ActionButton { text: qsTr("Propose changes"); primary: screen.tab === "proposal"; onActivated: screen.tab = "proposal" }
            ActionButton { text: qsTr("Control"); primary: screen.tab === "control"; onActivated: screen.tab = "control" }
        }
        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: content.implicitHeight
            C.ScrollBar.vertical: ThinScrollBar {}
            ColumnLayout {
                id: content
                width: scroll.width
                spacing: Theme.gapM

                ColumnLayout {
                    visible: screen.tab === "reviews"
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    Label { visible: screen.control.reviewsError !== ""; text: Messages.controlledFailure(screen.control.reviewsError); color: Theme.failed }
                    Label { visible: screen.control.reviews.length === 0 && !screen.control.busy; text: qsTr("No reviews available. Select a document to inspect its history.") }
                    Repeater {
                        model: screen.control.reviews
                        delegate: ActionButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: Messages.reviewStatus(modelData.status) + " · " + modelData.reason
                            primary: screen.control.review.id === modelData.id
                            usable: !screen.control.busy
                            onActivated: { comment.text = ""; screen.control.selectReview(modelData.id) }
                        }
                    }
                    ColumnLayout {
                        visible: screen.control.review.id !== undefined
                        Layout.fillWidth: true
                        spacing: Theme.gapS
                        Label { text: qsTr("Reason: %1").arg(screen.control.review.reason ?? "") }
                        Label { text: qsTr("Submitted: %1").arg(screen.control.review.inserted_at ? new Date(screen.control.review.inserted_at).toLocaleString(Qt.locale(), Locale.ShortFormat) : "") }
                        Label {
                            visible: screen.control.review.decision !== null && screen.control.review.decision !== undefined
                            text: qsTr("Decision comment: %1").arg(screen.control.review.decision?.comment ?? "")
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            ActionButton { text: qsTr("Show diff"); usable: !screen.control.busy; onActivated: screen.control.loadDiff() }
                            ActionButton { text: qsTr("Download candidate"); usable: !screen.control.busy; onActivated: screen.control.downloadCandidate() }
                        }
                        C.ScrollView {
                            visible: screen.control.diff !== ""
                            Layout.fillWidth: true
                            Layout.preferredHeight: 400
                            clip: true
                            contentWidth: availableWidth
                            Editor {
                                readOnly: true
                                text: screen.control.diff
                                font.family: "monospace"
                                wrapMode: TextEdit.WrapAnywhere
                            }
                        }
                        Editor {
                            id: comment
                            visible: screen.control.review.status === "open"
                            placeholderText: qsTr("Decision comment (optional)")
                            Layout.preferredHeight: 100
                            enabled: !screen.control.busy
                        }
                        Label {
                            visible: screen.control.review.status === "open"
                            text: qsTr("Approval requires explicit review permissions and a reviewer other than the author. The server authorizes every decision.")
                        }
                        Flow {
                            visible: screen.control.review.status === "open"
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            spacing: Theme.gapS
                            ActionButton { text: qsTr("Approve"); primary: true; usable: screen.control.canDecide; onActivated: screen.ask("approve") }
                            ActionButton { text: qsTr("Reject"); usable: screen.control.canDecide; onActivated: screen.ask("reject") }
                            ActionButton { text: qsTr("Cancel review"); usable: !screen.control.busy; onActivated: screen.ask("cancel") }
                        }
                    }
                }

                ColumnLayout {
                    visible: screen.tab === "proposal"
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    Label { text: qsTr("Edit Markdown up to 1 MiB. Submitting creates a proposal; the published document stays available until approval.") }
                    Label {
                        visible: screen.control.draftStale
                        color: Theme.failed
                        text: qsTr("The published version changed since this draft was loaded. Copy your edits before reloading the published Markdown.")
                    }
                    ActionButton {
                        text: qsTr("Load published Markdown")
                        usable: !screen.control.busy
                        onActivated: screen.dirty ? screen.ask("reload-source") : screen.control.loadPublished()
                    }
                    Editor {
                        id: markdown
                        objectName: "controlledMarkdownEditor"
                        placeholderText: qsTr("Markdown proposal")
                        Layout.preferredHeight: 320
                        enabled: !screen.control.busy
                    }
                    Field { id: reason; objectName: "controlledReasonField"; placeholderText: qsTr("Reason for this change"); maximumLength: 500; enabled: !screen.control.busy }
                    ActionButton {
                        text: qsTr("Submit proposal")
                        primary: true
                        usable: screen.control.canSubmit && reason.text.trim() !== ""
                        onActivated: {
                            screen.pendingText = markdown.text
                            screen.control.submit(markdown.text, reason.text)
                        }
                    }
                }

                ColumnLayout {
                    visible: screen.tab === "control"
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    Label { text: qsTr("Control requires an active installation, a space rule, and explicit permissions. Documents must already have a published Markdown version.") }
                    Label { visible: screen.control.ruleError !== ""; text: Messages.controlledFailure(screen.control.ruleError); color: Theme.failed }
                    Label { text: screen.control.rule.active === true ? qsTr("Space rule active") : qsTr("Space rule inactive or absent") }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: Theme.gapS
                        ActionButton { text: qsTr("Activate space rule"); usable: !screen.control.busy && screen.control.canManageRule && !screen.unavailable; onActivated: screen.control.saveRule(true) }
                        ActionButton { text: qsTr("Pause space rule"); usable: !screen.control.busy && screen.control.canManageRule && screen.control.rule.active === true && !screen.unavailable; onActivated: screen.control.saveRule(false) }
                        ActionButton { text: qsTr("Enable document control"); usable: !screen.control.busy && !screen.control.controlled && !screen.unavailable && screen.control.rule.active === true; onActivated: screen.control.setControlled(true) }
                    }
                    Label { text: screen.control.controlled ? qsTr("Document control enabled") : qsTr("Document control disabled") }
                    Field { id: removalReason; placeholderText: qsTr("Reason for removing control or the rule"); maximumLength: 500; enabled: !screen.control.busy }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: Theme.gapS
                        ActionButton { text: qsTr("Remove document control"); usable: !screen.control.busy && screen.control.controlled && removalReason.text.trim() !== ""; onActivated: screen.ask("remove-control") }
                        ActionButton { text: qsTr("Remove space rule"); usable: !screen.control.busy && screen.control.canManageRule && screen.control.rule.id !== undefined && removalReason.text.trim() !== ""; onActivated: screen.ask("remove-rule") }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: Session.addOns.canInstall
                        spacing: Theme.gapS
                        Label { text: qsTr("Review access for this space"); font: Theme.bodyLarge }
                        Label { text: qsTr("Organization administrators need explicit control grants too. Grant management access to configure rules and documents, or reviewer access to read and decide proposals. Authors cannot approve their own proposals.") }
                        Label { visible: screen.control.accessError !== ""; text: Messages.controlledFailure(screen.control.accessError); color: Theme.failed }
                        C.ComboBox {
                            id: accessMember
                            Layout.fillWidth: true
                            model: screen.control.members
                            textRole: "email"
                            valueRole: "id"
                            enabled: screen.control.canAssign
                            font: Theme.body
                            palette.text: Theme.textPrimary
                            palette.button: Theme.surface
                            Accessible.name: qsTr("Member receiving access")
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            spacing: Theme.gapS
                            ActionButton { text: qsTr("Grant management access"); usable: screen.control.canAssign && accessMember.currentIndex >= 0; onActivated: screen.control.grantAccess(String(accessMember.currentValue), true) }
                            ActionButton { text: qsTr("Grant reviewer access"); usable: screen.control.canAssign && accessMember.currentIndex >= 0; onActivated: screen.control.grantAccess(String(accessMember.currentValue), false) }
                        }
                        Repeater {
                            model: screen.control.grants
                            delegate: RowLayout {
                                id: grantRow
                                required property var modelData
                                Layout.fillWidth: true
                                Label { text: (grantRow.modelData.email || qsTr("Group or role grant")) + " · " + grantRow.modelData.name }
                                ActionButton {
                                    text: qsTr("Revoke")
                                    usable: screen.control.canAssign
                                    onActivated: { screen.pendingGrant = grantRow.modelData.id; screen.ask("revoke-access") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Confirm {
        id: confirmation
        anchors.fill: parent
        onAccepted: {
            if (screen.pendingAction === "close") screen.control.close()
            else if (screen.pendingAction === "reload-source") screen.control.loadPublished()
            else if (screen.pendingAction === "remove-control") screen.control.setControlled(false, removalReason.text)
            else if (screen.pendingAction === "remove-rule") screen.control.removeRule(removalReason.text)
            else if (screen.pendingAction === "revoke-access") screen.control.revokeAccess(screen.pendingGrant)
            else screen.control.decide(screen.pendingAction, comment.text)
        }
        onVisibleChanged: if (!visible && screen.visible) screen.focusDefault()
    }
}
