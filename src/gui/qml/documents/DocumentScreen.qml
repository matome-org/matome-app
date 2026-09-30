pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import matome
import "../chrome"
import "../controlled_docs"
import "../chrome/Messages.js" as Messages
import "../chrome/Commands.js" as Commands

// Any document of the open space, opened from the explorer: a preview of
// the selected version when its type has one, an editor for Markdown and
// text, the list of versions, and the documents it links or that link it.
// Every verb is a row of Session.commandList,
// so its button, key, and sheet entry agree. The controlled-documents
// add-on, when it applies, adds its Reviews tab and turns a save into a
// review; a review opened from that tab takes the whole screen, one level
// below the document. Nothing here depends on the add-on being there.
FocusScope {
    id: screen

    readonly property var view: Session.documentView
    readonly property var control: Session.controlledDocs
    readonly property bool managed: control.active && control.controlled
    readonly property bool inReview: control.active && control.review.id !== undefined
    // The opened review still awaits a decision.
    readonly property bool reviewOpen: screen.inReview && control.review.status === "open"
    readonly property bool narrow: screen.width < 600
    readonly property bool touch: screen.narrow || Qt.platform.os === "android"
    // The editor holds the proposal of one of the author's reviews.
    readonly property bool proposing: control.active && control.proposalReviewId !== ""
    readonly property string proposalReason: control.reviews.find(function (review) {
        return review.id === control.proposalReviewId })?.reason ?? ""
    // Core's conflict markers are still in the proposal.
    readonly property bool conflicted: screen.proposing && /^(<<<<<<< published|>>>>>>> review)$/m.test(editor.text)
    readonly property bool dirty: view.editable && (editor.text !== view.text || screen.proposing)
    readonly property var tabs: ["view", "edit", "versions", "related", "reviews"]
    readonly property bool unrelated: view.relatedLoaded && view.incoming.length === 0 && view.outgoing.length === 0
                                      && view.hiddenCount === 0
    property string draftView: "write"
    property string pendingAction
    // The document selected on the Related tab, when it opens.
    property string relatedPick

    function command(id) { return Commands.find(Session.commandList, id) }
    // One row of the Related tab from Core's incoming or outgoing reference.
    function relatedRow(item, incoming) {
        const join = function (parts) { return parts.filter(function (part) { return part !== "" }).join(" · ") }
        if (incoming)
            return { id: String(item.document_id), title: item.title ?? "", openable: true,
                     detail: join([item.path ?? "", (item.modes ?? []).indexOf("path") >= 0 ? qsTr("By path") : ""]) }
        const target = item.target ?? {}
        const ok = target.state === "ok"
        return { id: ok ? String(target.document_id) : "",
                 title: target.title ?? item.path ?? qsTr("Unavailable file"),
                 detail: join([target.path ?? "", Messages.referenceState(target.state),
                               item.mode === "version" ? qsTr("Pinned version") : item.mode === "path" ? qsTr("By path") : ""]),
                 openable: ok }
    }
    function dismiss() {
        if (confirmation.visible) confirmation.close()
        else if (screen.inReview) Session.runCommand("close-review")
        else if (screen.dirty) screen.ask("close")
        else screen.view.close()
    }
    function ask(action) {
        screen.pendingAction = action
        const review = action === "save" && screen.managed
        if (action === "save" && screen.proposing) {
            confirmation.title = qsTr("Update this review?")
            confirmation.detail = qsTr("The edited text becomes the review's proposal, based on the published version. The review keeps its summary.")
            confirmation.reasonLabel = qsTr("What changed")
            confirmation.reasonRequired = true
            confirmation.reasonLength = 500
            confirmation.action = qsTr("Update review")
            confirmation.open()
            return
        }
        confirmation.title = action === "save" ? (review ? qsTr("Submit your changes for review?") : qsTr("Save a new version?"))
                           : action === "approve" ? qsTr("Publish this proposal?")
                           : action === "reject" ? qsTr("Reject this proposal?")
                           : action === "cancel" ? qsTr("Cancel this review?")
                           : action === "unmanage" ? qsTr("Stop managing this document?")
                           : qsTr("Discard your changes?")
        confirmation.detail = action === "save" ? (review ? qsTr("Reviewers see the edited document and its changes. The published version stays available until approval.")
                                                          : qsTr("The edited text becomes the document's current version. Earlier versions stay under Versions."))
                            : action === "approve" ? qsTr("The exact candidate shown in this review will become the published version.")
                            : action === "unmanage" ? qsTr("Open reviews will be cancelled. Future versions will publish immediately.")
                            : action === "reject" || action === "cancel" ? qsTr("The published version will remain unchanged.")
                            : qsTr("The editor returns to the current version.")
        confirmation.reasonLabel = action === "save" ? (review ? qsTr("Summary of the change") : qsTr("Describe the change (optional)"))
                                 : action === "approve" || action === "reject" ? qsTr("Decision comment (optional)")
                                 : action === "unmanage" ? qsTr("Reason for no longer managing it") : ""
        confirmation.reasonRequired = review || action === "unmanage"
        confirmation.reasonLength = action === "approve" || action === "reject" ? 2000 : 500
        confirmation.action = action === "save" ? (review ? qsTr("Submit for review") : qsTr("Save"))
                            : action === "approve" ? qsTr("Publish") : qsTr("Confirm")
        confirmation.open()
    }
    // The verbs the document screen and the add-on hand back to it.
    function perform(id) {
        if (id === "save-document" && screen.dirty && !screen.conflicted) screen.ask("save")
        else if (id === "discard-changes" && screen.dirty) screen.ask("discard")
        else if (id === "insert-image") Session.assets.pickImages()
        else if (id === "approve-review") screen.ask("approve")
        else if (id === "reject-review") screen.ask("reject")
        else if (id === "cancel-review") screen.ask("cancel")
        else if (id === "unmanage-document") screen.ask("unmanage")
    }
    function focusDefault() { header.backButton.forceActiveFocus() }
    // Going into a review or back out of it keeps the keyboard where it went.
    onInReviewChanged: if (screen.visible) {
        if (screen.inReview) screen.focusDefault()
        else reviewList.focusList()
    }
    onVisibleChanged: if (visible) {
        screen.draftView = "write"
        focusDefault()
    }

    Connections {
        target: Session.documentView
        function onTextChanged() { editor.text = screen.view.text }
        function onRequested(id) { screen.perform(id) }
        function onOpened() { screen.relatedPick = "" }
        function onSaved() {
            if (screen.view.notice === "review_requested" || screen.view.notice === "review_updated")
                screen.view.tab = "reviews"
        }
        function onChanged() {
            if (screen.view.errorIndex < 0 || screen.view.tab !== "edit")
                return
            const at = Session.assets.referenceAt(editor.text, screen.view.errorIndex, !screen.control.pinsLinks)
            if (at.start !== undefined) {
                screen.draftView = "write"
                editor.select(at.start, at.start + at.length)
                editor.forceActiveFocus()
            }
        }
    }
    Connections {
        target: Session.controlledDocs
        function onRequested(id) { screen.perform(id) }
        // The author's review, merged over the published version, goes to
        // the editor with the cursor on its first conflict.
        function onProposalReady(text, conflicts) {
            editor.text = text
            screen.draftView = "write"
            screen.view.tab = "edit"
            const at = conflicts > 0 ? text.search(/^<<<<<<< published$/m) : -1
            editor.cursorPosition = Math.max(0, at)
            if (at >= 0)
                editor.select(at, at + "<<<<<<< published".length)
            editor.forceActiveFocus()
        }
    }
    Connections {
        target: Session.assets
        function onPromptPick() { if (screen.visible) imagePicker.open() }
    }

    FileDialog {
        id: imagePicker
        title: qsTr("Insert image")
        fileMode: FileDialog.OpenFiles
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.gif *.webp)")]
        onAccepted: Session.assets.uploadUrls(imagePicker.selectedFiles)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ScreenHeader {
            id: header
            Layout.fillWidth: true
            narrow: screen.narrow
            caption: screen.inReview ? screen.view.place.concat([screen.view.title, qsTr("Reviews")]).join(" › ")
                                     : screen.view.place.join(" › ")
            title: screen.inReview ? screen.control.review.reason : screen.view.title
            backText: screen.inReview ? qsTr("Back to reviews") : qsTr("Back to files")
            backName: "closeDocumentButton"
            refreshName: "refreshDocumentButton"
            refreshKey: "F5"
            refreshUsable: screen.command("refresh").usable
            onBackRequested: screen.dismiss()
            onRefreshRequested: Session.runCommand("refresh")
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: screen.narrow ? Theme.gapM : Theme.gapXl
            spacing: Theme.gapM

            Item {
                Layout.fillWidth: true
                implicitHeight: bar.implicitHeight + Theme.gapM + 1
                RowLayout {
                    id: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Theme.gapL
                    RowLayout {
                        visible: !screen.inReview
                        spacing: Theme.gapXs
                        Accessible.role: Accessible.PageTabList
                        Repeater {
                            model: screen.tabs
                            delegate: ViewTab {
                                id: tab
                                required property string modelData
                                readonly property var command: screen.command(tab.modelData + "-tab")
                                objectName: "documentTab_" + tab.modelData
                                visible: tab.command.usable
                                view: tab.modelData
                                current: screen.view.tab
                                text: tab.command.title
                                icon: tab.command.icon
                                showLabel: !screen.narrow
                                tip: tab.command.title
                                key: Commands.keys(tab.command)[0] ?? ""
                                onPicked: function (view) { Session.runCommand(view + "-tab") }
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    CommandBar {
                        Accessible.role: Accessible.ToolBar
                        Accessible.name: screen.view.title

                        CommandButton { id: manage; commandId: "manage-document"; visible: screen.view.tab === "view" && manage.usable; showLabel: !screen.narrow }
                        CommandButton { id: unmanage; commandId: "unmanage-document"; visible: screen.view.tab === "view" && unmanage.usable; showLabel: !screen.narrow }
                        CommandButton { commandId: "download-version"; visible: screen.view.tab === "view" || screen.view.tab === "versions"; showLabel: !screen.narrow }
                        ActionButton {
                            visible: screen.view.tab === "versions"
                            text: qsTr("Show this version")
                            icon: "document"
                            primary: true
                            usable: screen.command("view-tab").usable
                            onActivated: Session.runCommand("view-tab")
                        }
                        CommandButton { id: edit; commandId: "edit-tab"; visible: screen.view.tab === "view" && edit.usable; primary: true }
                        ActionButton {
                            objectName: "openRelatedButton"
                            visible: screen.view.tab === "related"
                            text: qsTr("Open")
                            icon: "forward"
                            primary: true
                            usable: screen.relatedPick !== ""
                            onActivated: Session.openEntry("document", screen.relatedPick)
                        }

                        CommandButton { commandId: "insert-image"; visible: screen.view.tab === "edit" && screen.view.kind === "markdown"; showLabel: !screen.narrow }
                        CommandButton {
                            id: discard
                            commandId: "discard-changes"
                            visible: screen.view.tab === "edit"
                            showLabel: !screen.narrow
                            usable: discard.command.usable && screen.dirty
                        }
                        CommandButton {
                            id: save
                            commandId: "save-document"
                            visible: screen.view.tab === "edit"
                            primary: true
                            text: screen.proposing ? qsTr("Update review") : screen.managed ? qsTr("Submit for review") : save.command.title
                            usable: save.command.usable && screen.dirty && !screen.conflicted && !Session.assets.uploading
                        }

                        CommandButton { commandId: "open-review"; visible: screen.view.tab === "reviews" && !screen.inReview; primary: true }

                        CommandButton { commandId: "download-candidate"; visible: screen.inReview; showLabel: !screen.narrow }
                        CommandButton { id: editProposal; commandId: "edit-proposal"; visible: screen.reviewOpen && editProposal.usable; showLabel: !screen.narrow }
                        CommandButton { id: resolve; commandId: "resolve-conflicts"; visible: screen.reviewOpen && resolve.usable }
                        CommandButton { id: updateReview; commandId: "update-review"; visible: screen.reviewOpen && updateReview.usable }
                        BarRule { visible: screen.reviewOpen }
                        CommandButton { commandId: "cancel-review"; visible: screen.reviewOpen; showLabel: !screen.narrow }
                        CommandButton { commandId: "reject-review"; visible: screen.reviewOpen; showLabel: !screen.narrow }
                        CommandButton { commandId: "approve-review"; visible: screen.reviewOpen; primary: true }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.border
                }
            }

            Label {
                objectName: "documentVersion"
                visible: screen.view.version.id !== undefined && !screen.inReview
                text: [qsTr("Version %1").arg(screen.view.version.version_number ?? ""),
                       screen.view.version.published_at ? new Date(screen.view.version.published_at).toLocaleString(Qt.locale(), Locale.ShortFormat) : "",
                       screen.view.latest ? qsTr("Current") : qsTr("Earlier version"),
                       screen.managed ? (screen.control.openReviews > 0
                                         ? qsTr("Managed · %n open review(s)", "", screen.control.openReviews) : qsTr("Managed")) : ""]
                      .filter(function (part) { return part !== "" }).join(" · ")
            }
            Label {
                objectName: "documentError"
                visible: screen.view.errorCode !== ""
                color: Theme.failed
                text: Messages.documentFailure(screen.view.errorCode)
                Accessible.role: Accessible.AlertMessage
            }
            Label {
                visible: screen.control.active && screen.control.errorCode !== ""
                color: Theme.failed
                text: Messages.controlledFailure(screen.control.errorCode)
                Accessible.role: Accessible.AlertMessage
            }
            Label {
                visible: screen.view.notice !== "" || (screen.control.active && screen.control.notice !== "")
                color: Theme.accentText
                text: Messages.documentNotice(screen.view.notice !== "" ? screen.view.notice : screen.control.notice)
            }
            Label { visible: screen.view.busy; text: qsTr("Working…") }

            Page {
                visible: screen.view.tab === "view"
                Layout.fillWidth: true
                Layout.fillHeight: true
                MarkdownView {
                    objectName: "documentPreview"
                    onDocumentRequested: function (id) { Session.openEntry("document", id) }
                    visible: screen.view.kind === "markdown" && screen.view.textLoaded
                    markdown: screen.view.kind === "markdown" ? screen.view.text : ""
                    via: screen.view.version.id ?? ""
                    Accessible.name: screen.view.title
                }
                Image {
                    objectName: "documentImage"
                    visible: screen.view.kind === "image"
                    Layout.maximumWidth: parent.width
                    source: screen.view.kind === "image"
                            ? Session.assets.source(Session.currentOrgId, Session.currentSpaceId, "", screen.view.documentId,
                                                    screen.view.version.id, Math.floor(screen.width)) : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    Accessible.role: Accessible.Graphic
                    Accessible.name: screen.view.title
                }
                TextEdit {
                    objectName: "documentText"
                    visible: screen.view.kind === "text" && screen.view.textLoaded
                    Layout.fillWidth: true
                    readOnly: true
                    selectByMouse: true
                    selectByKeyboard: true
                    activeFocusOnTab: true
                    wrapMode: TextEdit.WrapAnywhere
                    textFormat: TextEdit.PlainText
                    text: screen.view.kind === "text" ? screen.view.text : ""
                    font: Theme.mono
                    color: Theme.textPrimary
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.textPrimary
                    Accessible.name: screen.view.title
                }
                Label {
                    objectName: "noVersion"
                    visible: !screen.view.busy && screen.view.version.id === undefined && screen.view.errorCode === ""
                    text: qsTr("This document has no published version yet. It appears here once its upload finishes.")
                }
                Label {
                    objectName: "previewUnsupported"
                    visible: screen.view.kind === "none" && !screen.view.busy && screen.view.version.id !== undefined
                    text: qsTr("There is no preview for this type of file. Download it to open it on your device.")
                }
            }

            Page {
                visible: screen.view.tab === "edit"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label {
                    objectName: "proposalNotice"
                    visible: screen.proposing
                    color: Theme.accentText
                    text: qsTr("You are editing the proposal of your review “%1”. Saving updates that review; discarding leaves it as it is.")
                          .arg(screen.proposalReason)
                }
                Label {
                    objectName: "conflictNotice"
                    visible: screen.conflicted
                    color: Theme.failed
                    text: qsTr("Resolve each conflict before saving: keep the text you want between <<<<<<< published and >>>>>>> review, then delete the three marker lines.")
                    Accessible.role: Accessible.AlertMessage
                }
                Label {
                    text: screen.managed && !screen.proposing
                          ? qsTr("Saving opens a new review of your changes. Other open reviews stay as they are.")
                          : screen.view.kind === "markdown"
                            ? qsTr("Paste or drop images to store them in the space's assets folder. Type @ or / to link a file, # at a line's start for actions.")
                            : qsTr("Saving publishes the edited text as the document's next version.")
                }
                Label {
                    visible: editor.assetError !== ""
                    color: Theme.failed
                    text: Messages.assetFailure(editor.assetError)
                    Accessible.role: Accessible.AlertMessage
                }
                RowLayout {
                    visible: screen.view.kind === "markdown"
                    spacing: Theme.gapXs
                    Accessible.role: Accessible.PageTabList
                    ViewTab { view: "write"; current: screen.draftView; text: qsTr("Write"); icon: "rename"; onPicked: function (view) { screen.draftView = view } }
                    ViewTab { view: "preview"; current: screen.draftView; text: qsTr("Preview"); icon: "document"; onPicked: function (view) { screen.draftView = view } }
                }
                MarkdownView {
                    objectName: "draftPreview"
                    opensLinks: false
                    visible: screen.view.kind === "markdown" && screen.draftView === "preview"
                    markdown: visible ? editor.text : ""
                    via: screen.view.version.id ?? ""
                    Accessible.name: qsTr("Preview")
                }
                MarkdownEditor {
                    id: editor
                    objectName: "documentEditor"
                    visible: screen.view.kind !== "markdown" || screen.draftView === "write"
                    images: screen.view.kind === "markdown"
                    documentId: screen.view.documentId
                    folderId: screen.view.document.folder_id ?? ""
                    pinLinks: screen.control.pinsLinks
                    font: screen.view.kind === "text" ? Theme.mono : Theme.body
                    placeholderText: screen.view.title
                    Accessible.name: screen.view.title
                    enabled: !screen.view.busy && screen.view.editable
                    onDraftDropped: function (file) {
                        const text = screen.view.readDraft(file)
                        if (text !== "")
                            editor.text = text
                    }
                }
            }

            Page {
                visible: screen.view.tab === "versions"
                Layout.fillWidth: true
                Layout.fillHeight: true
                CursorList {
                    id: versions
                    objectName: "versionList"
                    Layout.fillWidth: true
                    Layout.preferredHeight: versions.contentHeight
                    interactive: false
                    activeFocusOnTab: true
                    spacing: Theme.gapS
                    rowHeight: screen.touch ? Theme.rowTouch : Theme.controlM
                    model: screen.view.versions
                    Accessible.role: Accessible.List
                    Accessible.name: qsTr("Versions")
                    delegate: ListRow {
                        id: row
                        required property var modelData
                        required property int index
                        objectName: "version_" + row.modelData.version_number
                        view: versions
                        touch: screen.touch
                        cursor: versions.currentIndex === row.index
                        selected: screen.view.version.id === row.modelData.id
                        title: qsTr("Version %1").arg(row.modelData.version_number) + (row.modelData.current ? " · " + qsTr("Current") : "")
                        detail: [row.modelData.published_at ? new Date(row.modelData.published_at).toLocaleString(Qt.locale(), Locale.ShortFormat) : "",
                                 row.modelData.filename ?? "", Messages.usageAmount(row.modelData.byte_size, "storage_bytes")]
                                .filter(function (part) { return part !== "" }).join(" · ")
                        onClicked: {
                            versions.currentIndex = row.index
                            screen.view.selectVersion(row.modelData.id)
                        }
                        onActivated: {
                            screen.view.selectVersion(row.modelData.id)
                            Session.runCommand("view-tab")
                        }
                    }
                }
            }

            Page {
                objectName: "relatedPage"
                visible: screen.view.tab === "related"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.gapL
                EmptyState {
                    objectName: "relatedEmpty"
                    visible: screen.unrelated
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.gapXl
                    text: qsTr("No other document links this one, and it links none.")
                }
                Repeater {
                    model: ["incoming", "outgoing"]
                    delegate: ColumnLayout {
                        id: side
                        required property string modelData
                        readonly property bool incoming: side.modelData === "incoming"
                        readonly property var rows: (side.incoming ? screen.view.incoming : screen.view.outgoing)
                                                    .map(function (item) { return screen.relatedRow(item, side.incoming) })
                        visible: screen.view.relatedLoaded && !screen.unrelated
                        Layout.fillWidth: true
                        spacing: Theme.gapM
                        SectionHead {
                            title: side.incoming ? qsTr("Linked from") : qsTr("Links to")
                            ActionButton {
                                objectName: side.modelData + "MoreButton"
                                visible: side.incoming ? screen.view.incomingMore : screen.view.outgoingMore
                                text: qsTr("Show more")
                                icon: "new"
                                usable: !screen.view.busy
                                onActivated: screen.view.loadMoreRelated(side.modelData)
                            }
                        }
                        Label {
                            visible: side.rows.length === 0
                            text: side.incoming ? qsTr("No document you can open links this one.")
                                                : qsTr("The current version links no files.")
                        }
                        CursorList {
                            id: related
                            objectName: side.modelData + "List"
                            Layout.fillWidth: true
                            Layout.preferredHeight: related.contentHeight
                            interactive: false
                            activeFocusOnTab: true
                            spacing: Theme.gapS
                            rowHeight: screen.touch ? Theme.rowTouch : Theme.controlM
                            model: side.rows
                            Accessible.role: Accessible.List
                            Accessible.name: side.incoming ? qsTr("Linked from") : qsTr("Links to")
                            onMoved: screen.relatedPick = side.rows[related.currentIndex]?.id ?? ""
                            delegate: ListRow {
                                id: link
                                required property var modelData
                                required property int index
                                objectName: side.modelData + "_" + link.index
                                view: related
                                touch: screen.touch
                                cursor: related.currentIndex === link.index
                                selected: link.modelData.openable && screen.relatedPick === link.modelData.id
                                opacity: link.modelData.openable ? 1 : 0.6
                                title: link.modelData.title
                                detail: link.modelData.detail
                                onClicked: {
                                    related.currentIndex = link.index
                                    screen.relatedPick = link.modelData.id
                                }
                                onActivated: if (link.modelData.openable)
                                    Session.openEntry("document", link.modelData.id)
                            }
                        }
                        Label {
                            objectName: "relatedHidden"
                            visible: side.incoming && screen.view.hiddenCount > 0
                            text: qsTr("%n more document(s) you cannot open link this one.", "", screen.view.hiddenCount)
                        }
                    }
                }
            }

            Page {
                visible: screen.view.tab === "reviews" && !screen.inReview
                Layout.fillWidth: true
                Layout.fillHeight: true
                ReviewList {
                    id: reviewList
                    Layout.fillWidth: true
                    touch: screen.touch
                }
            }
            Page {
                visible: screen.inReview
                Layout.fillWidth: true
                Layout.fillHeight: true
                ReviewPage { Layout.fillWidth: true }
            }
        }
    }

    Confirm {
        id: confirmation
        objectName: "documentConfirm"
        anchors.fill: parent
        onAccepted: {
            if (screen.pendingAction === "save")
                screen.view.save(editor.text, confirmation.reason, !screen.control.pinsLinks, screen.control.proposal())
            else if (screen.pendingAction === "discard") {
                editor.text = screen.view.text
                screen.control.clearProposal()
            }
            else if (screen.pendingAction === "close") screen.view.close()
            else if (screen.pendingAction === "unmanage") screen.control.setControlled(false, confirmation.reason)
            else screen.control.decide(screen.pendingAction, confirmation.reason)
        }
        onVisibleChanged: if (!visible && screen.visible) screen.focusDefault()
    }
}
