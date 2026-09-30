pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../documents"
import "../chrome/Messages.js" as Messages

// One review of the document, opened from the Reviews tab: who proposed
// what against which version, and what was decided, over the edited
// document or its changes, images included. The screen's command bar
// decides on it.
ColumnLayout {
    id: panel

    readonly property var control: Session.controlledDocs
    readonly property var review: panel.control.review
    readonly property var decision: panel.review.decision ?? null
    property string shown: "document"

    function memberEmail(id) {
        return panel.control.members.find(function (member) { return String(member.id) === String(id) })?.email ?? ""
    }
    function when(time) {
        return time ? new Date(time).toLocaleString(Qt.locale(), Locale.ShortFormat) : ""
    }
    function versionNumber(id) {
        return Session.documentView.versions.find(function (version) { return version.id === id })?.version_number ?? ""
    }

    spacing: Theme.gapS
    onReviewChanged: if (panel.review.id === undefined) panel.shown = "document"

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.gapXs
        Text {
            objectName: "reviewStatus"
            Layout.fillWidth: true
            text: Messages.reviewStatus(panel.review.status ?? "")
            font: Theme.strong(Theme.body)
            color: panel.review.status === "open" ? Theme.accentText : Theme.textPrimary
            textFormat: Text.PlainText
        }
        Label {
            text: {
                const author = panel.memberEmail(panel.review.author_membership_id)
                const base = panel.versionNumber(panel.review.base_version_id)
                return [author !== "" ? qsTr("Submitted by %1").arg(author) : qsTr("Submitted"),
                        panel.when(panel.review.inserted_at),
                        base !== "" ? qsTr("changes version %1").arg(base) : ""]
                       .filter(function (part) { return part !== "" }).join(" · ")
            }
        }
        Label {
            visible: panel.decision !== null
            text: [Messages.reviewStatus(panel.review.status) + " " + qsTr("by %1").arg(panel.memberEmail(panel.decision?.deciding_membership_id) || qsTr("a reviewer")),
                   panel.when(panel.decision?.inserted_at)]
                  .filter(function (part) { return part !== "" }).join(" · ")
                  + ((panel.decision?.comment ?? "") !== "" ? "\n" + qsTr("Comment: %1").arg(panel.decision.comment) : "")
        }
        Label {
            visible: panel.review.status === "open" && !panel.control.canDecide && !panel.control.busy
            text: panel.memberEmail(panel.review.author_membership_id).toLowerCase() === Session.email.toLowerCase()
                  ? qsTr("You submitted this review, so another reviewer must approve or reject it. You can still cancel it.")
                  : qsTr("Approving or rejecting needs review permission in this space.")
        }
    }
    RowLayout {
        spacing: Theme.gapXs
        Accessible.role: Accessible.PageTabList
        ViewTab { view: "document"; current: panel.shown; text: qsTr("Document"); icon: "document"; onPicked: function (view) { panel.shown = view } }
        ViewTab { view: "changes"; current: panel.shown; text: qsTr("Changes"); icon: "diff"; onPicked: function (view) { panel.shown = view } }
    }
    MarkdownView {
        objectName: "reviewCandidate"
        onDocumentRequested: function (id) { Session.openEntry("document", id) }
        visible: panel.shown === "document"
        markdown: panel.control.candidate
        via: panel.control.review.candidate_version_id ?? ""
        Accessible.name: qsTr("Edited document")
    }
    DiffView {
        objectName: "reviewDiff"
        visible: panel.shown === "changes"
        diff: panel.control.diff
    }
    ColumnLayout {
        readonly property var references: panel.control.diffReferences
        readonly property int total: (references.added?.length ?? 0) + (references.removed?.length ?? 0)
                                     + (references.changed?.length ?? 0)
        visible: panel.shown === "changes" && total > 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.gapM
        spacing: Theme.gapS
        Caption { Layout.fillWidth: true; text: qsTr("Images and linked files") }
        Flow {
            Layout.fillWidth: true
            spacing: Theme.gapL
            Repeater {
                model: panel.control.diffReferences.changed ?? []
                delegate: RowLayout {
                    id: swap
                    required property var modelData
                    spacing: Theme.gapS
                    PinnedImage {
                        via: panel.control.review.base_version_id ?? ""
                        documentId: String(swap.modelData.document_id)
                        versionId: swap.modelData.from_version_id
                        caption: qsTr("Before")
                    }
                    Icon { name: "forward" }
                    PinnedImage {
                        via: panel.control.review.candidate_version_id ?? ""
                        documentId: String(swap.modelData.document_id)
                        versionId: swap.modelData.to_version_id
                        caption: qsTr("After")
                    }
                }
            }
            Repeater {
                model: panel.control.diffReferences.added ?? []
                delegate: PinnedImage {
                    required property var modelData
                    via: panel.control.review.candidate_version_id ?? ""
                    documentId: String(modelData.document_id ?? "")
                    versionId: modelData.version_id ?? ""
                    caption: qsTr("Added: %1").arg(modelData.path ?? qsTr("document %1").arg(modelData.document_id))
                }
            }
            Repeater {
                model: panel.control.diffReferences.removed ?? []
                delegate: PinnedImage {
                    required property var modelData
                    via: panel.control.review.base_version_id ?? ""
                    documentId: String(modelData.document_id ?? "")
                    versionId: modelData.version_id ?? ""
                    caption: qsTr("Removed: %1").arg(modelData.path ?? qsTr("document %1").arg(modelData.document_id))
                }
            }
        }
    }
}
