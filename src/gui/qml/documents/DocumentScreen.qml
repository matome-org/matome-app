pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import matome
import "../chrome"
import "../controlled_docs"
import "../screens"
import "../chrome/Messages.js" as Messages
import "../chrome/Commands.js" as Commands

// Any document of the open space, opened from the explorer, on a detail
// page: the way back to its folder, its name and state, one command bar,
// and the tabs Preview, Versions, Related, and, while it is managed with
// reviews, Reviews. Editing a Markdown or text document is a mode of its
// own that takes the screen; leaving it with changes asks first. Its switch
// shows the text (Write), the rendered draft (Preview), or both side by
// side, scrolled together by source line (Split). Every verb
// is a row of Session.commandList, so its button, key, and sheet entry
// agree. The controlled-documents add-on, when it applies, adds its Reviews
// tab and turns a save into a proposed change; a review opened from it
// takes the whole screen, one level below the document. Two versions
// compared from the Versions tab take it the same way. Nothing here
// depends on the add-on being there.
FocusScope {
    id: screen

    // Asks the window to open what fixes a refusal (Permissions' `explain`).
    signal fixRequested(var answer)

    readonly property var view: Session.documentView
    readonly property var control: Session.controlledDocs
    readonly property bool editing: view.editing
    readonly property bool managed: control.active && control.controlled
    readonly property bool inReview: control.active && control.review.id !== undefined
    // The opened review still awaits a decision.
    readonly property bool comparing: view.comparison.from !== undefined
    readonly property bool narrow: screen.width < 600
    readonly property bool touch: screen.narrow || Qt.platform.os === "android"
    // The editor holds the proposal of one of the author's reviews.
    readonly property bool proposing: control.active && control.proposalReviewId !== ""
    readonly property string proposalReason: control.reviews.find(function (review) {
        return review.id === control.proposalReviewId })?.reason ?? ""
    // Core's conflict markers are still in the proposal.
    readonly property bool conflicted: screen.proposing && /^(<<<<<<< published|>>>>>>> review)$/m.test(editor.text)
    readonly property bool dirty: screen.editing && (editor.text !== view.text || screen.proposing)
    // The document's open reviews, the one Open review opens first.
    readonly property var openReviews: control.active ? control.reviews.filter(function (review) { return review.status === "open" }) : []
    // Manage with reviews in this space, as the space's catalog judges it.
    readonly property var manageAnswer: Session.permissions.revision >= 0
                                        ? Session.permissions.explain("addon.controlled_docs.document_manage", Session.currentSpaceId) : ({})
    // Managing applies to Markdown where Core offers the add-on, or to a
    // document already managed.
    readonly property bool manageable: screen.managed || (screen.view.kind === "markdown" && screen.manageAnswer.listed === true)
    // One table row per document linked from or linking this one.
    readonly property var relatedRows: view.incoming.map(function (item, index) { return screen.relatedRow(item, true, index) })
                                       .concat(view.outgoing.map(function (item, index) { return screen.relatedRow(item, false, index) }))
    // What the editor shows: "write", "preview", or "split".
    property string editMode: "write"
    // Split shows both sides only where they fit.
    readonly property bool splitting: screen.editMode === "split" && !screen.narrow
    // The text the draft preview renders, a moment behind the editor's.
    property string draftText
    // The preview, not the editor, drives the scrolling of both.
    readonly property bool previewLeads: draftHover.hovered || draft.list.activeFocus
    // What the side panel asks before: "propose", "update", or "leave" (a
    // save of the editor, or leaving it), a review decision ("approve",
    // "reject", "cancel"), or "unmanage".
    property string pendingAction
    // What follows once the editor is left: "close" closes the document.
    property string leaving

    function command(id) { return Commands.find(Session.commandList, id) }
    // Why Core refused `action` here with `code`, from the space's catalog
    // when it explains it.
    function refusal(code, action) {
        return Messages.refused(code, Session.permissions.revision >= 0 ? Session.permissions.explain(action, Session.currentSpaceId) : ({}),
                                Messages.controlledFailure)
    }
    function personName(id) {
        const key = String(id ?? "")
        const member = key === "" ? null
                     : Session.accessDirectory.members.find(function (person) { return person.id === key })
                       ?? screen.control.members.find(function (person) { return String(person.id) === key })
        return member?.label ?? ""
    }
    function when(time) {
        return time ? new Date(time).toLocaleString(Qt.locale(), Locale.ShortFormat) : ""
    }
    // One row of the Related tab from Core's incoming or outgoing reference.
    function relatedRow(item, incoming, index) {
        if (incoming)
            return { key: "in" + index, id: String(item.item_id), title: item.name ?? "", openable: true,
                     direction: qsTr("Linked from"), state: (item.modes ?? []).indexOf("path") >= 0 ? qsTr("By path") : "" }
        const target = item.target ?? {}
        const ok = target.state === "ok"
        return { key: "out" + index, id: ok ? String(target.item_id) : "", openable: ok,
                 title: target.name ?? item.path ?? qsTr("Unavailable file"), direction: qsTr("Links to"),
                 state: [Messages.referenceState(target.state),
                         item.mode === "version" ? qsTr("Pinned version") : item.mode === "path" ? qsTr("By path") : ""]
                        .filter(function (part) { return part !== "" }).join(" · ") }
    }
    function openVersion(version) {
        screen.view.selectVersion(version.id)
        Session.runCommand("view-tab")
    }
    function dismiss() {
        if (panel.shown) panel.dismiss()
        else if (screen.comparing) screen.view.stopComparing()
        else if (screen.inReview) Session.runCommand("close-review")
        else if (screen.editing) screen.leaveEditor("")
        else screen.view.close()
    }
    // Leaves the editor, asking first while it holds changes; `then` is
    // what follows ("close").
    function leaveEditor(then) {
        screen.leaving = then
        if (screen.dirty)
            screen.ask("leave")
        else
            screen.finishLeaving()
    }
    function finishLeaving() {
        screen.view.stopEditing()
        screen.control.clearProposal()
        if (screen.leaving === "close")
            screen.view.close()
        screen.leaving = ""
    }
    // A plain document saves at once; a managed one proposes the change.
    function save() {
        if (!screen.dirty || screen.conflicted)
            return
        if (screen.proposing)
            screen.ask("update")
        else if (screen.managed)
            screen.ask("propose")
        else
            screen.view.save(editor.text, "", !screen.control.pinsLinks, screen.control.proposal())
    }
    function setMode(mode) {
        if (mode === "split" && screen.narrow)
            return
        redraft.stop()
        screen.draftText = editor.text
        screen.editMode = mode
        if (mode === "preview")
            draft.list.forceActiveFocus()
        else
            editor.forceActiveFocus()
        if (screen.splitting)
            Qt.callLater(screen.followEditor)
    }
    // A segment of the editor's mode switch from command `id`, unusable
    // with `reason` too.
    function modeOption(id, reason) {
        const command = screen.command(id)
        return { value: id.slice(0, -5), text: command.title, icon: command.icon, key: Commands.keys(command)[0] ?? "",
                 usable: command.usable && reason === "", reason: reason }
    }
    // The source line at the top of the editor, a fraction down it.
    function editorLine(): real {
        const text = editor.text
        const top = editorPage.contentY - editor.y
        const at = editor.positionAt(editor.leftPadding, Math.max(editor.topPadding, top))
        const start = text.lastIndexOf("\n", at - 1) + 1
        const next = text.indexOf("\n", at)
        const from = editor.positionToRectangle(start)
        const to = editor.positionToRectangle(next < 0 ? text.length : next)
        const share = (top - from.y) / Math.max(1, to.y + to.height - from.y)
        return text.slice(0, start).split("\n").length + Math.max(0, Math.min(1, share))
    }
    // Scrolls the editor to source line `line`, a fraction down it.
    function showEditorLine(line: real) {
        const text = editor.text
        let start = 0
        for (let at = 1; at < Math.floor(line); ++at) {
            const next = text.indexOf("\n", start)
            if (next < 0)
                break
            start = next + 1
        }
        const next = text.indexOf("\n", start)
        const from = editor.positionToRectangle(start)
        const to = editor.positionToRectangle(next < 0 ? text.length : next)
        const y = editor.y + from.y + (line - Math.floor(line)) * (to.y + to.height - from.y)
        editorPage.contentY = Math.max(0, Math.min(Math.max(0, editorPage.contentHeight - editorPage.height), y))
    }
    function followEditor() {
        if (screen.splitting)
            draft.showLine(screen.editorLine())
    }
    function ask(action) {
        screen.pendingAction = action
        panel.show(askPanel, screen.Window.activeFocusItem)
    }
    // The verbs the document screen and the add-on hand back to it.
    function perform(id) {
        if (id === "save-document") screen.save()
        else if (id === "discard-changes") screen.leaveEditor("")
        else if (id === "insert-image") Session.assets.pickImages()
        else if (id.endsWith("-mode")) screen.setMode(id.slice(0, -5))
        else if (id === "approve-review") screen.ask("approve")
        else if (id === "reject-review") screen.ask("reject")
        else if (id === "cancel-review") screen.ask("cancel")
        else if (id === "unmanage-document") screen.ask("unmanage")
    }
    function focusDefault() {
        if (screen.editing)
            editor.forceActiveFocus()
        else if (screen.comparing)
            comparePage.backButton.forceActiveFocus()
        else if (screen.inReview)
            reviewPage.backButton.forceActiveFocus()
        else if (preview.visible)
            preview.list.forceActiveFocus()
        else
            page.backButton.forceActiveFocus()
    }

    // Going into a review or back out of it keeps the keyboard where it went.
    onInReviewChanged: if (screen.visible) {
        if (screen.inReview) screen.focusDefault()
        else reviews.focusList()
    }
    onComparingChanged: if (screen.visible) {
        if (screen.comparing) screen.focusDefault()
        else versions.focusKey(versions.cursorKey)
    }
    // The editor opens on the published text, or on a proposal handed to it.
    onEditingChanged: {
        screen.editMode = "write"
        if (screen.editing && !screen.proposing)
            editor.text = screen.view.text
        if (screen.visible)
            Qt.callLater(screen.focusDefault)
    }
    // Back from Settings, the space may require reviews now.
    // The roles a refusal names come from the organization's directory.
    onVisibleChanged: if (visible) {
        screen.control.refresh()
        if (!Session.accessDirectory.active) Session.accessDirectory.open()
        focusDefault()
    } else {
        panel.close()
    }

    Connections {
        target: Session.documentView
        function onRequested(id) { screen.perform(id) }
        function onSaved() {
            if (screen.view.notice === "review_requested" || screen.view.notice === "review_updated")
                screen.view.tab = "reviews"
            if (screen.leaving === "close")
                screen.view.close()
            screen.leaving = ""
        }
        function onChanged() {
            if (page.current !== screen.view.tab && screen.view.tab !== "")
                page.current = screen.view.tab
            if (screen.view.errorIndex < 0 || !screen.editing)
                return
            const at = Session.assets.referenceAt(editor.text, screen.view.errorIndex, !screen.control.pinsLinks)
            if (at.start !== undefined) {
                if (screen.editMode === "preview")
                    screen.setMode("write")
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
            Session.runCommand("edit-document")
            const at = conflicts > 0 ? text.search(/^<<<<<<< published$/m) : -1
            editor.cursorPosition = Math.max(0, at)
            if (at >= 0)
                editor.select(at, at + "<<<<<<< published".length)
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

    DetailPage {
        id: page
        objectName: "documentPage"
        visible: !screen.editing && !screen.inReview && !screen.comparing
        anchors.fill: parent
        anchors.margins: screen.narrow ? Theme.gapM : Theme.gapXl
        anchors.rightMargin: panel.reserve + (screen.narrow ? Theme.gapM : Theme.gapXl)
        name: "document"
        narrow: screen.narrow
        backText: screen.view.place.join(" › ")
        title: screen.view.title
        chips: [screen.view.version.id === undefined ? ""
                : screen.view.latest ? qsTr("Version %1").arg(screen.view.version.version_number)
                : qsTr("Version %1").arg(screen.view.version.version_number) + " · " + qsTr("Earlier version"),
                screen.managed ? qsTr("Managed") : "",
                screen.openReviews.length > 0 ? qsTr("Review open") : ""].filter(function (chip) { return chip !== "" })
        subject: screen.view.documentId
        start: "view"
        onBackRequested: screen.dismiss()
        onCurrentChanged: if (page.current !== "" && page.current !== screen.view.tab && screen.view.active) {
            Session.runCommand(page.current + "-tab")
            page.current = screen.view.tab
        }

        notes: [
            Label {
                objectName: "reviewState"
                visible: screen.openReviews.length > 0
                color: Theme.accentText
                text: qsTr("%n review(s) open · %1/%2 approvals", "", screen.openReviews.length)
                      .arg(screen.openReviews[0]?.approvals?.length ?? 0)
                      .arg(Math.max(1, screen.openReviews[0]?.settings?.required_approvals ?? 1))
            },
            Standing {}
        ]

        commands: [
            CommandButton {
                commandId: "edit-document"
                primary: true
                showLabel: !page.compact
                reason: screen.view.kind !== "markdown" && screen.view.kind !== "text" ? qsTr("Only Markdown and text documents are edited here.")
                      : !screen.view.latest ? qsTr("Only the current version is edited.") : ""
            },
            CommandButton { commandId: "download-version"; showLabel: !page.compact },
            ActionButton {
                id: details
                objectName: "documentDetailsButton"
                text: qsTr("Details")
                icon: "info"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                onActivated: panel.show(detailsPanel, details)
            },
            BarRule { visible: manage.visible },
            CommandButton {
                id: manage
                commandId: "manage-document"
                visible: screen.manageable
                showLabel: !page.compact
                reason: screen.managed ? qsTr("It is managed with reviews already.") : Messages.refusal(screen.manageAnswer)
            },
            ActionButton {
                objectName: "manageFixButton"
                visible: manage.visible && !screen.managed && screen.manageAnswer.canFix === true
                text: Messages.fixName(screen.manageAnswer.fix ?? "")
                icon: "settings"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                onActivated: screen.fixRequested(screen.manageAnswer)
            },
            CommandButton {
                commandId: "unmanage-document"
                visible: manage.visible
                showLabel: !page.compact
                reason: screen.managed ? "" : qsTr("It is not managed with reviews.")
            },
            CommandButton {
                commandId: "open-review"
                visible: screen.managed && page.current !== "reviews"
                showLabel: !page.compact
                reason: qsTr("No review is open.")
            }
        ]

        DetailTab {
            view: "view"
            title: qsTr("Preview")

            MarkdownView {
                id: preview
                objectName: "documentPreview"
                visible: screen.view.kind === "markdown" && screen.view.textLoaded
                Layout.fillWidth: true
                Layout.fillHeight: true
                markdown: screen.view.kind === "markdown" ? screen.view.text : ""
                via: screen.view.version.id ?? ""
                touch: screen.touch
                Accessible.name: screen.view.title
                onDocumentRequested: function (id) { Session.openEntry("document", id) }
            }
            Page {
                visible: !preview.visible
                Layout.fillWidth: true
                Layout.fillHeight: true
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
        }

        DetailTab {
            view: "versions"
            title: qsTr("Versions")

            commands: [
                ActionButton {
                    objectName: "versionOpenButton"
                    text: qsTr("Open")
                    icon: "forward"
                    showLabel: !page.compact
                    tip: page.compact ? text : ""
                    usable: versions.selectedRow !== null && !screen.view.busy
                    reason: qsTr("Select one row.")
                    onActivated: screen.openVersion(versions.selectedRow)
                },
                ActionButton {
                    objectName: "versionCompareButton"
                    readonly property var picked: versions.selectedRows
                    text: qsTr("Compare")
                    icon: "diff"
                    showLabel: !page.compact
                    tip: page.compact ? text : ""
                    usable: !screen.view.busy && screen.view.kind !== "none"
                            && (picked.length === 2 || (picked.length === 1 && picked[0].current !== true))
                    reason: screen.view.kind === "none" ? qsTr("Only text documents are compared.")
                          : picked.length === 1 ? qsTr("Select an earlier version, or two versions.")
                          : qsTr("Select one version to compare with the current one, or two versions.")
                    onActivated: screen.view.compare(picked[0].id, picked.length === 2 ? picked[1].id : "")
                }
            ]

            Page {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Table {
                    id: versions
                    objectName: "versionTable"
                    prefix: "version_"
                    label: qsTr("Versions")
                    touch: screen.touch
                    multiSelect: true
                    columns: [{ title: qsTr("Version"), share: 2 }, { title: qsTr("Date"), share: 2 }, { title: qsTr("Author"), share: 3 }]
                    model: screen.view.versions
                    cells: function (version) {
                        return [qsTr("Version %1").arg(version.version_number) + (version.current ? " · " + qsTr("Current") : ""),
                                screen.when(version.published_at), screen.personName(version.published_by_membership_id)]
                    }
                    onOpened: function (version) { screen.openVersion(version) }
                }
            }
        }

        DetailTab {
            view: "related"
            title: qsTr("Related")

            commands: [
                ActionButton {
                    objectName: "relatedOpenButton"
                    text: qsTr("Open")
                    icon: "forward"
                    showLabel: !page.compact
                    tip: page.compact ? text : ""
                    usable: related.selectedRow?.openable === true
                    reason: related.selectedRow ? Messages.referenceState("forbidden") : qsTr("Select one row.")
                    onActivated: Session.openEntry("document", related.selectedRow.id)
                },
                ActionButton {
                    objectName: "relatedMoreButton"
                    visible: screen.view.incomingMore || screen.view.outgoingMore
                    text: qsTr("Show more")
                    icon: "new"
                    showLabel: !page.compact
                    tip: page.compact ? text : ""
                    usable: !screen.view.busy
                    onActivated: screen.view.loadMoreRelated(screen.view.incomingMore ? "incoming" : "outgoing")
                }
            ]

            Page {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Table {
                    id: related
                    objectName: "relatedTable"
                    prefix: "related_"
                    label: qsTr("Related")
                    touch: screen.touch
                    columns: [{ title: qsTr("Document"), share: 4 }, { title: qsTr("Direction"), share: 2 }, { title: qsTr("State"), share: 3 }]
                    model: screen.relatedRows
                    keyOf: function (row) { return row.key }
                    cells: function (row) { return [row.title, row.direction, row.state] }
                    emptyText: screen.view.relatedLoaded && screen.view.hiddenCount === 0 ? qsTr("No other document links this one, and it links none.") : ""
                    onOpened: function (row) { if (row.openable) Session.openEntry("document", row.id) }
                }
                Label {
                    objectName: "relatedHidden"
                    visible: screen.view.hiddenCount > 0
                    text: qsTr("%n more document(s) you cannot open link this one.", "", screen.view.hiddenCount)
                }
            }
        }

        ReviewList {
            id: reviews
            touch: screen.touch
        }
    }

    DetailPage {
        id: editPage
        objectName: "editPage"
        visible: screen.editing
        anchors.fill: page
        name: "edit"
        narrow: screen.narrow
        backText: qsTr("Back to preview")
        title: screen.view.title
        onBackRequested: screen.leaveEditor("")

        notes: [
            Label {
                objectName: "proposalNotice"
                visible: screen.proposing
                color: Theme.accentText
                text: qsTr("You are editing the proposal of your review “%1”. Saving updates that review; discarding leaves it as it is.")
                      .arg(screen.proposalReason)
            },
            Label {
                objectName: "conflictNotice"
                visible: screen.conflicted
                color: Theme.failed
                text: qsTr("Resolve each conflict before saving: keep the text you want between <<<<<<< published and >>>>>>> review, then delete the three marker lines.")
                Accessible.role: Accessible.AlertMessage
            },
            Label {
                visible: editor.assetError !== ""
                color: Theme.failed
                text: Messages.assetFailure(editor.assetError)
                Accessible.role: Accessible.AlertMessage
            },
            Standing {}
        ]

        commands: [
            SegmentedSwitch {
                objectName: "editMode"
                readonly property string unrendered: screen.view.kind === "markdown" ? "" : qsTr("Only Markdown documents are rendered.")
                options: [screen.modeOption("write-mode", ""), screen.modeOption("preview-mode", unrendered),
                          screen.modeOption("split-mode", unrendered !== "" ? unrendered : screen.narrow ? qsTr("Split needs a wider window.") : "")]
                current: screen.editMode
                showLabel: !editPage.compact
                Accessible.name: qsTr("Mode")
                onPicked: function (value) { Session.runCommand(value + "-mode") }
            },
            BarRule {},
            CommandButton {
                id: insertImage
                commandId: "insert-image"
                showLabel: !editPage.compact
                usable: insertImage.command.usable && screen.editMode !== "preview"
                reason: screen.view.kind !== "markdown" ? qsTr("Only Markdown documents take images.")
                      : screen.editMode === "preview" ? qsTr("Go back to the text to insert an image.") : ""
            },
            CommandButton {
                commandId: "discard-changes"
                text: qsTr("Discard")
                showLabel: !editPage.compact
            },
            CommandButton {
                id: save
                commandId: "save-document"
                primary: true
                text: screen.proposing ? qsTr("Update review") : screen.managed ? qsTr("Propose change") : save.command.title
                usable: save.command.usable && screen.dirty && !screen.conflicted && !Session.assets.uploading
                reason: !screen.dirty ? qsTr("Nothing has changed.")
                      : screen.conflicted ? qsTr("Resolve its conflicts first.")
                      : Session.assets.uploading ? qsTr("Images are still uploading.") : ""
            }
        ]

        // The text in the reading column, or in the left half beside the
        // draft preview.
        Item {
            id: editBody
            readonly property real half: (editBody.width - Theme.gapL) / 2
            Layout.fillWidth: true
            Layout.fillHeight: true

            Page {
                id: editorPage
                visible: screen.editMode !== "preview"
                width: screen.splitting ? editBody.half : editBody.width
                height: editBody.height
                onContentYChanged: if (!screen.previewLeads) screen.followEditor()
                MarkdownEditor {
                    id: editor
                    objectName: "documentEditor"
                    Layout.maximumWidth: screen.splitting ? Number.POSITIVE_INFINITY : Theme.reading + 2 * editor.leftPadding
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: Math.max(editorPage.height, editor.implicitHeight)
                    images: screen.view.kind === "markdown"
                    documentId: screen.view.documentId
                    folderId: screen.view.document.parent_id ?? ""
                    pinLinks: screen.control.pinsLinks
                    placeholderText: screen.view.kind === "markdown"
                                     ? qsTr("Paste or drop images to store them in the space's assets folder. Type @ or / to link a file, # at a line's start for actions.")
                                     : screen.view.title
                    Accessible.name: screen.view.title
                    enabled: !screen.view.busy && screen.view.editable
                    onTextChanged: if (screen.editMode !== "write") redraft.restart()
                    onDraftDropped: function (file) {
                        const text = screen.view.readDraft(file)
                        if (text !== "")
                            editor.text = text
                    }
                }
            }
            Rectangle {
                visible: screen.splitting
                x: editBody.half + Theme.gapL / 2
                width: 1
                height: editBody.height
                color: Theme.border
            }
            MarkdownView {
                id: draft
                objectName: "draftPreview"
                visible: screen.editMode === "preview" || screen.splitting
                x: screen.splitting ? editBody.half + Theme.gapL : 0
                width: screen.splitting ? editBody.half : editBody.width
                height: editBody.height
                opensLinks: false
                markdown: draft.visible ? screen.draftText : ""
                via: screen.view.version.id ?? ""
                touch: screen.touch
                Accessible.name: qsTr("Preview")

                HoverHandler { id: draftHover }
            }
            Connections {
                target: draft.list
                function onContentYChanged() {
                    if (screen.splitting && screen.previewLeads)
                        screen.showEditorLine(draft.topLine())
                }
            }
            // The draft preview follows the text a moment after typing stops.
            Timer {
                id: redraft
                interval: 250
                onTriggered: {
                    screen.draftText = editor.text
                    Qt.callLater(screen.followEditor)
                }
            }
        }
    }

    ReviewPage {
        id: reviewPage
        objectName: "reviewPage"
        visible: screen.inReview && !screen.editing
        anchors.fill: page
        narrow: screen.narrow
        touch: screen.touch
    }

    DetailPage {
        id: comparePage
        objectName: "comparePage"
        visible: screen.comparing
        anchors.fill: page
        name: "compare"
        narrow: screen.narrow
        backText: screen.view.title
        title: qsTr("Version %1 → version %2").arg(screen.view.comparison.from?.version_number ?? "")
                                               .arg(screen.view.comparison.to?.version_number ?? "")
        subject: (screen.view.comparison.from?.id ?? "") + (screen.view.comparison.to?.id ?? "")
        start: "changes"
        onBackRequested: screen.view.stopComparing()
        Keys.onPressed: function (event) { event.accepted = compareChanges.handleKey(event) }

        notes: [
            Standing {}
        ]

        ChangesTab {
            id: compareChanges
            name: "compare"
            before: screen.view.comparison.before ?? ""
            after: screen.view.comparison.after ?? ""
            beforeVia: screen.view.comparison.from?.id ?? ""
            afterVia: screen.view.comparison.to?.id ?? ""
            loaded: screen.view.comparison.loaded === true
            touch: screen.touch
        }
    }

    PanelHost {
        id: panel
        anchors.fill: parent
        narrow: screen.narrow
        onClosed: if (screen.visible && !(panel.returnTo && panel.returnTo.visible)) screen.focusDefault()
    }
    Component {
        id: detailsPanel
        PanelBody {
            objectName: "documentDetailsPanel"
            title: qsTr("Details")
            subtitle: screen.view.title
            cancelText: qsTr("Close")
            Facts {
                facts: [{ name: "documentAuthor", label: qsTr("Author"),
                          value: screen.personName(screen.view.versions[screen.view.versions.length - 1]?.published_by_membership_id) },
                        { name: "documentVersions", label: qsTr("Versions"), value: String(screen.view.versions.length) },
                        { name: "documentTags", label: qsTr("Tags"),
                          value: (screen.view.document.document?.tag_assignments ?? []).map(function (tag) { return tag.name }).join(", ") },
                        { name: "documentPath", label: qsTr("Path"), value: screen.view.place.concat([screen.view.title]).join(" › ") }]
            }
        }
    }
    Component {
        id: askPanel
        ConfirmPanel {
            id: asking
            readonly property string action: screen.pendingAction
            readonly property bool saving: ["propose", "update", "leave"].includes(asking.action)
            // What a save proposes: a change to review, or a review's update.
            readonly property string proposal: asking.action === "update" || (asking.action === "leave" && screen.proposing) ? "update"
                                             : asking.action === "propose" || (asking.action === "leave" && screen.managed) ? "propose" : ""
            objectName: "documentAskPanel"
            title: asking.action === "propose" ? qsTr("Propose change")
                   : asking.action === "update" ? qsTr("Update this review?")
                   : asking.action === "leave" ? qsTr("Unsaved changes")
                   : asking.action === "approve" ? qsTr("Approve this proposal?")
                   : asking.action === "reject" ? qsTr("Reject this proposal?")
                   : asking.action === "cancel" ? qsTr("Cancel this review?")
                   : qsTr("Stop managing this document?")
            detail: asking.action === "approve" ? qsTr("Once enough reviewers approve it, the proposal shown in this review becomes the published version.")
                    : asking.action === "unmanage" ? qsTr("Open reviews will be cancelled. New versions will no longer wait for approval.")
                    : asking.action === "reject" || asking.action === "cancel" ? qsTr("The published version will remain unchanged.") : ""
            reasonLabel: asking.proposal === "update" ? qsTr("What changed")
                         : asking.proposal === "propose" ? qsTr("Comment")
                         : asking.action === "approve" || asking.action === "reject" ? qsTr("Decision comment (optional)")
                         : asking.action === "unmanage" ? qsTr("Reason for no longer managing it") : ""
            reasonRequired: asking.action !== "approve" && asking.action !== "reject"
            reasonLength: asking.action === "approve" || asking.action === "reject" ? 2000 : 500
            saveText: asking.proposal === "update" ? qsTr("Update review")
                      : asking.proposal === "propose" ? qsTr("Propose change")
                      : asking.saving ? qsTr("Save")
                      : asking.action === "approve" ? qsTr("Approve")
                      : asking.action === "reject" ? qsTr("Reject")
                      : asking.action === "cancel" ? qsTr("Cancel review") : qsTr("Stop managing")
            otherText: asking.action === "leave" ? qsTr("Discard") : ""
            cancelText: asking.action === "leave" ? qsTr("Continue editing") : qsTr("Cancel")
            busy: asking.saving ? screen.view.busy : screen.control.busy
            failure: asking.saving ? screen.refusal(screen.view.errorCode, "document.new_version")
                     : asking.action === "unmanage" ? screen.refusal(screen.control.errorCode, "addon.controlled_docs.document_manage")
                     : asking.action === "approve" || asking.action === "reject"
                       ? screen.refusal(screen.control.errorCode, "addon.controlled_docs.approve")
                     : Messages.controlledFailure(screen.control.errorCode)
            onConfirmed: {
                if (asking.saving)
                    screen.view.save(editor.text, asking.reason, !screen.control.pinsLinks, screen.control.proposal())
                else if (asking.action === "unmanage")
                    screen.control.setControlled(false, asking.reason)
                else
                    screen.control.decide(asking.action, asking.reason)
            }
            onOtherRequested: {
                asking.finished()
                screen.finishLeaving()
            }
        }
    }

    // How the document stands: what failed, what was saved, what is under way.
    component Standing: ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.gapXs
        Label {
            objectName: "documentError"
            visible: screen.view.errorCode !== ""
            color: Theme.failed
            text: screen.refusal(screen.view.errorCode, "document.new_version")
            Accessible.role: Accessible.AlertMessage
        }
        Label {
            objectName: "controlError"
            visible: screen.control.active && screen.control.errorCode !== ""
            color: Theme.failed
            text: screen.managed ? Messages.controlledFailure(screen.control.errorCode)
                                 : screen.refusal(screen.control.errorCode, "addon.controlled_docs.document_manage")
            Accessible.role: Accessible.AlertMessage
        }
        Notice {
            code: screen.view.notice !== "" ? screen.view.notice : screen.control.active ? screen.control.notice : ""
            place: screen.view.documentId + ":" + screen.view.tab
            text: Messages.documentNotice(code)
        }
        Label { visible: screen.view.busy; text: qsTr("Working…") }
    }
}
