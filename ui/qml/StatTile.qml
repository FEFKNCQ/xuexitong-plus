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
    // Counter mode: animate the number instead of swapping text.
    property bool counter: false
    property int countValue: 0
    property real shownCount: countValue
    property int appearDelay: 0
    property bool appeared: false

    readonly property string display: counter ? String(Math.round(shownCount)) : value
    readonly property bool empty: !counter && value === ""

    color: Theme.surface
    radius: Theme.radiusLarge
    border.color: Theme.border
    implicitHeight: 76

    Behavior on shownCount { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    // Entrance.
    opacity: appeared ? 1 : 0
    transform: Translate {
        y: tile.appeared ? 0 : 12
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
    Timer {
        interval: Math.max(1, tile.appearDelay)
        running: !tile.appeared && tile.Window.window !== null && tile.Window.window.visible
        onTriggered: tile.appeared = true
    }

    // Brief accent flash whenever the value changes.
    Rectangle {
        id: flash
        anchors.fill: parent
        radius: parent.radius
        color: Theme.accentSoft
        opacity: 0
    }
    SequentialAnimation {
        id: pulse
        NumberAnimation { target: flash; property: "opacity"; to: 0.9; duration: 120 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 520; easing.type: Easing.OutCubic }
    }
    onValueChanged: if (appeared && value !== "") pulse.restart()
    onCountValueChanged: if (appeared) pulse.restart()

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
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
        Text {
            Layout.fillWidth: true
            text: tile.empty ? tile.placeholder : tile.display
            color: tile.empty ? Theme.faint : Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            ToolTip.visible: hover.hovered && tile.display.length > 12
            ToolTip.text: tile.display
            HoverHandler { id: hover }
        }
    }
}
