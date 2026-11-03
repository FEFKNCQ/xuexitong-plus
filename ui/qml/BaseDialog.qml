import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Self-drawn modal dialog: rounded card, title, scale/fade in and out, dimmed backdrop.
Dialog {
    id: dialog
    property alias buttons: buttonRow.data

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 24
    topPadding: 8
    standardButtons: Dialog.NoButton

    background: Rectangle {
        radius: 14
        color: Theme.surface
        border.color: Theme.border
        // Soft shadow layers.
        Rectangle { z: -1; anchors.fill: parent; anchors.margins: -1; radius: 15; color: "transparent"; border.color: Qt.rgba(0, 0, 0, Theme.dark ? 0.4 : 0.06); border.width: 1 }
        Rectangle { z: -2; anchors.fill: parent; anchors.margins: -4; anchors.topMargin: 0; anchors.bottomMargin: -8; radius: 18; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.28 : 0.045) }
    }

    header: Text {
        text: dialog.title
        visible: dialog.title !== ""
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: 18
        font.weight: Font.Bold
        leftPadding: 24
        rightPadding: 24
        topPadding: 22
        bottomPadding: 6
        elide: Text.ElideRight
    }

    footer: Item {
        implicitHeight: buttonRow.implicitHeight + 40
        RowLayout {
            id: buttonRow
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
        }
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.5 : 0.28)
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1; to: 0.97; duration: Theme.fast; easing.type: Easing.InCubic }
        }
    }
}
