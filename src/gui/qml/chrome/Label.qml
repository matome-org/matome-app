pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// Running text in a screen: secondary ink that wraps to the column. Plain
// text, so server strings (reasons, names) never render as markup.
Text {
    Layout.fillWidth: true
    font: Theme.body
    color: Theme.textSecondary
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
}
