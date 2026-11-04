import QtQuick
import QtQuick.Layouts
import "."

// Rounded surface with an optional title row; children go into the body column.
Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property int padding: Theme.pad
    default property alias content: body.data
    property alias actions: actionsRow.data
    property alias bodySpacing: body.spacing
    // Entrance: fade + lift once the window is shown, staggered by appearDelay (ms).
    property int appearDelay: 0
    property bool appeared: false

    opacity: appeared ? 1 : 0
    transform: Translate {
        y: card.appeared ? 0 : 14
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
    Timer {
        interval: Math.max(1, card.appearDelay)
        running: !card.appeared && card.Window.window !== null && card.Window.window.visible
        onTriggered: card.appeared = true
    }

    color: Theme.surface
    radius: Theme.radiusLarge
    // Border darkens slightly on hover; colours fade when the theme changes.
    border.color: cardHover.hovered ? Theme.borderStrong : Theme.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: Theme.slow } }
    Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    HoverHandler { id: cardHover }
    implicitHeight: column.implicitHeight + padding * 2

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 12

        RowLayout {
            visible: card.title !== "" || actionsRow.visibleChildren.length > 0
            Layout.fillWidth: true
            spacing: 10

            Text {
                visible: card.icon !== ""
                text: card.icon
                font.family: Theme.iconFont
                font.pixelSize: 16
                color: Theme.accent
            }
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Text {
                    text: card.title
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: card.subtitle !== ""
                    text: card.subtitle
                    color: Theme.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            RowLayout {
                id: actionsRow
                spacing: 6
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
        }
    }
}
