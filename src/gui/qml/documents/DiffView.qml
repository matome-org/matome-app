pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome

// A unified diff as blocks the width of the view: added lines on a green
// wash, removed ones on a red wash, hunk heads muted. Unchanged lines more
// than three away from a change fold into one marker.
TextEdit {
    id: view

    property string diff

    function html(diff) {
        const washAdded = Qt.tint(Theme.surface, Theme.fill(Theme.added, 0.16))
        const washRemoved = Qt.tint(Theme.surface, Theme.fill(Theme.failed, 0.14))
        const lines = diff.split("\n")
        const head = function (line) { return line.startsWith("+++") || line.startsWith("---") || line.startsWith("@@") }
        const changed = lines.map(function (line) { return !head(line) && (line.startsWith("+") || line.startsWith("-")) })
        const near = lines.map(function (line, at) {
            if (head(line)) return true
            for (let step = Math.max(0, at - 3); step <= Math.min(lines.length - 1, at + 3); ++step)
                if (changed[step]) return true
            return false
        })
        const block = function (text, style) {
            return "<p style=\"margin:0;white-space:pre-wrap;" + style + "\">" + text + "</p>"
        }
        let shown = ""
        let folded = 0
        for (let at = 0; at <= lines.length; ++at) {
            if (at < lines.length && !near[at]) {
                ++folded
                continue
            }
            if (folded > 0) {
                shown += block(qsTr("⋯ %n unchanged line(s)", "", folded), "color:" + Theme.textMuted + ";background-color:" + Theme.subtleFill)
                folded = 0
            }
            if (at === lines.length) break
            const line = lines[at]
            const text = line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") || "&nbsp;"
            shown += block(text, head(line) ? "color:" + Theme.textMuted
                               : line.startsWith("+") ? "background-color:" + washAdded + ";color:" + Theme.textPrimary
                               : line.startsWith("-") ? "background-color:" + washRemoved + ";color:" + Theme.textPrimary
                               : "color:" + Theme.textSecondary)
        }
        return shown
    }

    Layout.fillWidth: true
    readOnly: true
    selectByMouse: true
    selectByKeyboard: true
    activeFocusOnTab: true
    wrapMode: TextEdit.WrapAnywhere
    textFormat: TextEdit.RichText
    text: view.html(view.diff)
    font: Theme.mono
    selectionColor: Theme.accentSoft
    Accessible.name: qsTr("Changes")
}
