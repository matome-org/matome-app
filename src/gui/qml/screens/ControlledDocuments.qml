pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages
import "../chrome/Commands.js" as Commands

// Document reviews over one space or document, in the Settings shell: head,
// section column (a drawer when narrow), and the section's page under its
// command bar. Pick an item, then a verb from the bar. Every verb is a row
// of Session.commandList, so its button, key, context menu, and sheet entry
// agree; ControlledDocs asks back through `requested` when a verb needs a
// comment, a reason, a member, or a confirmation first.
FocusScope {
    id: screen
    readonly property var control: Session.controlledDocs
    readonly property bool narrow: screen.width < 600
    readonly property bool touch: screen.narrow || Qt.platform.os === "android"
    readonly property bool unavailable: control.availability.known === true && control.availability.available !== true
    readonly property var sections: ["reviews", "edit", "control", "access"]
    readonly property var reviewCommands: ["download-candidate", "approve-review", "reject-review", "cancel-review"]
    readonly property bool reviewOpen: control.reviews.some(function (review) { return review.status === "open" })
    property string reviewView: "document"
    property string pendingAction
    property string pendingGrant
    property string pendingText
    property string submittedText
    property bool sourceRequested: false
    property bool dirty: control.sourceLoaded && markdown.text !== control.source && markdown.text !== submittedText

    function command(id) { return Commands.find(Session.commandList, id) }
    function memberEmail(id) {
        return screen.control.members.find(function (member) { return String(member.id) === String(id) })?.email ?? ""
    }
    function dismiss() {
        if (drawer.visible) drawer.close()
        else if (menu.visible) menu.dismiss()
        else if (confirmation.visible) confirmation.close()
        else if (grantDialog.visible) grantDialog.close()
        else if (screen.dirty) screen.ask("close")
        else screen.control.close()
    }
    function ask(action) {
        pendingAction = action
        confirmation.title = action === "approve" ? qsTr("Publish this proposal?")
                           : action === "reject" ? qsTr("Reject this proposal?")
                           : action === "cancel" ? qsTr("Cancel this review?")
                           : action === "submit" ? qsTr("Submit your changes for review?")
                           : action === "remove-control" ? qsTr("Remove document control?")
                           : action === "remove-rule" ? qsTr("Remove this space rule?")
                           : action === "revoke-access" ? qsTr("Revoke this access grant?")
                           : action === "reload-source" ? qsTr("Discard your changes?")
                           : qsTr("Discard your draft?")
        confirmation.detail = action === "approve" ? qsTr("The exact candidate shown in this review will become the published version.")
                            : action === "submit" ? qsTr("Reviewers see the edited document and its changes. The published version stays available until approval.")
                            : action === "remove-control" ? qsTr("Open reviews will be cancelled. Future versions will publish immediately.")
                            : action === "remove-rule" ? qsTr("Existing controlled documents will remain blocked until the rule is reactivated or their control is removed.")
                            : action === "revoke-access" ? qsTr("This removes the selected space role grant. Access from other grants is preserved.")
                            : action === "close" || action === "reload-source" ? qsTr("The editor returns to the published version.")
                            : qsTr("The published version will remain unchanged.")
        confirmation.reasonLabel = action === "submit" ? qsTr("Summary of the change")
                                 : action === "approve" || action === "reject" ? qsTr("Decision comment (optional)")
                                 : action === "remove-control" ? qsTr("Reason for removing document control")
                                 : action === "remove-rule" ? qsTr("Reason for removing the space rule") : ""
        confirmation.reasonRequired = action !== "approve" && action !== "reject"
        confirmation.reasonLength = action === "approve" || action === "reject" ? 2000 : 500
        confirmation.action = action === "approve" ? qsTr("Publish")
                            : action === "submit" ? qsTr("Submit for review") : qsTr("Confirm")
        confirmation.open()
    }
    // The verbs ControlledDocs hands back to the screen.
    function perform(id) {
        if (id === "approve-review") screen.ask("approve")
        else if (id === "reject-review") screen.ask("reject")
        else if (id === "cancel-review") screen.ask("cancel")
        else if (id === "discard-changes" && screen.dirty) screen.ask("reload-source")
        else if (id === "submit-proposal" && screen.dirty) screen.ask("submit")
        else if (id === "remove-rule") screen.ask("remove-rule")
        else if (id === "unmanage-document") screen.ask("remove-control")
        else if (id === "grant-access") grantDialog.open()
        else if (id === "revoke-access" && grantList.currentIndex >= 0) {
            screen.pendingGrant = screen.control.grants[grantList.currentIndex].id
            screen.ask("revoke-access")
        }
    }
    function selectReview(index) {
        const review = screen.control.reviews[index]
        reviewList.currentIndex = index
        if (review && screen.control.review.id !== review.id)
            screen.control.selectReview(review.id)
    }
    // The unified diff as blocks the width of the view: added lines on a
    // green wash, removed ones on a red wash, hunk heads muted. Unchanged
    // lines more than three away from a change fold into one marker.
    function diffHtml(diff) {
        const washAdded = Qt.tint(Theme.surface, Theme.fill(Theme.added, 0.16))
        const washRemoved = Qt.tint(Theme.surface, Theme.fill(Theme.failed, 0.14))
        const lines = diff.split("\n")
        const head = function (line) { return line.startsWith("+++") || line.startsWith("---") || line.startsWith("@@") }
        const changed = lines.map(function (line) { return !head(line) && (line.startsWith("+") || line.startsWith("-")) })
        const near = lines.map(function (line, at) {
            if (head(line)) return true
            for (let step = Math.max(0, at - 3); step <= Math.min(lines.length - 1, at + 3); ++step)
                if (changed[step]) return true
            return false
        })
        const block = function (text, style) {
            return "<p style=\"margin:0;white-space:pre-wrap;" + style + "\">" + text + "</p>"
        }
        let html = ""
        let folded = 0
        for (let at = 0; at <= lines.length; ++at) {
            if (at < lines.length && !near[at]) {
                ++folded
                continue
            }
            if (folded > 0) {
                html += block(qsTr("⋯ %n unchanged line(s)", "", folded), "color:" + Theme.textMuted + ";background-color:" + Theme.subtleFill)
                folded = 0
            }
            if (at === lines.length) break
            const line = lines[at]
            const text = line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") || "&nbsp;"
            html += block(text, head(line) ? "color:" + Theme.textMuted
                              : line.startsWith("+") ? "background-color:" + washAdded + ";color:" + Theme.textPrimary
                              : line.startsWith("-") ? "background-color:" + washRemoved + ";color:" + Theme.textPrimary
                              : "color:" + Theme.textSecondary)
        }
        return html
    }
    // The editor opens on the published version, once per visit.
    function loadSource() {
        if (screen.control.section === "edit" && !screen.control.sourceLoaded && !screen.sourceRequested
                && !screen.control.busy && screen.control.hasDocument) {
            screen.sourceRequested = true
            screen.control.loadPublished()
        }
    }
    function focusDefault() { header.backButton.forceActiveFocus() }
    onVisibleChanged: if (visible) focusDefault()

    Connections {
        target: Session.controlledDocs
        function onSourceChanged() {
            markdown.text = screen.control.source
            screen.submittedText = screen.control.source
        }
        function onProposalSubmitted() {
            screen.submittedText = screen.pendingText
            screen.control.section = "reviews"
        }
        function onRequested(id) { screen.perform(id) }
        function onChanged() {
            screen.loadSource()
            if (screen.control.active && screen.control.section === "reviews" && screen.control.review.id === undefined
                    && screen.control.reviews.length > 0 && !screen.control.busy)
                screen.selectReview(0)
            if (!screen.control.active) {
                screen.sourceRequested = false
                confirmation.close()
                grantDialog.close()
                drawer.close()
                markdown.text = ""
                screen.submittedText = ""
            }
        }
    }

    component Editor: C.TextArea {
        id: editor
        property bool highlighted: false
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Theme.controlXl * 3, editor.implicitHeight)
        font: Theme.body
        color: Theme.textPrimary
        placeholderTextColor: Theme.textMuted
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.textPrimary
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        selectByMouse: true
        activeFocusOnTab: true
        background: Rectangle {
            color: Theme.surface
            radius: Theme.rounding
            border.color: editor.highlighted || editor.activeFocus ? Theme.accentLine : Theme.border
        }
        // Tab leaves the editor; Ctrl+Enter reaches the window's keys.
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                editor.nextItemInFocusChain(event.key === Qt.Key_Tab).forceActiveFocus(Qt.TabFocusReason)
                event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                       && (event.modifiers & Qt.ControlModifier)) {
                event.accepted = Session.handleKey(event.key, event.modifiers, true)
            }
        }
    }

    // One of the review's two views; the gold-soft wash marks the one shown.
    component ViewTab: ActionButton {
        id: tab
        required property string view
        color: screen.reviewView === tab.view ? Theme.accentSoft : "transparent"
        Accessible.role: Accessible.PageTab
        Accessible.checkable: true
        Accessible.checked: screen.reviewView === tab.view
        onActivated: screen.reviewView = tab.view
    }

    component Navigation: Page {
        topMargin: Theme.gapM
        bottomMargin: Theme.gapM
        leftMargin: Theme.gapS
        rightMargin: Theme.gapS
        spacing: Theme.gapXs
        Repeater {
            model: screen.sections
            delegate: NavigationRow {
                id: entry
                required property string modelData
                readonly property var command: screen.command(entry.modelData + "-section")
                objectName: "controlledSection_" + entry.modelData
                visible: entry.command.usable
                touch: screen.touch
                checkable: true
                text: entry.command.title
                icon: entry.command.icon
                selected: screen.control.section === entry.modelData
                onActivated: {
                    Session.runCommand(entry.modelData + "-section")
                    drawer.close()
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
            narrow: screen.narrow
            caption: screen.control.title
            title: qsTr("Document reviews")
            backText: qsTr("Back to files")
            backName: "closeControlledButton"
            navigationName: "controlledNavigationButton"
            refreshName: "refreshControlledButton"
            refreshKey: "F5"
            refreshUsable: screen.command("refresh").usable
            onNavigationRequested: drawer.open()
            onBackRequested: screen.dismiss()
            onRefreshRequested: Session.runCommand("refresh")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                visible: !screen.narrow
                Layout.preferredWidth: Theme.column
                Layout.fillHeight: true
                color: Theme.surface
                Loader {
                    anchors.fill: parent
                    active: screen.visible && !screen.narrow
                    sourceComponent: Navigation {}
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: screen.narrow ? Theme.gapM : Theme.gapXl
                spacing: Theme.gapM

                SectionHead {
                    title: screen.command(screen.control.section + "-section").title

                    CommandButton { commandId: "download-candidate"; visible: screen.control.section === "reviews"; showLabel: !screen.narrow }
                    BarRule { visible: screen.control.section === "reviews" }
                    CommandButton { commandId: "approve-review"; visible: screen.control.section === "reviews"; primary: true }
                    CommandButton { commandId: "reject-review"; visible: screen.control.section === "reviews"; showLabel: !screen.narrow }
                    CommandButton { commandId: "cancel-review"; visible: screen.control.section === "reviews"; showLabel: !screen.narrow }

                    CommandButton {
                        id: discard
                        commandId: "discard-changes"
                        visible: screen.control.section === "edit"
                        showLabel: !screen.narrow
                        usable: discard.command.usable && screen.dirty
                    }
                    CommandButton {
                        id: submit
                        commandId: "submit-proposal"
                        visible: screen.control.section === "edit"
                        primary: true
                        usable: submit.command.usable && screen.dirty
                    }

                    CommandButton {
                        id: selfGrant
                        commandId: "grant-self-management"
                        visible: screen.control.section === "control" && selfGrant.usable
                        primary: true
                    }
                    CommandButton { commandId: "activate-rule"; visible: screen.control.section === "control"; showLabel: !screen.narrow }
                    CommandButton { commandId: "pause-rule"; visible: screen.control.section === "control"; showLabel: !screen.narrow }
                    CommandButton { commandId: "remove-rule"; visible: screen.control.section === "control"; showLabel: !screen.narrow }
                    BarRule { visible: screen.control.section === "control" && screen.control.hasDocument }
                    CommandButton { commandId: "manage-document"; visible: screen.control.section === "control" && screen.control.hasDocument; showLabel: !screen.narrow }
                    CommandButton { commandId: "unmanage-document"; visible: screen.control.section === "control" && screen.control.hasDocument; showLabel: !screen.narrow }

                    CommandButton { commandId: "grant-access"; visible: screen.control.section === "access"; primary: true }
                    CommandButton { commandId: "revoke-access"; visible: screen.control.section === "access"; showLabel: !screen.narrow }
                }
                Label {
                    visible: screen.unavailable
                    text: qsTr("This add-on is paused, unavailable, or outside this space. Published documents remain readable; proposals and approvals are blocked.")
                }
                Label {
                    objectName: "controlledError"
                    visible: screen.control.errorCode !== ""
                    color: Theme.failed
                    text: Messages.controlledFailure(screen.control.errorCode)
                    Accessible.role: Accessible.AlertMessage
                }
                Label {
                    visible: screen.control.notice !== ""
                    color: Theme.accentText
                    text: Messages.controlledNotice(screen.control.notice)
                }
                Label { visible: screen.control.busy; text: qsTr("Working…") }

                Page {
                    visible: screen.control.section === "reviews"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Label {
                        visible: screen.control.reviewsError !== ""
                        text: Messages.controlledFailure(screen.control.reviewsError)
                        color: Theme.failed
                    }
                    Label {
                        visible: screen.control.reviews.length === 0 && !screen.control.busy && screen.control.reviewsError === ""
                        text: qsTr("No reviews yet. Propose changes to start one.")
                    }
                    CursorList {
                        id: reviewList
                        objectName: "controlledReviewList"
                        visible: reviewList.count > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: reviewList.contentHeight
                        interactive: false
                        activeFocusOnTab: true
                        spacing: Theme.gapS
                        rowHeight: screen.touch ? Theme.rowTouch : Theme.controlM
                        model: screen.control.reviews
                        Accessible.role: Accessible.List
                        Accessible.name: qsTr("Reviews")
                        onMenuRequested: if (reviewList.currentItem) {
                            screen.selectReview(reviewList.currentIndex)
                            menu.show(screen.reviewCommands, reviewList.currentItem, 0, reviewList.currentItem.height, reviewList)
                        }
                        delegate: ListRow {
                            id: reviewRow
                            required property var modelData
                            required property int index
                            objectName: "controlledReview_" + reviewRow.modelData.id
                            view: reviewList
                            touch: screen.touch
                            cursor: reviewList.currentIndex === reviewRow.index
                            title: Messages.reviewStatus(reviewRow.modelData.status) + " · " + reviewRow.modelData.reason
                            detail: [screen.memberEmail(reviewRow.modelData.author_membership_id),
                                     reviewRow.modelData.inserted_at ? new Date(reviewRow.modelData.inserted_at).toLocaleString(Qt.locale(), Locale.ShortFormat) : ""]
                                    .filter(function (part) { return part !== "" }).join(" · ")
                            selected: screen.control.review.id === reviewRow.modelData.id
                            onClicked: screen.selectReview(reviewRow.index)
                            onActivated: screen.selectReview(reviewRow.index)
                            onMenuRequested: function (position) {
                                screen.selectReview(reviewRow.index)
                                menu.show(screen.reviewCommands, reviewRow, position.x, position.y, reviewList)
                            }
                        }
                    }
                    ColumnLayout {
                        visible: screen.control.review.id !== undefined
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.gapS
                        spacing: Theme.gapS
                        Text {
                            Layout.fillWidth: true
                            text: screen.control.review.reason ?? ""
                            font: Theme.heading
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                        Label {
                            visible: screen.control.review.decision !== null && screen.control.review.decision !== undefined
                            text: qsTr("Decision comment: %1").arg(screen.control.review.decision?.comment ?? "")
                        }
                        Label {
                            visible: screen.control.review.status === "open"
                            text: qsTr("Approval requires explicit review permissions and a reviewer other than the author. The server authorizes every decision.")
                        }
                        RowLayout {
                            spacing: Theme.gapXs
                            Accessible.role: Accessible.PageTabList
                            ViewTab { view: "document"; text: qsTr("Document"); icon: "document" }
                            ViewTab { view: "changes"; text: qsTr("Changes"); icon: "diff" }
                        }
                        TextEdit {
                            objectName: "controlledCandidate"
                            visible: screen.reviewView === "document"
                            Layout.fillWidth: true
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            activeFocusOnTab: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.MarkdownText
                            text: screen.control.candidate
                            font: Theme.body
                            color: Theme.textPrimary
                            selectionColor: Theme.accentSoft
                            selectedTextColor: Theme.textPrimary
                            Accessible.name: qsTr("Edited document")
                        }
                        TextEdit {
                            objectName: "controlledDiff"
                            visible: screen.reviewView === "changes"
                            Layout.fillWidth: true
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            activeFocusOnTab: true
                            wrapMode: TextEdit.WrapAnywhere
                            textFormat: TextEdit.RichText
                            text: screen.diffHtml(screen.control.diff)
                            font: Theme.mono
                            selectionColor: Theme.accentSoft
                            Accessible.name: qsTr("Changes")
                        }
                    }
                }

                Page {
                    visible: screen.control.section === "edit"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Label {
                        text: screen.reviewOpen ? qsTr("A review of this document is open. Decide or cancel it before submitting more changes.")
                                                : qsTr("Edit the Markdown, or drop an .md file on it. Submitting sends the edited document for review; the published version stays available until approval.")
                    }
                    Label {
                        visible: screen.control.draftStale
                        color: Theme.failed
                        text: qsTr("The published version changed since you started editing. Copy your edits, then discard them to start from the new version.")
                    }
                    Editor {
                        id: markdown
                        objectName: "controlledMarkdownEditor"
                        placeholderText: qsTr("Markdown")
                        Accessible.name: markdown.placeholderText
                        Layout.preferredHeight: Math.max(10 * Theme.controlL, markdown.implicitHeight)
                        enabled: !screen.control.busy && screen.control.sourceLoaded
                        highlighted: drop.containsDrag
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            onEntered: function (drag) { drag.accepted = drag.hasUrls && markdown.enabled }
                            onDropped: function (event) {
                                const text = screen.control.readDraft(event.urls[0])
                                if (text !== "")
                                    markdown.text = text
                                event.acceptProposedAction()
                            }
                        }
                    }
                }

                Page {
                    visible: screen.control.section === "control"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Label {
                        visible: screen.control.ruleError === "forbidden"
                        color: Theme.failed
                        text: screen.command("grant-self-management").usable
                              ? qsTr("You need management access to this space. Organization administrators get it only through an explicit grant: use Grant me management access.")
                              : qsTr("You need management access to this space. Ask an organization administrator to grant it in Review access.")
                    }
                    Label {
                        visible: screen.control.ruleError !== "" && screen.control.ruleError !== "forbidden"
                        text: Messages.controlledFailure(screen.control.ruleError)
                        color: Theme.failed
                    }
                    TileGrid {
                        Card {
                            Layout.alignment: Qt.AlignTop
                            Caption { Layout.fillWidth: true; text: qsTr("Space rule") }
                            Text {
                                Layout.fillWidth: true
                                text: screen.control.rule.active === true ? qsTr("Active") : qsTr("Inactive or absent")
                                font: Theme.heading
                                color: Theme.textPrimary
                                wrapMode: Text.Wrap
                            }
                            Label { text: qsTr("Control requires an active installation, a space rule, and explicit permissions.") }
                        }
                        Card {
                            visible: screen.control.hasDocument
                            Layout.alignment: Qt.AlignTop
                            Caption { Layout.fillWidth: true; text: qsTr("This document") }
                            Text {
                                Layout.fillWidth: true
                                text: screen.control.controlled ? qsTr("Managed") : qsTr("Not managed")
                                font: Theme.heading
                                color: Theme.textPrimary
                                wrapMode: Text.Wrap
                            }
                            Label { text: qsTr("Documents must already have a published Markdown version.") }
                        }
                    }
                }

                Page {
                    visible: screen.control.section === "access"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Label { text: qsTr("Organization administrators need explicit control grants too. Grant management access to configure rules and documents, or reviewer access to read and decide proposals. Authors cannot approve their own proposals.") }
                    Label {
                        visible: screen.control.accessError !== ""
                        text: Messages.controlledFailure(screen.control.accessError)
                        color: Theme.failed
                    }
                    Label {
                        visible: grantList.count === 0
                        text: qsTr("No review access granted in this space yet.")
                    }
                    CursorList {
                        id: grantList
                        objectName: "controlledGrantList"
                        visible: grantList.count > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: grantList.contentHeight
                        interactive: false
                        activeFocusOnTab: true
                        spacing: Theme.gapS
                        rowHeight: screen.touch ? Theme.rowTouch : Theme.controlM
                        model: screen.control.grants
                        Accessible.role: Accessible.List
                        Accessible.name: qsTr("Grants")
                        onMenuRequested: if (grantList.currentItem)
                            menu.show(["revoke-access"], grantList.currentItem, 0, grantList.currentItem.height, grantList)
                        delegate: ListRow {
                            id: grantRow
                            required property var modelData
                            required property int index
                            view: grantList
                            touch: screen.touch
                            cursor: grantList.currentIndex === grantRow.index
                            title: grantRow.modelData.email || qsTr("Group or role grant")
                            detail: grantRow.modelData.name
                            selected: grantRow.cursor
                            onClicked: grantList.currentIndex = grantRow.index
                            onActivated: grantList.currentIndex = grantRow.index
                            onMenuRequested: function (position) {
                                grantList.currentIndex = grantRow.index
                                menu.show(["revoke-access"], grantRow, position.x, position.y, grantList)
                            }
                        }
                    }
                }
            }
        }
    }

    NavigationDrawer {
        id: drawer
        objectName: "controlledNavigationDrawer"
        navigation: Navigation {}
        onClosed: if (screen.visible && screen.narrow) header.navigationButton.forceActiveFocus()
    }

    ContextMenu {
        id: menu
        commands: Session.commandList
        touch: screen.touch
        onChosen: function (id) { Session.runCommand(id) }
    }

    Dialog {
        id: grantDialog
        objectName: "controlledGrantDialog"
        anchors.fill: parent
        title: qsTr("Grant access")
        action: qsTr("Grant")
        ready: accessMember.currentIndex >= 0 && accessKind.currentIndex >= 0
        initialFocus: accessMember
        onAccepted: screen.control.grantAccess(String(accessMember.currentValue), accessKind.currentValue === "manage")
        Label { text: qsTr("Member") }
        Picker {
            id: accessMember
            Layout.fillWidth: true
            model: screen.control.members
            textRole: "email"
            valueRole: "id"
            Accessible.name: qsTr("Member receiving access")
        }
        Label { text: qsTr("Access") }
        Picker {
            id: accessKind
            Layout.fillWidth: true
            model: [{ value: "review", label: qsTr("Reviewer: read and decide proposals") },
                    { value: "manage", label: qsTr("Management: configure rules and documents") }]
            value: "review"
            Accessible.name: qsTr("Access")
        }
    }

    Confirm {
        id: confirmation
        objectName: "controlledConfirm"
        anchors.fill: parent
        onAccepted: {
            if (screen.pendingAction === "close") screen.control.close()
            else if (screen.pendingAction === "reload-source") screen.control.loadPublished()
            else if (screen.pendingAction === "submit") {
                screen.pendingText = markdown.text
                screen.control.submit(markdown.text, confirmation.reason)
            }
            else if (screen.pendingAction === "remove-control") screen.control.setControlled(false, confirmation.reason)
            else if (screen.pendingAction === "remove-rule") screen.control.removeRule(confirmation.reason)
            else if (screen.pendingAction === "revoke-access") screen.control.revokeAccess(screen.pendingGrant)
            else screen.control.decide(screen.pendingAction, confirmation.reason)
        }
        onVisibleChanged: if (!visible && screen.visible) screen.focusDefault()
    }
}
