.pragma library

// How a comparison marks what changed, in the colours of `theme` (Theme):
// a wash for a block or a line added or removed, and the rich-text style of
// the words a change adds (`<span class="ins">`) or removes
// (`<span class="del">`).

function wash(theme, change) {
    if (change === "added")
        return Qt.tint(theme.surface, theme.fill(theme.added, 0.12))
    if (change === "removed")
        return Qt.tint(theme.surface, theme.fill(theme.failed, 0.10))
    return "transparent"
}

// The bar beside a block that changed.
function bar(theme, change) {
    return change === "added" ? theme.added : change === "removed" ? theme.failed : theme.accentLine
}

function css(theme) {
    return ".ins{background-color:" + Qt.tint(theme.surface, theme.fill(theme.added, 0.32))
            + "}.del{background-color:" + Qt.tint(theme.surface, theme.fill(theme.failed, 0.28))
            + ";text-decoration:line-through}"
}

// What a screen reader says a change is.
function name(change) {
    switch (change) {
    case "added": return qsTr("Added")
    case "removed": return qsTr("Removed")
    case "changed": return qsTr("Changed")
    default: return ""
    }
}
