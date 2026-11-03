import QtQuick
import QtQuick.Layouts
import "."

// Read-only rendering of one filled-in question. Nothing here reacts to input.
Rectangle {
    id: card
    property var question: ({})
    radius: Theme.radius
    color: Theme.surfaceAlt
    border.color: Theme.border
    implicitHeight: column.implicitHeight + 24

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Text {
                text: card.question.index + "."
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Rectangle {
                radius: 4
                color: Theme.accentSoft
                implicitWidth: typeText.implicitWidth + 12
                implicitHeight: 20
                Text { id: typeText; anchors.centerIn: parent; text: card.question.typeLabel || ""; color: Theme.accent; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                radius: 4
                color: card.question.fromBank ? Theme.successSoft : Theme.warningSoft
                implicitWidth: srcText.implicitWidth + 12
                implicitHeight: 20
                Text {
                    id: srcText
                    anchors.centerIn: parent
                    text: card.question.fromBank ? "题库匹配" : "随机作答"
                    color: card.question.fromBank ? Theme.success : Theme.warning
                    font.pixelSize: 11
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: card.question.title || ""
            color: Theme.text
            font.pixelSize: 13
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }

        Repeater {
            model: card.question.options || []
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: optText.implicitHeight + 14
                radius: 6
                property bool marked: false
                color: marked ? Theme.accentSoft : Theme.surface
                border.color: marked ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.slow } }
                Behavior on border.color { ColorAnimation { duration: Theme.slow } }
                Timer { interval: 420; running: modelData.selected; onTriggered: parent.marked = true }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    Text {
                        text: parent.parent.marked ? "" : ""
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: parent.parent.marked ? Theme.accent : Theme.faint
                        Behavior on color { ColorAnimation { duration: Theme.slow } }
                    }
                    Text {
                        id: optText
                        Layout.fillWidth: true
                        text: modelData.text
                        color: Theme.text
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        Rectangle {
            visible: (card.question.options || []).length === 0
            Layout.fillWidth: true
            implicitHeight: answerText.implicitHeight + 14
            radius: 6
            color: Theme.surface
            border.color: Theme.border
            Text {
                id: answerText
                anchors.fill: parent
                anchors.margins: 7
                anchors.leftMargin: 10
                text: card.question.answerText ? card.question.answerText : "（未填写）"
                color: card.question.answerText ? Theme.text : Theme.faint
                font.pixelSize: 12
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }
    }
}
