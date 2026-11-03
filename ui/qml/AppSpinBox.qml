import QtQuick
import QtQuick.Controls
import "."

// Self-drawn spin box: editable value with − / + buttons on the right, same field look
// as AppTextField / AppComboBox. Keeps SpinBox's API (from, to, value, stepSize,
// textFromValue, valueFromText, valueModified).
SpinBox {
    id: control
    implicitHeight: 36
    implicitWidth: 140
    editable: true
    font.family: Theme.uiFont
    font.pixelSize: 13
    hoverEnabled: true
    leftPadding: 12
    rightPadding: 66

    background: Rectangle {
        radius: Theme.radius
        color: !control.enabled ? Theme.sunken : control.hovered ? Theme.surfaceAlt : Theme.surface
        border.width: 1
        border.color: control.activeFocus ? Theme.accent : control.hovered ? Theme.borderStrong : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
        // Focus underline, like AppTextField.
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

    contentItem: TextInput {
        text: control.displayText
        font: control.font
        color: control.enabled ? Theme.text : Theme.faint
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        horizontalAlignment: Qt.AlignLeft
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        selectByMouse: true
    }

    component StepButton: Rectangle {
        id: step
        property bool plus: true
        property bool pressed: false
        property bool hovered: false
        property bool canStep: true
        width: 26
        height: control.height - 10
        y: 5
        radius: Theme.radius - 2
        color: !canStep ? "transparent" : pressed ? Theme.sunken : hovered ? Theme.surfaceAlt : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Text {
            anchors.centerIn: parent
            text: step.plus ? "" : ""   // add / remove
            font.family: Theme.iconFont
            font.pixelSize: 11
            color: step.canStep && control.enabled ? (step.hovered ? Theme.text : Theme.muted) : Theme.faint
            scale: step.pressed ? 0.85 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
        }
    }

    up.indicator: StepButton {
        x: control.width - width - 5
        plus: true
        pressed: control.up.pressed
        hovered: control.up.hovered
        canStep: control.value < control.to
    }
    down.indicator: StepButton {
        x: control.width - 2 * width - 9
        plus: false
        pressed: control.down.pressed
        hovered: control.down.hovered
        canStep: control.value > control.from
    }
}
