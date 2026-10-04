pragma ComponentBehavior: Bound

import QtQuick
import matome

// A saved-change confirmation shown where `code` was raised and hidden for
// good once `place` (section, tab, or open item) changes. A move the save
// itself makes in the same event keeps the notice.
Label {
    id: notice

    required property string code
    required property string place
    property bool raised: false

    function capture() { notice.raised = notice.code !== "" }

    onCodeChanged: Qt.callLater(notice.capture)
    onPlaceChanged: notice.raised = false
    visible: notice.raised && notice.code !== ""
    color: Theme.accentText
}
