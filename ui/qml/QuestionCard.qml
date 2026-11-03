import QtQuick
import QtQuick.Layouts
import "."

// Read-only rendering of one filled-in question. Nothing here reacts to input.
Rectangle {
    id: card
    property var question: ({})
    // When this card's answer is revealed (after its entrance), in ms.
    property int revealDelay: 0
    property bool revealed: !Theme.motion

    radius: Theme.radius
    color: Theme.surfaceAlt
    border.color: hover.hovered ? Theme.borderStrong : Theme.border
    implicitHeight: column.implicitHeight + 24
    Behavior on color { ColorAnimation { duration: Theme.slow } }
    Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    HoverHandler { id: hover }

    Timer {
        interval: Math.max(1, card.revealDelay + 260)
        running: !card.revealed
        onTriggered: card.revealed = true
    }

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
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Rectangle {
                radius: 4
                color: Theme.accentSoft
                implicitWidth: typeText.implicitWidth + 12
                implicitHeight: 20
                Behavior on color { ColorAnimation { duration: Theme.slow } }
                Text { id: typeText; anchors.centerIn: parent; text: card.question.typeLabel || ""; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                radius: 4
                color: card.question.pending ? Theme.sunken : card.question.fromBank ? Theme.successSoft : Theme.warningSoft
                implicitWidth: srcText.implicitWidth + 12
                implicitHeight: 20
                opacity: card.revealed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                Behavior on color { ColorAnimation { duration: Theme.slow } }
                Text {
                    id: srcText
                    anchors.centerIn: parent
                    text: card.question.pending ? "查找中" : card.question.fromBank ? "题库匹配" : "随机作答"
                    color: card.question.pending ? Theme.muted : card.question.fromBank ? Theme.success : Theme.warning
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: card.question.title || ""
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 13
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }

        Repeater {
            model: card.question.options || []
            Rectangle {
                id: option
                required property var modelData
                readonly property bool marked: card.revealed && modelData.selected
                Layout.fillWidth: true
                implicitHeight: optText.implicitHeight + 14
                radius: 6
                color: marked ? Theme.accentSoft : Theme.surface
                border.color: marked ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.slow } }
                Behavior on border.color { ColorAnimation { duration: Theme.slow } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    Text {
                        text: option.marked ? "" : ""
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: option.marked ? Theme.accent : Theme.faint
                        scale: option.marked ? 1 : 0.92
                        Behavior on color { ColorAnimation { duration: Theme.slow } }
                        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
                    }
                    Text {
                        id: optText
                        Layout.fillWidth: true
                        text: modelData.text
                        color: Theme.text
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        // Fill-in / short answers type out character by character.
        Rectangle {
            id: answerBox
            readonly property string full: card.question.answerText || ""
            property int shown: 0
            visible: (card.question.options || []).length === 0
            Layout.fillWidth: true
            implicitHeight: answerText.implicitHeight + 14
            radius: 6
            color: Theme.surface
            border.color: answerBox.full !== "" && answerBox.shown > 0 ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.slow } }
            Behavior on border.color { ColorAnimation { duration: Theme.slow } }
            onFullChanged: shown = Theme.motion ? 0 : full.length
            Component.onCompleted: shown = Theme.motion ? 0 : full.length
            Timer {
                // Short answers type at a steady pace; long ones finish within about 1.2 s.
                interval: Math.max(16, Math.min(45, 1200 / Math.max(1, answerBox.full.length)))
                repeat: true
                running: card.revealed && answerBox.visible && answerBox.shown < answerBox.full.length
                onTriggered: answerBox.shown += 1
            }
            Text {
                id: answerText
                anchors.fill: parent
                anchors.margins: 7
                anchors.leftMargin: 10
                text: answerBox.full !== "" ? answerBox.full.substring(0, answerBox.shown) + (answerBox.shown < answerBox.full.length ? "▍" : "")
                                            : "（未填写）"
                color: answerBox.full !== "" ? Theme.text : Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 12
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }
    }
}
