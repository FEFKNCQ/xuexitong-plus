import QtQuick
import QtQuick.Controls
import "."

// Text field with a self-drawn background (works under any Quick Controls style).
TextField {
    id: control
    implicitHeight: 36
    leftPadding: 12
    rightPadding: 12
    font.family: Theme.uiFont
    font.pixelSize: 13
    color: Theme.text
    placeholderTextColor: Theme.faint
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentText
    selectByMouse: true
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: Theme.radius
        color: control.enabled ? (control.hovered && !control.activeFocus ? Theme.surfaceAlt : Theme.surface) : Theme.sunken
        border.width: 1
        border.color: control.activeFocus ? Theme.accent : (control.hovered ? Theme.borderStrong : Theme.border)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

        // Fluent-style focus underline that grows from the centre.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: 2
            radius: 1
            width: control.activeFocus ? parent.width - 2 * parent.radius : 0
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        }
    }
}
