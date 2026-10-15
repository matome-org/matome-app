pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The controlled-documents add-on's Reviews tab: one table of the
// document's reviews, open ones first, each open one with how it stands
// against the published version and its approvals. Selecting a row selects
// the review; Open, Enter, or a double click opens it on its own page,
// where it is decided.
DetailTab {
    id: tab

    readonly property var control: Session.controlledDocs
    property bool touch: false

    function memberEmail(id) {
        return tab.control.members.find(function (member) { return String(member.id) === String(id) })?.label ?? ""
    }
    function focusList() { table.focusKey(tab.control.selectedReviewId) }

    view: "reviews"
    title: qsTr("Reviews")
    available: tab.control.active && tab.control.controlled

    commands: [
        CommandButton {
            commandId: "open-review"
            text: qsTr("Open")
            showLabel: !tab.compact
            reason: qsTr("Select one row.")
        }
    ]

    Connections {
        target: Session.controlledDocs
        function onChanged() {
            if (tab.control.selectedReviewId !== "" && table.selectedRow?.id !== tab.control.selectedReviewId)
                table.selectedKeys = [tab.control.selectedReviewId]
        }
    }

    Label {
        visible: tab.control.reviewsError !== ""
        text: Messages.controlledFailure(tab.control.reviewsError)
        color: Theme.failed
    }
    Page {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Table {
            id: table
            objectName: "reviewTable"
            prefix: "review_"
            label: qsTr("Reviews")
            touch: tab.touch
            columns: [{ title: qsTr("Review"), share: 4 }, { title: qsTr("Author"), share: 3 },
                      { title: qsTr("State"), share: 3 }, { title: qsTr("Approvals"), share: 1 }]
            model: tab.control.reviews
            cells: function (review) {
                const open = review.status === "open"
                return [review.reason, tab.memberEmail(review.author_membership_id),
                        open ? Messages.mergeState(review.merge_state) : Messages.reviewStatus(review.status),
                        open ? (review.approvals?.length ?? 0) + "/" + Math.max(1, review.settings?.required_approvals ?? 1) : ""]
            }
            emptyText: tab.control.busy || tab.control.reviewsError !== "" ? ""
                       : qsTr("No reviews yet. Edit the document and submit it for review to start one.")
            onSelectedRowChanged: if (table.selectedRow) tab.control.selectReview(table.selectedRow.id)
            onOpened: function (review) {
                tab.control.selectReview(review.id)
                Session.runCommand("open-review")
            }
        }
    }
}
