import QtQuick
import QtQuick.Layouts
import "."

// Segmented switch with a highlight that slides to the picked segment. model: [{value, label}]
Rectangle {
    id: seg
    property var model: []
    property string current: ""
    signal picked(string value)

    readonly property int currentIndex: {
        for (let i = 0; i < model.length; ++i)
            if (model[i].value === current) return i
        return -1
    }

    color: Theme.sunken
    radius: Theme.radius
    implicitHeight: 30
    implicitWidth: row.implicitWidth + 6

    Rectangle {
        id: highlight
        readonly property Item target: seg.currentIndex >= 0 ? repeater.itemAt(seg.currentIndex) : null
        visible: target !== null
        x: target ? row.x + target.x : 0
        y: 3
        width: target ? target.width : 0
        height: seg.height - 6
        radius: Theme.radius - 2
        color: Theme.surface
        border.color: Theme.border
        Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2
        Repeater {
            id: repeater
            model: seg.model
            Item {
                required property var modelData
                required property int index
                readonly property bool active: seg.currentIndex === index
                Layout.fillHeight: true
                implicitWidth: label.implicitWidth + 20
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius - 2
                    color: !parent.active && hover.hovered ? Theme.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.active ? Theme.text : Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: parent.active ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: seg.picked(modelData.value) }
            }
        }
    }
}
