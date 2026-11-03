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

    color: Theme.surface
    radius: Theme.radiusLarge
    border.color: Theme.border
    border.width: 1
    implicitHeight: column.implicitHeight + padding * 2

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 12

        RowLayout {
            visible: card.title !== "" || actionsRow.children.length > 0
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
