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
// text, and the list of versions. Every verb is a row of Session.commandList,
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
    readonly property bool dirty: view.editable && editor.text !== view.text
    readonly property var tabs: ["view", "edit", "versions", "reviews"]
    property string draftView: "write"
    property string pendingAction

    function command(id) { return Commands.find(Session.commandList, id) }
    function dismiss() {
        if (confirmation.visible) confirmation.close()
        else if (screen.inReview) Session.runCommand("close-review")
        else if (screen.dirty) screen.ask("close")
        else screen.view.close()
    }
    function ask(action) {
        screen.pendingAction = action
        const review = action === "save" && screen.managed
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
        if (id === "save-document" && screen.dirty) screen.ask("save")
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
        function onSaved() {
            if (screen.view.notice === "review_requested")
                screen.view.tab = "reviews"
        }
        function onChanged() {
            if (screen.view.errorIndex < 0 || screen.view.tab !== "edit")
                return
            const at = Session.assets.referenceAt(editor.text, screen.view.errorIndex)
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
                            text: screen.managed ? qsTr("Submit for review") : save.command.title
                            usable: save.command.usable && screen.dirty && !Session.assets.uploading
                        }

                        CommandButton { commandId: "open-review"; visible: screen.view.tab === "reviews" && !screen.inReview; primary: true }

                        CommandButton { commandId: "download-candidate"; visible: screen.inReview; showLabel: !screen.narrow }
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
                       screen.managed ? (screen.control.reviewOpen ? qsTr("Managed · review open") : qsTr("Managed")) : ""]
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
                    text: screen.managed && screen.control.reviewOpen
                          ? qsTr("A review of this document is open. Decide or cancel it before submitting more changes.")
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
            if (screen.pendingAction === "save") screen.view.save(editor.text, confirmation.reason)
            else if (screen.pendingAction === "discard") editor.text = screen.view.text
            else if (screen.pendingAction === "close") screen.view.close()
            else if (screen.pendingAction === "unmanage") screen.control.setControlled(false, confirmation.reason)
            else screen.control.decide(screen.pendingAction, confirmation.reason)
        }
        onVisibleChanged: if (!visible && screen.visible) screen.focusDefault()
    }
}
