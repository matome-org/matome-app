pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import matome

// What a list shows with no rows: the landing's small stack of pages, drawn
// in thin strokes with gold lines of writing, over one serif italic phrase.
// `mode` is "empty", "loading" (the lines write themselves over and over;
// under reduced motion they stay written), or "error" (the lines and the
// words turn to `failed`).
Column {
    id: placeholder

    property string mode: "empty"
    property alias text: phrase.text

    readonly property bool failing: placeholder.mode === "error"
    readonly property color ink: placeholder.failing ? Theme.failed : Theme.accent
    // Each unit of the landing's 29 × 35 drawing, in pixels.
    readonly property real unit: 2

    // How much of each gold line is written.
    property real first: 1
    property real second: 1
    property real third: 1

    // One stroke of the drawing on the landing's grid, 1 px whatever the scale.
    component Stroke: ShapePath {
        id: stroke

        required property string svg
        required property real unit

        scale: Qt.size(stroke.unit, stroke.unit)
        strokeWidth: 1
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathSvg { path: stroke.svg }
    }

    // A line of writing, drawn up to `drawn`.
    component Line: Stroke {
        id: line

        required property real drawn

        strokeColor: placeholder.ink
        fillColor: "transparent"
        trim.end: line.drawn
    }

    spacing: Theme.gapL
    Accessible.role: Accessible.StaticText
    Accessible.name: phrase.text

    Shape {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: 29 * placeholder.unit
        implicitHeight: 35 * placeholder.unit
        preferredRendererType: Shape.CurveRenderer

        Stroke {
            unit: placeholder.unit
            svg: "M8.5,0 H27.5 A1.5,1.5 0 0 1 29,1.5 V26.5 A1.5,1.5 0 0 1 27.5,28 H8.5 A1.5,1.5 0 0 1 7,26.5 V1.5 A1.5,1.5 0 0 1 8.5,0 Z"
            strokeColor: Theme.fill(Theme.textSecondary, 0.45)
            fillColor: Theme.surface
        }
        Stroke {
            unit: placeholder.unit
            svg: "M5,3.5 H24 A1.5,1.5 0 0 1 25.5,5 V30 A1.5,1.5 0 0 1 24,31.5 H5 A1.5,1.5 0 0 1 3.5,30 V5 A1.5,1.5 0 0 1 5,3.5 Z"
            strokeColor: Theme.fill(Theme.textSecondary, 0.45)
            fillColor: Theme.surface
        }
        Stroke {
            unit: placeholder.unit
            svg: "M0,7 H16 L22,13 V35 H0 Z"
            strokeColor: Theme.textSecondary
            fillColor: Theme.surface
        }
        Line { unit: placeholder.unit; svg: "M4,18 H17"; drawn: placeholder.first }
        Line { unit: placeholder.unit; svg: "M4,23 H18"; drawn: placeholder.second }
        Line { unit: placeholder.unit; svg: "M4,28 H13"; drawn: placeholder.third }
    }

    Text {
        id: phrase
        objectName: "emptyText"
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: placeholder.failing ? Theme.failed : Theme.accentText
        font: Theme.slogan
    }

    // Loading writes the three lines in turn, rests, and starts over.
    SequentialAnimation {
        running: placeholder.mode === "loading" && !Theme.reduceMotion
        loops: Animation.Infinite
        onStopped: {
            placeholder.first = 1
            placeholder.second = 1
            placeholder.third = 1
        }

        PropertyAction { target: placeholder; properties: "first,second,third"; value: 0 }
        Ease { target: placeholder; property: "first"; to: 1; duration: Theme.slow }
        Ease { target: placeholder; property: "second"; to: 1; duration: Theme.slow }
        Ease { target: placeholder; property: "third"; to: 1; duration: Theme.base }
        PauseAnimation { duration: Theme.slow }
    }
}
