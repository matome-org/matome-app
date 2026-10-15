pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome
import "../chrome"
import "Marks.js" as Marks

// Rendered Markdown, block by block (MarkdownBlocks) in a centred column no
// wider than Theme.reading; only the blocks in sight are built, laid out
// again once the width stops changing, the top block kept in place. It
// scrolls as a GlideList. A drag selects across blocks, Ctrl+A selects them
// all, Ctrl+C copies the text selected. Images a version pins come from the
// image provider, signed through `via`, their space kept while they load;
// images from other sites load only once the reader asks. With
// `opensLinks`, a click or a tap on a link opens a file of the space
// (`documentRequested`), by id or by path, or a web page. Given a
// comparison's blocks (`blockModel`, MarkdownDiff's), it marks each block
// added, removed, or changed, the words changed inside it, and folds the
// unchanged runs into a row a click or Enter opens; removed blocks sign
// their images through `beforeVia`. A table wider than the column grows,
// centred on it, up to the list's width, then scrolls across; its cells
// wrap between words only. showLine() and topLine() tie the view to the
// Markdown's source lines.
FocusScope {
    id: view

    property string markdown
    property string via
    property string beforeVia
    // MarkdownBlocks or MarkdownDiff's blocks; the view's own by default.
    property var blockModel: blocks
    property bool external: false
    property bool opensLinks: true
    property bool touch: false
    // The path link that led to no file of the space.
    property string missing
    // The view's width, followed once it has stopped changing.
    property real settled: 0
    // The ends of the selection, `{index, pos, text}` each: the block, the
    // position in its text (0 or 1 before or after a block without text),
    // and that text as the block showed it; null with nothing selected.
    property var anchorPoint: null
    property var focusPoint: null
    // The ends in reading order, `{low, high}`; null with nothing selected.
    readonly property var span: {
        const from = view.anchorPoint, to = view.focusPoint
        if (from === null || to === null)
            return null
        const forward = from.index < to.index || (from.index === to.index && from.pos <= to.pos)
        return forward ? { low: from, high: to } : { low: to, high: from }
    }
    readonly property real column: Math.max(0, Math.min(view.settled - 2 * Theme.gapL, Theme.reading))
    // Each image's height over its width and its own width, by link, once
    // it has loaded, so a block built again takes its height at once.
    property var shapes: ({})
    // The line and paragraph separators a TextEdit's text holds.
    readonly property var separators: new RegExp("[\\u2028\\u2029]", "g")
    readonly property alias list: list

    signal documentRequested(string documentId)

    function follow(link) {
        const file = /^matome:doc\/([0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})/.exec(link)
        view.missing = ""
        if (file)
            view.documentRequested(file[1])
        else if (link.startsWith("/"))
            Session.assets.resolve(link)
        else if (/^(https?:|mailto:)/i.test(link))
            Qt.openUrlExternally(link)
    }
    // The rich text of a block: its links, inline code, and line height
    // themed.
    function styled(html, lineHeight) {
        return "<style>a{color:" + Theme.accentText + ";text-decoration:none}code{font-family:'" + Theme.mono.family
                + "';background-color:" + Qt.tint(Theme.background, Theme.subtleFillStrong) + "}" + Marks.css(Theme)
                + "</style><p style=\"margin:0;line-height:"
                + lineHeight + "%\">" + html + "</p>"
    }

    // Selection
    function rangeOf(index) {
        const span = view.span
        if (span === null || index < span.low.index || index > span.high.index)
            return null
        return { start: index === span.low.index ? span.low.pos : 0,
                 end: index === span.high.index ? span.high.pos : Number.MAX_SAFE_INTEGER }
    }
    // The block under the point (`x`, `y`) of the list, null for none.
    function blockAt(x, y) {
        const at = list.mapToItem(list.contentItem, x, y)
        return list.itemAt(at.x, at.y) as Block
    }
    // Where the point (`x`, `y`) of the list falls: `{index, pos, text, link}`.
    function hit(x, y) {
        const block = view.blockAt(x, y)
        if (block) {
            const inside = list.mapToItem(block, x, y)
            return block.hit(inside.x, inside.y)
        }
        if (list.count === 0)
            return null
        const at = list.mapToItem(list.contentItem, x, y)
        return at.y < list.originY + list.contentHeight / 2 ? { index: 0, pos: 0, text: null, link: "" }
                                                         : { index: list.count - 1, pos: Number.MAX_SAFE_INTEGER, text: null, link: "" }
    }
    function selectAll() {
        if (list.count === 0)
            return
        view.anchorPoint = { index: 0, pos: 0, text: null }
        view.focusPoint = { index: list.count - 1, pos: Number.MAX_SAFE_INTEGER, text: null }
    }
    function deselect() {
        view.anchorPoint = null
        view.focusPoint = null
    }
    // The selected text, blocks apart by a blank line.
    function selectedText() {
        const span = view.span
        if (span === null)
            return ""
        const parts = []
        for (let index = span.low.index; index <= span.high.index; ++index) {
            const range = view.rangeOf(index)
            const shown = index === span.low.index && span.low.text !== null ? span.low.text
                        : index === span.high.index && span.high.text !== null ? span.high.text : null
            const part = shown !== null ? shown.slice(range.start, Math.min(range.end, shown.length))
                       : range.end > range.start ? view.blockModel.plainAt(index) : ""
            if (part !== "")
                parts.push(part)
        }
        return parts.join("\n\n")
    }
    function copy() {
        const text = view.selectedText()
        if (text !== "")
            Clipboard.setText(text)
    }
    // Brings source line `line` (1-based, a fraction down it) of the
    // Markdown to the top: its block, as far down itself as the line.
    function showLine(line: real) {
        const index = blocks.blockAt(Math.floor(line))
        if (index < 0)
            return
        list.positionViewAtIndex(index, ListView.Beginning)
        const block = list.itemAtIndex(index) as Block
        if (!block)
            return
        const share = Math.max(0, Math.min(1, (line - block.firstLine) / (block.lastLine - block.firstLine + 1)))
        const range = list.bounds()
        list.contentY = Math.max(range.top, Math.min(range.bottom, block.y + share * block.height))
    }
    // The source line at the top, a fraction down it; 0 without blocks.
    function topLine(): real {
        const block = list.itemAt(list.width / 2, list.contentY) as Block
        if (!block)
            return list.count > 0 && list.contentY > list.originY ? Number.MAX_SAFE_INTEGER : 0
        const share = Math.max(0, Math.min(1, (list.contentY - block.y) / Math.max(1, block.height)))
        return block.firstLine + share * (block.lastLine - block.firstLine + 1)
    }
    // Opens the fold on row `index` of a comparison.
    function expand(index) {
        if ((list.itemAtIndex(index) as Block)?.kind === "fold")
            view.blockModel.expand(index)
    }

    Component.onCompleted: view.settled = view.width
    onWidthChanged: if (view.settled === 0) view.settled = view.width; else settling.restart()
    onMarkdownChanged: {
        view.missing = ""
        view.deselect()
    }

    MarkdownBlocks {
        id: blocks
        markdown: view.markdown
    }
    Connections {
        target: view.blockModel
        function onModelReset() { view.deselect() }
    }

    // The width settles: the top block stays where it was, as far down
    // itself as before.
    Timer {
        id: settling
        interval: 150
        onTriggered: {
            const top = list.itemAt(list.width / 2, list.contentY) as Block
            const index = top ? top.index : -1
            const share = top ? (list.contentY - top.y) / Math.max(1, top.height) : 0
            view.settled = view.width
            if (index < 0)
                return
            list.forceLayout()
            list.positionViewAtIndex(index, ListView.Beginning)
            const block = list.itemAtIndex(index)
            if (block)
                list.contentY = block.y + share * block.height
        }
    }

    Connections {
        target: Session.assets
        enabled: view.opensLinks && view.visible
        function onResolved(link, documentId) {
            if (!view.markdown.includes("](" + link))
                return
            if (documentId !== "")
                view.documentRequested(documentId)
            else
                view.missing = link
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.gapS

        RowLayout {
            visible: !view.external && view.blockModel.externalImages
            Layout.fillWidth: true
            Layout.maximumWidth: view.column
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.gapS
            Label { text: qsTr("Images from other sites are not loaded, so opening this document does not reach them.") }
            ActionButton { text: qsTr("Load external images"); icon: "image"; onActivated: view.external = true }
        }
        Label {
            visible: view.missing !== ""
            Layout.maximumWidth: view.column
            Layout.alignment: Qt.AlignHCenter
            color: Theme.failed
            text: qsTr("No file of this space is at %1.").arg(decodeURIComponent(view.missing))
            Accessible.role: Accessible.AlertMessage
        }

        GlideList {
            id: list
            objectName: view.objectName + "Blocks"
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: view.blockModel
            touch: view.touch
            topMargin: Theme.gapL
            bottomMargin: Theme.gapXl
            sideways: function (x, y, delta) {
                const block = view.blockAt(x, y)
                return block ? block.slide(delta) : false
            }
            Accessible.role: Accessible.Document
            Accessible.name: view.Accessible.name
            delegate: Block {}

            Keys.onPressed: function (event) {
                event.accepted = true
                if (event.matches(StandardKey.Copy))
                    view.copy()
                else if (event.matches(StandardKey.SelectAll))
                    view.selectAll()
                else if (event.key === Qt.Key_Escape && view.span !== null)
                    view.deselect()
                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && list.marked >= 0)
                    view.expand(list.marked)
                else
                    event.accepted = list.navigate(event)
            }
        }
    }

    // Presses over the blocks select, and a click or tap on a link follows
    // it. On touch a drag scrolls the list instead, and a table across. A
    // press on a block's own control (a table's scroll bar) is the control's.
    MouseArea {
        id: pointer
        property point pressedAt
        property bool dragged: false
        // The block a touch drag scrolls across, and where it last was.
        property Item held: null
        property real lastX
        parent: list
        anchors.fill: parent
        hoverEnabled: !view.touch
        cursorShape: Qt.IBeamCursor

        function reach(x, y) {
            const found = view.hit(x, y)
            if (found)
                view.focusPoint = found
        }

        onPressed: function (mouse) {
            const under = view.blockAt(mouse.x, mouse.y)
            const inside = under ? list.mapToItem(under, mouse.x, mouse.y) : Qt.point(0, 0)
            if (under && under.passes(inside.x, inside.y)) {
                mouse.accepted = false
                return
            }
            pointer.pressedAt = Qt.point(mouse.x, mouse.y)
            pointer.dragged = false
            pointer.held = under
            pointer.lastX = mouse.x
            list.forceActiveFocus(Qt.MouseFocusReason)
            if (view.touch)
                return
            const found = view.hit(mouse.x, mouse.y)
            if ((mouse.modifiers & Qt.ShiftModifier) && view.anchorPoint !== null) {
                view.focusPoint = found
            } else {
                view.anchorPoint = found
                view.focusPoint = null
            }
        }
        onPositionChanged: function (mouse) {
            if (!pointer.pressed) {
                const found = view.hit(mouse.x, mouse.y)
                pointer.cursorShape = found && found.link !== "" && view.opensLinks ? Qt.PointingHandCursor : Qt.IBeamCursor
                return
            }
            if (Math.abs(mouse.x - pointer.pressedAt.x) + Math.abs(mouse.y - pointer.pressedAt.y) > Theme.gapS)
                pointer.dragged = true
            if (view.touch && pointer.held)
                (pointer.held as Block).slide(pointer.lastX - mouse.x)
            pointer.lastX = mouse.x
            if (pointer.dragged && !view.touch)
                pointer.reach(mouse.x, mouse.y)
        }
        onReleased: function (mouse) {
            if (pointer.dragged)
                return
            const found = view.hit(mouse.x, mouse.y)
            view.deselect()
            if (found && found.link !== "" && view.opensLinks)
                view.follow(found.link)
            else if (found)
                view.expand(found.index)
        }

        // Dragging past the top or the bottom scrolls on.
        Timer {
            interval: 30
            repeat: true
            running: pointer.pressed && pointer.dragged && !view.touch
                     && (pointer.mouseY < Theme.gapL || pointer.mouseY > pointer.height - Theme.gapL)
            onTriggered: {
                list.scrollBy(pointer.mouseY < Theme.gapL ? -list.step / 3 : list.step / 3)
                pointer.reach(pointer.mouseX, pointer.mouseY)
            }
        }
    }

    // One block across the list's width, its content in the column.
    component Block: Item {
        id: block

        required property int index
        required property string kind
        required property string html
        required property string code
        required property int level
        required property int quote
        required property int indent
        required property string marker
        required property string source
        required property string alt
        required property var rows
        required property var align
        required property int firstLine
        required property int lastLine
        // What a comparison says of the block: "added", "removed",
        // "changed", or "" (kept); its text with the changed words marked;
        // a fold's count of blocks; a table's state of each row.
        required property string change
        required property string marked
        required property int count
        required property var rowStates

        readonly property real inset: block.quote * Theme.gapL + block.indent * Theme.gapXl
        readonly property real start: (list.width - view.column) / 2 + block.inset
        readonly property real room: Math.max(0, view.column - block.inset)
        readonly property real above: block.kind === "fold" ? Theme.gapXs : block.kind !== "heading" ? 0 : block.level === 1 ? Theme.gapXl : block.level === 2 ? Theme.gapL : Theme.gapM
        readonly property real below: block.indent > 0 && block.kind === "paragraph" ? Theme.gapXs
                                    : block.kind === "heading" ? Theme.gapS : Theme.gapM
        readonly property var range: view.rangeOf(block.index)
        readonly property string via: block.change === "removed" ? view.beforeVia : view.via
        readonly property Shown shown: content.item as Shown
        readonly property TextEdit text: block.shown?.text ?? null
        // Where the content shows, past the column when it reaches further.
        readonly property real outerStart: block.start + (block.shown?.outerX ?? 0)
        readonly property real outerRoom: block.shown?.outerWidth ?? block.room

        // What a press at (`x`, `y`) of the block selects and follows.
        function hit(x, y) {
            if (block.text) {
                const at = block.mapToItem(block.text, x, y)
                return { index: block.index, pos: block.text.positionAt(at.x, at.y), link: block.text.linkAt(at.x, at.y),
                         text: block.text.getText(0, block.text.length).replace(view.separators, "\n") }
            }
            const shown = content.item as Shown
            const at = block.mapToItem(shown, x, y)
            return { index: block.index, pos: y < block.height / 2 ? 0 : 1, text: null,
                     link: shown ? shown.linkAt(at.x, at.y) : "" }
        }
        // Scrolls the content across by `delta`; false when it does not.
        function slide(delta: real): bool {
            const shown = content.item as Shown
            return shown ? shown.slide(delta) : false
        }
        // Whether a press at (`x`, `y`) of the block is its content's own.
        function passes(x: real, y: real): bool {
            const shown = content.item as Shown
            if (!shown)
                return false
            const at = block.mapToItem(shown, x, y)
            return shown.passes(at.x, at.y)
        }
        function apply() {
            if (block.text) {
                if (block.range === null)
                    block.text.deselect()
                else
                    block.text.select(Math.min(block.range.start, block.text.length), Math.min(block.range.end, block.text.length))
            }
        }

        width: list.width
        height: block.above + content.height + block.below
        onRangeChanged: block.apply()

        // A block added or removed on its wash, any change with a bar.
        Rectangle {
            visible: block.change !== "" && block.kind !== "fold"
            x: block.outerStart - Theme.gapS
            y: block.above - Theme.gapXs
            width: block.outerRoom + Theme.gapS
            height: content.height + 2 * Theme.gapXs
            color: Marks.wash(Theme, block.change)
            Rectangle {
                width: 3
                height: parent.height
                color: Marks.bar(Theme, block.change)
            }
        }
        // The row Next or Previous change brought into view.
        Rectangle {
            visible: block.index === list.marked && list.activeFocus
            x: block.outerStart - Theme.gapS - Theme.gapXs
            y: block.above - 2 * Theme.gapXs
            width: block.outerRoom + Theme.gapS + 2 * Theme.gapXs
            height: content.height + 4 * Theme.gapXs
            color: "transparent"
            radius: Theme.rounding
            border.color: Theme.accentLine
            border.width: 2
        }

        Repeater {
            model: block.quote
            delegate: Rectangle {
                required property int index
                x: (list.width - view.column) / 2 + index * Theme.gapL
                width: 3
                height: block.height
                color: Theme.accentLine
            }
        }
        Text {
            id: marker
            readonly property bool box: block.marker === "☐" || block.marker === "☑"
            visible: block.marker !== "" && !marker.box
            anchors.right: content.left
            anchors.rightMargin: Theme.gapS
            y: block.above
            text: block.marker
            font: Theme.bodyLarge
            lineHeight: 1.6
            color: Theme.textMuted
            textFormat: Text.PlainText
        }
        Icon {
            visible: marker.box
            anchors.right: content.left
            anchors.rightMargin: Theme.gapS
            y: block.above + (marker.height - height) / 2
            name: block.marker === "☑" ? "checkbox-checked" : "checkbox"
            color: Theme.textMuted
        }
        Loader {
            id: content
            x: block.start
            y: block.above
            width: block.room
            sourceComponent: block.kind === "heading" || block.kind === "paragraph" ? proseBlock
                           : block.kind === "code" ? codeBlock
                           : block.kind === "table" ? tableBlock
                           : block.kind === "image" ? pictureBlock
                           : block.kind === "fold" ? foldBlock : ruleBlock
            onLoaded: block.apply()
        }
        Rectangle {
            visible: !block.text && block.range !== null && block.range.end > block.range.start
            x: block.outerStart
            y: block.above
            width: block.outerRoom
            height: content.height
            color: Theme.accentSoft
            opacity: 0.6
        }

        Component {
            id: proseBlock
            Shown {
                text: proseText
                implicitHeight: proseText.implicitHeight
                Prose {
                    id: proseText
                    width: parent.width
                    text: view.styled(block.marked !== "" ? block.marked : block.html, block.kind === "heading" ? 130 : 160)
                    font: block.kind !== "heading" ? Theme.bodyLarge
                        : Theme.sized(Theme.heading, [0, 32, 26, 21, 18, 16, 15][block.level])
                    color: block.kind === "heading" && block.level === 6 ? Theme.textSecondary : Theme.textPrimary
                    Accessible.role: block.kind === "heading" ? Accessible.Heading : Accessible.Paragraph
                    Accessible.description: Marks.name(block.change)
                }
            }
        }
        Component {
            id: codeBlock
            Shown {
                text: codeText
                implicitHeight: codeText.implicitHeight + 2 * Theme.gapM
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rounding
                    color: Theme.subtleFill
                    border.color: Theme.border
                }
                Prose {
                    id: codeText
                    x: Theme.gapM
                    y: Theme.gapM
                    width: parent.width - 2 * Theme.gapM
                    text: block.marked === "" ? block.code
                        : "<style>" + Marks.css(Theme) + "</style><div style=\"white-space:pre-wrap\">" + block.marked + "</div>"
                    textFormat: block.marked === "" ? TextEdit.PlainText : TextEdit.RichText
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    font: Theme.mono
                    Accessible.role: Accessible.StaticText
                    Accessible.description: Marks.name(block.change)
                }
            }
        }
        Component {
            id: tableBlock
            Shown {
                id: grid
                readonly property int columns: block.align.length
                // Each column's narrowest width, its longest word, and its
                // natural one, its longest cell on one line.
                readonly property var least: grid.widths(true)
                readonly property var natural: grid.widths(false)
                readonly property real leastTotal: grid.least.reduce(function (sum, width) { return sum + width }, 0)
                readonly property real naturalTotal: grid.natural.reduce(function (sum, width) { return sum + width }, 0)
                // What the table shows of itself: at least the column, at
                // most the list less its margins.
                readonly property real most: Math.max(grid.width, list.width - 2 * Theme.gapL)
                readonly property real seen: Math.min(grid.most, Math.max(grid.width, grid.naturalTotal))
                // Its whole width, scrolled across when wider than it shows.
                readonly property real whole: Math.max(grid.seen, grid.leastTotal)
                readonly property bool scrolls: grid.whole > grid.seen + 0.5
                // Each column's width: natural ones grow alike to fill the
                // table; short of them, each gives up towards its longest word.
                readonly property var sizes: grid.natural.map(function (natural, column) {
                    if (grid.whole >= grid.naturalTotal)
                        return natural * grid.whole / Math.max(1, grid.naturalTotal)
                    const least = grid.least[column]
                    return least + (grid.whole - grid.leastTotal) * (natural - least) / Math.max(1, grid.naturalTotal - grid.leastTotal)
                })

                // The widest cell of each column: its longest word with
                // `words`, else its whole text on one line.
                function widths(words: bool): var {
                    const widths = new Array(grid.columns).fill(0)
                    for (let at = 0; at < cellCells.count; ++at) {
                        const cell = cellCells.itemAt(at) as Cell
                        if (cell)
                            widths[at % grid.columns] = Math.max(widths[at % grid.columns], words ? cell.least : cell.natural)
                    }
                    return widths
                }

                outerX: Math.max(Theme.gapL - block.start, Math.min((grid.width - grid.seen) / 2,
                                                                    list.width - Theme.gapL - block.start - grid.seen))
                outerWidth: grid.seen
                implicitHeight: scroller.height
                linkAt: function (x, y) {
                    const at = grid.mapToItem(cells, x, y)
                    const cell = cells.childAt(at.x, at.y) as Cell
                    if (!cell)
                        return ""
                    const inside = cells.mapToItem(cell.prose, at.x, at.y)
                    return cell.prose.linkAt(inside.x, inside.y)
                }
                slide: function (delta) {
                    if (!grid.scrolls)
                        return false
                    scroller.contentX = Math.max(0, Math.min(grid.whole - grid.seen, scroller.contentX + delta))
                    return true
                }
                passes: function (x, y) {
                    return grid.scrolls && y >= cells.implicitHeight
                }

                Flickable {
                    id: scroller
                    objectName: view.objectName + "Table"
                    // One arrow press across.
                    readonly property real stride: 3 * Theme.gapL
                    x: grid.outerX
                    width: grid.seen
                    height: cells.implicitHeight + (grid.scrolls ? bar.height + Theme.gapXs : 0)
                    contentWidth: grid.whole
                    contentHeight: cells.implicitHeight
                    clip: true
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds
                    activeFocusOnTab: grid.scrolls
                    Accessible.role: Accessible.Table
                    Accessible.name: block.rows[0]?.join(", ") ?? ""
                    C.ScrollBar.horizontal: ThinScrollBar {
                        id: bar
                        shown: true
                    }
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right)
                            grid.slide(event.key === Qt.Key_Left ? -scroller.stride : scroller.stride)
                        else if (event.key === Qt.Key_Home || event.key === Qt.Key_End)
                            scroller.contentX = event.key === Qt.Key_Home ? 0 : grid.whole - grid.seen
                        else
                            return
                        event.accepted = true
                    }

                    GridLayout {
                        id: cells
                        width: grid.whole
                        columns: grid.columns
                        columnSpacing: 0
                        rowSpacing: 0
                        Repeater {
                            id: cellCells
                            model: block.rows.length * grid.columns
                            delegate: Cell {
                                id: cell
                                required property int index
                                readonly property int row: Math.floor(cell.index / grid.columns)
                                readonly property int column: cell.index % grid.columns
                                readonly property string change: block.rowStates[cell.row] ?? ""
                                Layout.preferredWidth: grid.sizes[cell.column]
                                Layout.preferredHeight: cell.prose.implicitHeight + 2 * Theme.gapS
                                Layout.fillHeight: true
                                color: cell.change === "added" || cell.change === "removed" ? Marks.wash(Theme, cell.change)
                                     : cell.row === 0 ? Theme.subtleFillStrong : cell.row % 2 === 0 ? Theme.subtleFill : "transparent"
                                html: block.rows[cell.row][cell.column]
                                textFont: cell.row === 0 ? Theme.strong(Theme.body) : Theme.body
                                alignment: block.align[cell.column] === "right" ? TextEdit.AlignRight
                                         : block.align[cell.column] === "center" ? TextEdit.AlignHCenter : TextEdit.AlignLeft
                            }
                        }
                    }
                    Rectangle {
                        width: cells.width
                        height: cells.implicitHeight
                        color: "transparent"
                        border.color: Theme.border
                    }
                }
                Rectangle {
                    visible: scroller.activeFocus && Theme.focusVisible
                    x: scroller.x - Theme.gapXs
                    y: -Theme.gapXs
                    width: scroller.width + 2 * Theme.gapXs
                    height: scroller.height + 2 * Theme.gapXs
                    color: "transparent"
                    radius: Theme.rounding
                    border.color: Theme.accentLine
                }
            }
        }
        Component {
            id: pictureBlock
            Shown {
                id: frame
                readonly property string url: Session.assets.imageSource(block.source, Session.currentOrgId, Session.currentSpaceId,
                                                                           block.via, Math.floor(block.room), view.external)
                readonly property var shape: view.shapes[block.source] ?? null
                implicitHeight: frame.url === "" ? missingImage.implicitHeight
                              : image.status === Image.Ready ? image.height
                              : frame.shape ? Math.min(frame.width, frame.shape.width) * frame.shape.ratio
                              : Math.min(frame.width * 0.5625, 360)
                Accessible.role: Accessible.Graphic
                Accessible.name: block.alt
                Rectangle {
                    visible: frame.url !== "" && image.status !== Image.Ready
                    width: frame.shape ? Math.min(frame.width, frame.shape.width) : frame.width
                    height: frame.implicitHeight
                    radius: Theme.rounding
                    color: Theme.subtleFill
                }
                Image {
                    id: image
                    source: frame.url
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    width: Math.min(frame.width, implicitWidth)
                    height: implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
                    onStatusChanged: if (image.status === Image.Ready && image.implicitWidth > 0)
                        view.shapes[block.source] = { ratio: image.implicitHeight / image.implicitWidth, width: image.implicitWidth }
                }
                RowLayout {
                    id: missingImage
                    visible: frame.url === ""
                    width: frame.width
                    spacing: Theme.gapS
                    Icon { name: "image"; color: Theme.textMuted }
                    Label { text: block.alt !== "" ? block.alt : block.source; color: Theme.textMuted }
                }
            }
        }
        Component {
            id: foldBlock
            Shown {
                implicitHeight: foldText.implicitHeight + 2 * Theme.gapS
                Accessible.role: Accessible.Button
                Accessible.name: foldText.text
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rounding
                    color: Theme.subtleFill
                }
                Text {
                    id: foldText
                    anchors.centerIn: parent
                    text: qsTr("⋯ %n unchanged block(s)", "", block.count)
                    font: Theme.body
                    color: Theme.textMuted
                    textFormat: Text.PlainText
                }
            }
        }
        Component {
            id: ruleBlock
            Shown {
                implicitHeight: Theme.gapL
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
            }
        }
    }

    // What a block shows: its selectable text, when it has one, and the
    // link under a point of a block without it. It may reach past its own
    // width (`outerX`, `outerWidth`), scroll across (`slide` by a delta,
    // true when it did), and keep presses at a point for its own controls
    // (`passes`).
    component Shown: Item {
        property TextEdit text: null
        property var linkAt: function (x, y) { return "" }
        property real outerX: 0
        property real outerWidth: width
        property var slide: function (delta) { return false }
        property var passes: function (x, y) { return false }
    }

    // Read-only rich text the list selects in for it.
    component Prose: TextEdit {
        readOnly: true
        selectByMouse: false
        activeFocusOnPress: false
        persistentSelection: true
        textFormat: TextEdit.RichText
        wrapMode: TextEdit.Wrap
        color: Theme.textPrimary
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.textPrimary
    }

    // One cell of a table: a hairline right and below. It knows how wide it
    // is at least, its longest word, and on one line.
    component Cell: Rectangle {
        id: cellFrame
        readonly property alias prose: cellText
        readonly property real least: Math.ceil(longestWord.contentWidth) + 2 * Theme.gapS + 1
        readonly property real natural: Math.ceil(cellText.implicitWidth) + 2 * Theme.gapS + 1
        property string html
        property font textFont
        property int alignment
        Prose {
            id: cellText
            x: Theme.gapS
            y: Theme.gapS
            width: cellFrame.width - 2 * Theme.gapS
            text: view.styled(cellFrame.html, 140)
            wrapMode: TextEdit.WordWrap
            font: cellFrame.textFont
            horizontalAlignment: cellFrame.alignment
        }
        // The text wrapped at every word, as wide as its longest one.
        Prose {
            id: longestWord
            visible: false
            width: 1
            text: cellText.text
            wrapMode: TextEdit.WordWrap
            font: cellFrame.textFont
        }
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    }
}
