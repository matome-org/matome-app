pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import matome

// The マ mark from the landing, on its 100-unit grid: a frame, マ in its two
// strokes, and the gold fold at the corner. With `animated` it writes itself
// the first time it shows — frame, the hooked stroke, the short one, then the
// fold springs out of the corner — on the landing's timings. Reduced motion
// shows it whole.
Item {
    id: logo

    property bool animated: false
    // Set once the mark has been written: a later visit shows it whole.
    property bool written: false

    // How much of each stroke is written, and the fold's scale.
    property real frame: 1
    property real hook: 1
    property real tick: 1
    property real fold: 1

    readonly property real unit: logo.width / 100
    readonly property bool writing: script.running

    function write() {
        logo.written = true
        script.stop()
        const blank = logo.animated && !Theme.reduceMotion ? 0 : 1
        logo.frame = blank
        logo.hook = blank
        logo.tick = blank
        logo.fold = blank
        if (blank === 0)
            script.start()
    }

    // One stroke of the mark on the 100-unit grid, written up to `drawn`.
    component Stroke: ShapePath {
        id: stroke

        required property string svg
        required property real drawn
        required property real weight
        required property real unit

        scale: Qt.size(stroke.unit, stroke.unit)
        strokeColor: Theme.textPrimary
        strokeWidth: stroke.weight * stroke.unit
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        trim.end: stroke.drawn

        PathSvg { path: stroke.svg }
    }

    implicitWidth: 96
    implicitHeight: 96
    Accessible.ignored: true

    Component.onCompleted: if (logo.visible && !logo.written)
        logo.write()
    onVisibleChanged: if (logo.visible && !logo.written)
        logo.write()

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Stroke { svg: "M2.5,94 V2.5 H97.5 V97.5 H35"; weight: 5; unit: logo.unit; drawn: logo.frame }
        Stroke { svg: "M35,37.8 H64 L50.5,53"; weight: 3.2; unit: logo.unit; drawn: logo.hook }
        Stroke { svg: "M41.5,47.8 L57,62.5"; weight: 3.2; unit: logo.unit; drawn: logo.tick }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.x: 0
            origin.y: logo.height
            xScale: logo.fold
            yScale: logo.fold
        }

        ShapePath {
            scale: Qt.size(logo.unit, logo.unit)
            strokeColor: "transparent"
            fillColor: Theme.accentLine

            PathSvg { path: "M0,94 L11.5,86 C19,90 27,93.5 35,95 L35,100 L0,100 Z" }
        }
    }

    // styles.css .brand__*: delays and lengths in ms, and each stroke's curve.
    ParallelAnimation {
        id: script

        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation {
                target: logo; property: "frame"; to: 1; duration: 900
                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.65, 0, 0.35, 1, 1, 1]
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1100 }
            NumberAnimation {
                target: logo; property: "hook"; to: 1; duration: 500
                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.5, 0, 0.3, 1, 1, 1]
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1700 }
            NumberAnimation {
                target: logo; property: "tick"; to: 1; duration: 300
                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.5, 0, 0.3, 1, 1, 1]
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 2050 }
            NumberAnimation {
                target: logo; property: "fold"; to: 1; duration: 550
                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 1.4, 0.5, 1, 1, 1]
            }
        }
    }
}
