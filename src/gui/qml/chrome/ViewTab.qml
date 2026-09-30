pragma ComponentBehavior: Bound

import QtQuick
import matome

// One of a row of views over the same thing; the gold-soft wash marks the
// one shown (`current`). Picking one only reports it.
ActionButton {
    id: tab

    required property string view
    required property string current

    signal picked(string view)

    color: tab.current === tab.view ? Theme.accentSoft : "transparent"
    Accessible.role: Accessible.PageTab
    Accessible.checkable: true
    Accessible.checked: tab.current === tab.view
    onActivated: tab.picked(tab.view)
}
