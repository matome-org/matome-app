pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../documents"
import "../chrome/Messages.js" as Messages

// One review of the document, opened from the Reviews tab, on a page of its
// own: the way back to the document, the review's reason and how it stands
// (its state, against the published version, its approvals), one command
// bar that decides on it or lets its author update it, each command there
// whether it applies or not, and the tabs Changes (its base version against
// its proposal), Document (the proposal rendered), and References (the
// links and images it adds, removes, or repins).
DetailPage {
    id: page

    readonly property var control: Session.controlledDocs
    readonly property var review: page.control.review
    readonly property bool open: page.review.status === "open"
    readonly property string mergeState: page.review.merge_state ?? "clean"
    property bool touch: false
    // One row per reference the proposal adds, removes, or repins.
    readonly property var referenceRows: {
        const changes = page.control.diffReferences
        const row = function (reference, kind, change, index) {
            return { key: kind + index, id: String(reference.item_id ?? ""), change: change,
                     name: page.referenceName(reference) }
        }
        return (changes.added ?? []).map(function (reference, index) { return row(reference, "added", qsTr("Added"), index) })
               .concat((changes.removed ?? []).map(function (reference, index) { return row(reference, "removed", qsTr("Removed"), index) }))
               .concat((changes.changed ?? []).map(function (reference, index) { return row(reference, "changed", qsTr("Changed"), index) }))
    }

    function memberEmail(id) {
        return page.control.members.find(function (member) { return String(member.id) === String(id) })?.label ?? ""
    }
    function when(time) {
        return time ? new Date(time).toLocaleString(Qt.locale(), Locale.ShortFormat) : ""
    }
    function versionNumber(id) {
        return Session.documentView.versions.find(function (version) { return version.id === id })?.version_number ?? ""
    }
    // A reference by the text that links it in the proposal or the base
    // version, else by its path, else by its document.
    function referenceName(reference) {
        const id = String(reference.item_id ?? "")
        const path = reference.path ?? ""
        const target = path !== "" ? path.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\)"
                                   : "matome:(?:doc|asset)/" + id
        const link = new RegExp("!?\\[([^\\]]+)\\]\\(" + target)
        const found = link.exec(page.control.candidate) ?? link.exec(page.control.base)
        return found ? found[1] : path !== "" ? path : qsTr("Document %1").arg(id)
    }
    // Why no command applies to a closed review; "" while it is open.
    function closed() {
        return page.open ? "" : qsTr("This review is closed.")
    }

    name: "review"
    backText: Session.documentView.title
    title: page.review.reason ?? ""
    chips: page.open ? [Messages.reviewStatus("open"),
                        page.mergeState === "behind" ? qsTr("Behind") : page.mergeState === "dirty" ? qsTr("Conflicts") : qsTr("Current"),
                        qsTr("%1/%2 approvals").arg(page.control.approvals).arg(page.control.requiredApprovals)]
                     : [Messages.reviewStatus(page.review.status ?? "")]
    subject: page.review.id ?? ""
    start: "changes"
    onBackRequested: Session.runCommand("close-review")
    Keys.onPressed: function (event) { event.accepted = changesTab.handleKey(event) }

    notes: [
        Label {
            objectName: "reviewSubmitted"
            text: {
                const author = page.memberEmail(page.review.author_membership_id)
                const base = page.versionNumber(page.review.base_version_id)
                return [author !== "" ? qsTr("Submitted by %1").arg(author) : qsTr("Submitted"),
                        page.when(page.review.inserted_at),
                        base !== "" ? qsTr("changes version %1").arg(base) : ""]
                       .filter(function (part) { return part !== "" }).join(" · ")
            }
        },
        Label {
            objectName: "reviewDecision"
            visible: !!page.review.closed_at
            text: [Messages.reviewStatus(page.review.status) + " " + qsTr("by %1").arg(page.memberEmail(page.review.deciding_membership_id) || qsTr("a reviewer")),
                   page.when(page.review.closed_at)]
                  .filter(function (part) { return part !== "" }).join(" · ")
                  + ((page.review.decision_comment ?? "") !== "" ? "\n" + qsTr("Comment: %1").arg(page.review.decision_comment) : "")
        },
        Label {
            objectName: "reviewMergeAdvice"
            visible: page.open && text !== ""
            color: Theme.failed
            text: Messages.mergeAdvice(page.mergeState, page.control.authored)
        }
    ]

    commands: [
        CommandButton {
            commandId: "approve-review"
            primary: true
            showLabel: !page.compact
            reason: page.closed()
                    || (page.control.approved ? qsTr("You approved it already.")
                    : page.control.authored && !page.control.authorMayApprove ? qsTr("Only another reviewer approves it.")
                    : page.mergeState !== "clean" ? qsTr("Its author must update it first.")
                    : page.control.busy ? qsTr("Working…") : qsTr("Approving needs review permission in this space."))
        },
        CommandButton {
            commandId: "reject-review"
            showLabel: !page.compact
            reason: page.closed()
                    || (page.control.authored ? qsTr("Only another reviewer rejects it.")
                    : page.control.busy ? qsTr("Working…") : qsTr("Rejecting needs review permission in this space."))
        },
        CommandButton {
            commandId: "update-review"
            showLabel: !page.compact
            reason: page.closed()
                    || (!page.control.authored ? qsTr("Only its author updates it.")
                    : page.mergeState !== "behind" ? qsTr("It is based on the published version.") : "")
        },
        CommandButton {
            commandId: "resolve-conflicts"
            showLabel: !page.compact
            reason: page.closed()
                    || (!page.control.authored ? qsTr("Only its author resolves its conflicts.")
                    : page.mergeState !== "dirty" ? qsTr("It has no conflicts.") : "")
        },
        CommandButton {
            commandId: "edit-proposal"
            showLabel: !page.compact
            reason: page.closed()
                    || (!page.control.authored ? qsTr("Only its author edits it.")
                    : page.mergeState === "dirty" ? qsTr("Resolve its conflicts first.") : "")
        },
        CommandButton {
            commandId: "cancel-review"
            showLabel: !page.compact
            reason: page.closed()
        },
        CommandButton { commandId: "download-candidate"; showLabel: !page.compact }
    ]

    ChangesTab {
        id: changesTab
        name: "review"
        before: page.control.base
        after: page.control.candidate
        beforeVia: page.review.base_version_id ?? ""
        afterVia: page.review.candidate_version_id ?? ""
        loaded: page.review.id !== undefined && !page.control.busy
        touch: page.touch
    }

    DetailTab {
        view: "document"
        title: qsTr("Document")

        MarkdownView {
            objectName: "reviewCandidate"
            Layout.fillWidth: true
            Layout.fillHeight: true
            markdown: page.control.candidate
            via: page.review.candidate_version_id ?? ""
            touch: page.touch
            Accessible.name: qsTr("Proposal")
            onDocumentRequested: function (id) { Session.openEntry("document", id) }
        }
    }

    DetailTab {
        view: "references"
        title: qsTr("References")

        commands: [
            ActionButton {
                objectName: "referenceOpenButton"
                text: qsTr("Open")
                icon: "forward"
                showLabel: !page.compact
                tip: page.compact ? text : ""
                usable: (references.selectedRow?.id ?? "") !== ""
                reason: qsTr("Select one row.")
                onActivated: Session.openEntry("document", references.selectedRow.id)
            }
        ]

        Page {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Table {
                id: references
                objectName: "referenceTable"
                prefix: "reference_"
                label: qsTr("References")
                touch: page.touch
                columns: [{ title: qsTr("Reference"), share: 4 }, { title: qsTr("Change"), share: 2 }]
                model: page.referenceRows
                keyOf: function (row) { return row.key }
                cells: function (row) { return [row.name, row.change] }
                emptyText: page.control.busy ? "" : qsTr("The proposal adds, removes, and repins no links.")
                onOpened: function (row) { if (row.id !== "") Session.openEntry("document", row.id) }
            }
        }
    }
}
