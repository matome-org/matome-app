pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import matome

// A pane that slides in at the right edge of this item, beside the list it
// edits from; it covers the whole width when `narrow`. A title over a
// subtitle, the children in a scrolling body, then Cancel and, with a
// `saveText`, the step that saves. It sits in the window's popup layer, so
// a press on it never reaches the list beneath, yet the list stays usable
// beside it. Opening moves focus in (`initialFocus`, else the first control
// of the body); closing returns it to the item `open` was given. Esc and
// Cancel first ask `back`, which steps back out of a confirmation and says
// so, else they close. Keys other than Tab stay in the pane, so none
// reaches the window's commands while it is open.
Item {
    id: panel

    property string title
    property string subtitle
    property string saveText
    property bool saveUsable: true
    property string cancelText: qsTr("Cancel")
    property bool narrow: false
    property Item initialFocus: null
    // Steps back inside the pane, such as out of a confirmation; true when it did.
    property var back: null
    property Item returnTo: null
    // Whether it is open; `open` and `close` set it.
    property bool shown: false
    // The width it takes beside the list while open; none over the list.
    readonly property real reserve: panel.shown && !panel.narrow ? sheet.width : 0
    default property alias content: body.content
    // 0 at rest beside the list, 1 out of sight past the edge.
    property real shift: panel.shown ? 0 : 1

    signal saveRequested()
    signal closed()

    function open(returnTo) {
        panel.returnTo = returnTo ?? null
        panel.shown = true
        body.contentY = 0
        sheet.open()
        Qt.callLater(panel.focusIn)
    }
    function focusIn() {
        if (!panel.shown)
            return
        if (panel.initialFocus && panel.initialFocus.visible)
            panel.initialFocus.forceActiveFocus(Qt.TabFocusReason)
        else
            closeButton.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
    }
    // Focus leaves before the pane does, so the popup layer hands it nowhere.
    function close() {
        if (!panel.shown)
            return
        panel.shown = false
        if (panel.returnTo && panel.returnTo.visible)
            panel.returnTo.forceActiveFocus(Qt.TabFocusReason)
        panel.closed()
    }
    // Cancel or Esc: back out of a step first, else close.
    function dismiss() {
        if (!(panel.back && panel.back()))
            panel.close()
    }

    visible: panel.shown || panel.shift < 1
    Behavior on shift { Ease {} }
    onShiftChanged: if (!panel.shown && panel.shift === 1) sheet.close()

    C.Popup {
        id: sheet
        width: panel.narrow ? panel.width : Math.min(panel.width, Theme.measure + 2 * Theme.gapXxl)
        height: panel.height
        x: panel.width - sheet.width + panel.shift * sheet.width
        y: 0
        padding: 0
        modal: false
        dim: false
        focus: true
        closePolicy: C.Popup.NoAutoClose
        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
        }

        contentItem: FocusScope {
            objectName: "sidePanel"
            Accessible.role: Accessible.Pane
            Accessible.name: panel.title

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape)
                    panel.dismiss()
                event.accepted = event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.gapL
                spacing: Theme.gapM

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gapXs
                        Text {
                            objectName: "sidePanelTitle"
                            Layout.fillWidth: true
                            text: panel.title
                            color: Theme.textPrimary
                            font: Theme.heading
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            Accessible.role: Accessible.Heading
                            Accessible.name: panel.title
                        }
                        Label {
                            objectName: "sidePanelSubtitle"
                            visible: panel.subtitle !== ""
                            text: panel.subtitle
                        }
                    }
                    ActionButton {
                        id: closeButton
                        objectName: "sidePanelClose"
                        Layout.alignment: Qt.AlignTop
                        text: qsTr("Close")
                        icon: "close"
                        showLabel: false
                        tip: text
                        onActivated: panel.close()
                    }
                }

                Page {
                    id: body
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.gapM
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.gapS
                    ActionButton {
                        objectName: "sidePanelCancel"
                        text: panel.cancelText
                        onActivated: panel.dismiss()
                    }
                    ActionButton {
                        objectName: "sidePanelSave"
                        visible: panel.saveText !== ""
                        text: panel.saveText
                        primary: true
                        usable: panel.saveUsable
                        onActivated: panel.saveRequested()
                    }
                }
            }
        }
    }
}
