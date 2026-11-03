import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Card {
    id: card
    property bool expanded: true
    title: "运行日志"
    icon: ""
    bodySpacing: 8

    actions: [
        Segmented {
            visible: card.expanded
            model: [
                { value: "ALL", label: "全部" },
                { value: "INFO", label: "信息" },
                { value: "WARNING", label: "警告" },
                { value: "ERROR", label: "错误" }
            ]
            current: controller.logModel.levelFilter
            onPicked: value => controller.logModel.levelFilter = value
        },
        IconButton {
            visible: card.expanded
            glyph: ""
            tip: "复制当前日志"
            onClicked: {
                clipboardHelper.text = controller.logModel.visibleText()
                clipboardHelper.selectAll()
                clipboardHelper.copy()
            }
        },
        IconButton {
            visible: card.expanded
            glyph: ""
            tip: "清空日志"
            onClicked: controller.logModel.clear()
        },
        IconButton {
            glyph: card.expanded ? "" : ""
            tip: card.expanded ? "收起" : "展开"
            onClicked: card.expanded = !card.expanded
        }
    ]

    TextEdit { id: clipboardHelper; visible: false }

    Rectangle {
        visible: card.expanded
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80
        radius: Theme.radius
        color: Theme.sunken

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            model: controller.logModel
            boundsBehavior: Flickable.StopAtBounds
            property bool follow: true
            onMovementEnded: follow = atYEnd
            onCountChanged: if (follow) Qt.callLater(positionViewAtEnd)
            ScrollBar.vertical: ScrollBar {}

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
                    NumberAnimation { property: "x"; from: -8; to: 0; duration: Theme.normal; easing.type: Easing.OutCubic }
                }
            }

            delegate: RowLayout {
                required property string level
                required property string message
                required property string time
                width: ListView.view.width - 10
                spacing: 8
                Text {
                    text: time
                    color: Theme.faint
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 54
                }
                Text {
                    text: level === "SUCCESS" ? "OK" : level.substring(0, 4)
                    color: Theme.levelColor(level)
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 32
                }
                Text {
                    Layout.fillWidth: true
                    text: message
                    color: level === "ERROR" || level === "CRITICAL" ? Theme.danger : Theme.text
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    wrapMode: Text.WrapAnywhere
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "准备就绪。设置好参数后点击“开始运行”。"
                color: Theme.faint
                font.pixelSize: 12
            }
        }
    }
}
