pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../chrome"

// A side panel that holds one PanelBody at a time: `show` loads a fresh body
// from `component` and opens beside the page, focus returning to `returnTo`
// once it closes. The panel's heading, footer, and focus follow the body;
// the body's `finished` closes it.
SidePanel {
    id: host

    readonly property PanelBody body: editor.item as PanelBody

    function show(component, returnTo) {
        editor.active = false
        editor.sourceComponent = component
        editor.active = true
        host.open(returnTo)
    }

    title: host.body?.title ?? ""
    subtitle: host.body?.subtitle ?? ""
    saveText: host.body?.saveText ?? ""
    saveUsable: host.body?.saveUsable ?? false
    cancelText: host.body?.cancelText ?? qsTr("Cancel")
    initialFocus: host.body?.initialFocus ?? null
    back: function () { return host.body ? host.body.back() : false }
    onSaveRequested: host.body?.saveRequested()

    Loader {
        id: editor
        Layout.fillWidth: true
        active: false
    }
    Connections {
        target: host.body
        function onFinished() { host.close() }
        function onStepChanged() { host.focusIn() }
    }
}
