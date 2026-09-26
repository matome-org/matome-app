pragma ComponentBehavior: Bound

import QtQuick
import matome

// A number animation on the landing's curve; `base` long unless told.
NumberAnimation {
    duration: Theme.base
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.ease
}
