import QtQuick
import QtQuick.Controls
import "."

// Compact button with a Segoe Fluent icon and optional label.
Button {
    id: control
    property string glyph: ""
    property string tip: ""
    flat: true
    padding: 6
    leftPadding: text !== "" ? 10 : 6
    rightPadding: text !== "" ? 10 : 6
    font.pixelSize: 12
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: 30
    ToolTip.visible: tip !== "" && hovered
    ToolTip.text: tip
    ToolTip.delay: 400

    contentItem: Row {
        spacing: 6
        Text {
            text: control.glyph
            font.family: Theme.iconFont
            font.pixelSize: 13
            color: control.enabled ? Theme.text : Theme.faint
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: control.text !== ""
            text: control.text
            font: control.font
            color: control.enabled ? Theme.text : Theme.faint
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
