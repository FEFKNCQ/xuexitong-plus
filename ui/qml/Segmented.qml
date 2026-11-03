import QtQuick
import QtQuick.Layouts
import "."

// Small segmented switch. model: [{value, label}]
Rectangle {
    id: seg
    property var model: []
    property string current: ""
    signal picked(string value)

    color: Theme.sunken
    radius: Theme.radius
    implicitHeight: 30
    implicitWidth: row.implicitWidth + 6

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2
        Repeater {
            model: seg.model
            Rectangle {
                required property var modelData
                readonly property bool active: seg.current === modelData.value
                Layout.fillHeight: true
                implicitWidth: label.implicitWidth + 20
                radius: Theme.radius - 2
                color: active ? Theme.surface : (hover.hovered ? Theme.surfaceAlt : "transparent")
                border.color: active ? Theme.border : "transparent"
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.active ? Theme.text : Theme.muted
                    font.pixelSize: 12
                    font.weight: parent.active ? Font.DemiBold : Font.Normal
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: seg.picked(modelData.value) }
            }
        }
    }
}
