import QtQuick
import QtQuick.Controls
import "."

// Self-drawn checkbox with an animated tick. The whole row (box + label) is clickable.
AbstractButton {
    id: control
    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 28
    implicitWidth: box.width + 10 + label.implicitWidth

    background: null
    contentItem: Item {
        implicitHeight: control.implicitHeight

        Rectangle {
            id: box
            width: 20
            height: 20
            radius: 5
            anchors.verticalCenter: parent.verticalCenter
            color: control.checked ? (control.hovered ? Theme.accentHover : Theme.accent)
                : (control.hovered ? Theme.surfaceAlt : Theme.surface)
            border.width: control.checked ? 0 : 1.5
            border.color: control.hovered ? Theme.muted : Theme.borderStrong
            scale: control.pressed ? 0.9 : 1
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: ""
                font.family: Theme.iconFont
                font.pixelSize: 12
                color: Theme.accentText
                opacity: control.checked ? 1 : 0
                scale: control.checked ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 8
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                visible: control.visualFocus
            }
        }

        Text {
            id: label
            anchors.left: box.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            color: control.enabled ? Theme.text : Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 13
        }
    }
}
