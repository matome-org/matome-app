pragma ComponentBehavior: Bound

import QtQuick
import matome

// Section, column, and pane headings: the landing's eyebrow, small spaced
// capitals. Muted unless the heading leads a pane.
Text {
    color: Theme.textMuted
    font: Theme.eyebrow
    elide: Text.ElideRight
    Accessible.role: Accessible.Heading
    Accessible.name: text
}
