pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import matome
import "../chrome"

// Rendered Markdown. Images a version pins come from the image provider,
// signed through `via`; images from other sites load only once the reader
// asks, so opening a document does not reach them. With `opensLinks`, a
// linked file of the space opens (`documentRequested`) from its link or
// from the row of linked files, which keys and touch reach too, whether it
// is linked by id or by its path; other web links open in the browser.
ColumnLayout {
    id: view

    property string markdown
    property string via
    property bool external: false
    property bool opensLinks: true
    // The files the Markdown links, not embeds, once each, as `{link, title}`.
    readonly property var linked: {
        const seen = {}
        const list = []
        const pattern = /(^|[^!])\[([^\]]*)\]\((matome:doc\/\d+|\/[^)\s]*)[^)]*\)/g
        let match
        while ((match = pattern.exec(view.markdown)) !== null) {
            if (seen[match[3]])
                continue
            seen[match[3]] = true
            list.push({ link: match[3], title: match[2] })
        }
        return list
    }
    // The path link that led to no file of the space.
    property string missing

    signal documentRequested(string documentId)

    function follow(link) {
        const file = /^matome:doc\/(\d+)/.exec(link)
        view.missing = ""
        if (file)
            view.documentRequested(file[1])
        else if (link.startsWith("/"))
            Session.assets.resolve(link)
        else if (/^https?:/i.test(link))
            Qt.openUrlExternally(link)
    }

    Layout.fillWidth: true
    spacing: Theme.gapS
    onMarkdownChanged: view.missing = ""

    Connections {
        target: Session.assets
        enabled: view.opensLinks && view.visible
        function onResolved(link, documentId) {
            if (!view.linked.some(function (file) { return file.link === link }))
                return
            if (documentId !== "")
                view.documentRequested(documentId)
            else
                view.missing = link
        }
    }

    RowLayout {
        visible: !view.external && Session.assets.linksExternal(view.markdown)
        Layout.fillWidth: true
        spacing: Theme.gapS
        Label { text: qsTr("Images from other sites are not loaded, so opening this document does not reach them.") }
        ActionButton { text: qsTr("Load external images"); icon: "image"; onActivated: view.external = true }
    }
    TextEdit {
        id: text
        Layout.fillWidth: true
        readOnly: true
        selectByMouse: true
        selectByKeyboard: true
        activeFocusOnTab: true
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.MarkdownText
        // The width comes from the layout, never from this text, so images
        // sized to it cannot resize it in turn.
        text: Session.assets.render(view.markdown, Session.currentOrgId, Session.currentSpaceId, view.via,
                                    Math.max(1, Math.floor(view.width)), view.external)
        font: Theme.body
        color: Theme.textPrimary
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.textPrimary
        Accessible.name: view.Accessible.name
        onLinkActivated: function (link) { if (view.opensLinks) view.follow(link) }

        HoverHandler {
            cursorShape: text.hoveredLink !== "" && view.opensLinks ? Qt.PointingHandCursor : Qt.IBeamCursor
        }
    }
    Flow {
        visible: view.opensLinks && view.linked.length > 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.gapS
        spacing: Theme.gapXs
        Caption { height: Theme.controlM; verticalAlignment: Text.AlignVCenter; text: qsTr("Linked files") }
        Repeater {
            model: view.linked
            delegate: ActionButton {
                required property var modelData
                text: modelData.title
                icon: "document"
                onActivated: view.follow(modelData.link)
            }
        }
    }
    Label {
        visible: view.missing !== ""
        color: Theme.failed
        text: qsTr("No file of this space is at %1.").arg(decodeURIComponent(view.missing))
        Accessible.role: Accessible.AlertMessage
    }
}
