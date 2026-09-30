pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"
import "../chrome/Messages.js" as Messages

// The controlled-documents add-on's Reviews tab: the document's reviews,
// newest first. A tap or the arrows select one; Enter, a double tap, or the
// screen's Open review opens it on its own page, where it is decided.
ColumnLayout {
    id: list

    readonly property var control: Session.controlledDocs
    property bool touch: false

    function memberEmail(id) {
        return list.control.members.find(function (member) { return String(member.id) === String(id) })?.email ?? ""
    }
    function select(index) {
        const review = list.control.reviews[index]
        if (review)
            list.control.selectReview(review.id)
    }
    // Puts the cursor on the selected review.
    function sync() {
        reviews.currentIndex = list.control.reviews.findIndex(function (review) {
            return review.id === list.control.selectedReviewId
        })
    }
    function focusList() { reviews.forceActiveFocus() }

    spacing: Theme.gapS

    Connections {
        target: Session.controlledDocs
        function onChanged() { list.sync() }
    }

    Label {
        visible: list.control.reviewsError !== ""
        text: Messages.controlledFailure(list.control.reviewsError)
        color: Theme.failed
    }
    Label {
        visible: list.control.reviews.length === 0 && !list.control.busy && list.control.reviewsError === ""
        text: qsTr("No reviews yet. Edit the document and submit it for review to start one.")
    }
    CursorList {
        id: reviews
        objectName: "reviewList"
        visible: reviews.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: reviews.contentHeight
        interactive: false
        activeFocusOnTab: true
        spacing: Theme.gapS
        rowHeight: list.touch ? Theme.rowTouch : Theme.controlM
        model: list.control.reviews
        Component.onCompleted: list.sync()
        Accessible.role: Accessible.List
        Accessible.name: qsTr("Reviews")
        onMoved: list.select(reviews.currentIndex)
        onMenuRequested: if (reviews.currentItem)
            menu.show([{ ids: ["open-review"] }], reviews.currentItem, 0, reviews.currentItem.height, reviews)
        delegate: ListRow {
            id: row
            required property var modelData
            required property int index
            objectName: "review_" + row.modelData.id
            view: reviews
            touch: list.touch
            cursor: reviews.currentIndex === row.index
            selected: list.control.selectedReviewId === row.modelData.id
            title: row.modelData.reason
            detail: [Messages.reviewStatus(row.modelData.status), list.memberEmail(row.modelData.author_membership_id),
                     row.modelData.inserted_at ? new Date(row.modelData.inserted_at).toLocaleString(Qt.locale(), Locale.ShortFormat) : ""]
                    .filter(function (part) { return part !== "" }).join(" · ")
            onClicked: list.select(row.index)
            onActivated: {
                list.select(row.index)
                Session.runCommand("open-review")
            }
            onMenuRequested: function (position) {
                list.select(row.index)
                menu.show([{ ids: ["open-review"] }], row, position.x, position.y, reviews)
            }
        }
    }

    ContextMenu {
        id: menu
        commands: Session.commandList
        touch: list.touch
        onChosen: function (id) { Session.runCommand(id) }
    }
}
