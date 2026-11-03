import QtQuick
import QtQuick.Controls
import "."

// Self-drawn toggle switch with a sliding knob.
AbstractButton {
    id: control
    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 28
    implicitWidth: track.width + 12 + label.implicitWidth
    opacity: enabled ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    background: null
    contentItem: Item {
        implicitHeight: control.implicitHeight

        Rectangle {
            id: track
            width: 40
            height: 22
            radius: 11
            anchors.verticalCenter: parent.verticalCenter
            color: control.checked ? (control.hovered ? Theme.accentHover : Theme.accent)
                : (control.hovered ? Theme.surfaceAlt : Theme.surface)
            border.width: control.checked ? 0 : 1.5
            border.color: Theme.borderStrong
            Behavior on color { ColorAnimation { duration: Theme.normal } }

            Rectangle {
                id: knob
                width: control.pressed ? 18 : 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: control.checked ? track.width - width - 4 : 4
                color: control.checked ? Theme.accentText : Theme.muted
                Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Theme.fast } }
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 14
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                visible: control.visualFocus
            }
        }

        Text {
            id: label
            anchors.left: track.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            color: control.enabled ? Theme.text : Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 13
        }
    }
}
