import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: tile
    property string label: ""
    property string value: ""
    property string icon: ""
    property string placeholder: "—"

    color: Theme.surface
    radius: Theme.radiusLarge
    border.color: Theme.border
    implicitHeight: 76

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 6

        RowLayout {
            spacing: 6
            Text {
                text: tile.icon
                font.family: Theme.iconFont
                font.pixelSize: 12
                color: Theme.faint
            }
            Text {
                text: tile.label
                color: Theme.muted
                font.pixelSize: 12
            }
        }
        Text {
            Layout.fillWidth: true
            text: tile.value !== "" ? tile.value : tile.placeholder
            color: tile.value !== "" ? Theme.text : Theme.faint
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            ToolTip.visible: hover.hovered && tile.value.length > 12
            ToolTip.text: tile.value
            HoverHandler { id: hover }
        }
    }
}
