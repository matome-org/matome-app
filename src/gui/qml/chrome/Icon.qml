pragma ComponentBehavior: Bound

import QtQuick
import matome

// Line icons on a 24-unit grid, stroked at the landing's 1.4 in a Theme
// colour; `solids` adds a filled part in the same colour. Canvas paints the
// same on desktop, WebAssembly, and Android. The command table names each
// command's icon, so menus and buttons pick theirs from it.
Canvas {
    id: icon

    property string name
    property color color: Theme.textSecondary
    property color fillColor: "transparent"
    readonly property real strokeWidth: 1.4

    readonly property var paths: ({
        "settings": "M9 3h6l1 3 3 1 2 5-2 5-3 1-1 3H9l-1-3-3-1-2-5 2-5 3-1Z M16 12a4 4 0 1 1-8 0a4 4 0 1 1 8 0z",
        "folder": "M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z",
        "document": "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z M14 2v4a2 2 0 0 0 2 2h4 M8 13h8 M8 17h5",
        "controlled-docs": "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z M14 2v4h6 M8 14l3 3 6-6",
        "org": "M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2 M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2 M10 6h4 M10 10h4 M10 14h4 M10 18h4",
        "space": "M4 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z M15 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z M15 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1z M4 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1z",
        "back": "M12 19l-7-7 7-7 M19 12H5",
        "forward": "M5 12h14 M12 5l7 7-7 7",
        "up": "M5 12l7-7 7 7 M12 19V5",
        "new": "M5 12h14 M12 5v14",
        "upload": "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4 M17 8l-5-5-5 5 M12 3v12",
        "download": "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4 M7 10l5 5 5-5 M12 15V3",
        "rename": "M21.17 6.81a1 1 0 0 0-3.99-3.99L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z M15 5l4 4",
        "trash": "M3 6h18 M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6 M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2 M10 11v6 M14 11v6",
        "purge": "M3 6h18 M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6 M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2 M10 11l4 6 M14 11l-4 6",
        "next-region": "M3 5h18v14H3z M9 5v14 M13 12h5 M16 9l3 3-3 3",
        "previous-region": "M3 5h18v14H3z M15 5v14 M11 12H6 M8 9l-3 3 3 3",
        "restore":"M9 14L4 9l5-5 M4 9h10.5a5.5 5.5 0 0 1 0 11H11",
        "cut": "M6 3a3 3 0 1 0 0 6a3 3 0 1 0 0-6z M6 15a3 3 0 1 0 0 6a3 3 0 1 0 0-6z M20 4L8.12 15.88 M14.47 14.48L20 20 M8.12 8.12L12 12",
        "paste": "M9 2h6a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2",
        "refresh": "M3 12a9 9 0 0 1 15.74-5.26L21 8 M21 3v5h-5 M21 12a9 9 0 0 1-15.74 5.26L3 16 M8 16H3v5",
        "filter": "M19 11a8 8 0 1 1-16 0a8 8 0 1 1 16 0z M21 21l-4.3-4.3",
        "chevron": "M9 18l6-6-6-6",
        "menu": "M4 6h16 M4 12h16 M4 18h16",
        "close": "M18 6L6 18 M6 6l12 12",
        "user": "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2 M16 7a4 4 0 1 1-8 0a4 4 0 1 1 8 0z",
        "keymap": "M4 5h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z M7 15h10 M7 10h1 M11 10h2 M16 10h1",
        "sheet": "M4 17l6-6-6-6 M12 19h8",
        "sign-out": "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4 M16 17l5-5-5-5 M21 12H9",
        "theme-light": "M16 12a4 4 0 1 1-8 0a4 4 0 1 1 8 0z M12 2v2 M12 20v2 M4.93 4.93l1.41 1.41 M17.66 17.66l1.41 1.41 M2 12h2 M20 12h2 M6.34 17.66l-1.41 1.41 M19.07 4.93l-1.41 1.41",
        "theme-dark": "M12 3a6 6 0 0 0 9 9a9 9 0 1 1-9-9z",
        "theme-system": "M4 3h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z M8 21h8 M12 17v4",
        "theme": "M20 12a8 8 0 1 1-16 0a8 8 0 1 1 16 0z",
        "language": "M22 12a10 10 0 1 1-20 0a10 10 0 1 1 20 0z M2 12h20 M12 2a15.3 15.3 0 0 1 4 10a15.3 15.3 0 0 1-4 10a15.3 15.3 0 0 1-4-10a15.3 15.3 0 0 1 4-10z",
        "check": "M20 6L9 17l-5-5",
        "diff": "M12 4v10 M7 9h10 M7 20h10",
        "cancel": "M22 12a10 10 0 1 1-20 0a10 10 0 1 1 20 0z M4.93 4.93l14.14 14.14",
        "pause": "M9 5v14 M15 5v14",
        "image": "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z M10 9a1.5 1.5 0 1 1-3 0a1.5 1.5 0 1 1 3 0z M21 15l-5-5L5 21"
    })
    readonly property var solids: ({
        "theme": "M12 4a8 8 0 0 1 0 16z"
    })
    readonly property string path: icon.paths[icon.name] ?? ""
    readonly property string solid: icon.solids[icon.name] ?? ""

    implicitWidth: Theme.iconM
    implicitHeight: Theme.iconM
    Accessible.ignored: true

    onPathChanged: requestPaint()
    onColorChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (icon.path === "" || icon.width <= 0)
            return
        const scale = icon.width / 24
        ctx.scale(scale, icon.height / 24)
        ctx.lineWidth = icon.strokeWidth / scale
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = icon.color
        ctx.fillStyle = icon.fillColor
        ctx.path = icon.path
        if (icon.fillColor.a > 0)
            ctx.fill()
        ctx.stroke()
        if (icon.solid !== "") {
            ctx.fillStyle = icon.color
            ctx.path = icon.solid
            ctx.fill()
        }
    }
}
