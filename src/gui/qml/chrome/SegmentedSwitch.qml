pragma ComponentBehavior: Bound

import QtQuick
import matome

// One of a few modes of the same view, a segment each in one frame; the
// current one filled and outlined. A pick only reports it (`picked`). Tab
// reaches the current segment, Left and Right pick the next usable one. A
// segment that does not apply stays, dimmed, and says why.
Rectangle {
    id: control

    // Each segment: `{value, text, icon, key, usable, reason}`; `key`,
    // `usable`, and `reason` may be left out.
    property var options: []
    property string current
    property bool showLabel: true
    // Its width with every label shown, whether or not they show.
    readonly property real labelledWidth: {
        let width = 2 * control.border.width
        for (let at = 0; at < segments.count; ++at)
            width += (segments.itemAt(at) as ViewTab)?.labelledWidth ?? 0
        return width
    }

    signal picked(string value)

    // Picks the first usable segment past `index` towards `delta`.
    function step(index: int, delta: int) {
        for (let at = index + delta; at >= 0 && at < segments.count; at += delta) {
            const segment = segments.itemAt(at) as ViewTab
            if (segment && segment.usable) {
                segment.forceActiveFocus(Qt.TabFocusReason)
                control.picked(segment.view)
                return
            }
        }
    }

    implicitWidth: row.implicitWidth + 2 * control.border.width
    implicitHeight: Theme.controlM
    radius: Theme.pill ? control.height / 2 : Theme.rounding
    color: "transparent"
    border.color: Theme.border
    Accessible.role: Accessible.Grouping

    Row {
        id: row
        anchors.centerIn: parent

        Repeater {
            id: segments
            model: control.options
            delegate: ViewTab {
                id: segment
                required property var modelData
                required property int index
                objectName: control.objectName + "_" + segment.modelData.value
                view: segment.modelData.value
                current: control.current
                text: segment.modelData.text
                icon: segment.modelData.icon
                key: segment.modelData.key ?? ""
                tip: segment.text
                usable: segment.modelData.usable ?? true
                reason: segment.modelData.reason ?? ""
                showLabel: control.showLabel
                tabFocusable: segment.view === control.current
                implicitHeight: control.height - 2 * control.border.width
                borderColor: segment.view === control.current ? Theme.accentLine : "transparent"
                ringOffset: 0
                Accessible.role: Accessible.RadioButton
                onPicked: function (view) { control.picked(view) }
                Keys.onLeftPressed: control.step(segment.index, -1)
                Keys.onRightPressed: control.step(segment.index, 1)
            }
        }
    }
}
