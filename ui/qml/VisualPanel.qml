import QtQuick
import QtQuick.Layouts
import "."

Card {
    id: card
    property bool suspended: false
    title: "可视化面板"
    subtitle: controller.visualMode === "video"
        ? (controller.videoTitle !== "" ? controller.videoTitle : "当前视频任务 · 静音")
        : "章节检测 · 自动填写"
    icon: ""

    actions: [
        Rectangle {
            radius: 10
            color: Theme.surfaceAlt
            border.color: Theme.border
            implicitWidth: lockRow.implicitWidth + 16
            implicitHeight: 22
            Row {
                id: lockRow
                anchors.centerIn: parent
                spacing: 4
                Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 10; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "只读"; color: Theme.muted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            }
        },
        Segmented {
            model: [{ value: "video", label: "视频" }, { value: "work", label: "答题" }]
            current: controller.visualMode
            onPicked: value => controller.visualMode = value
        }
    ]

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: controller.visualMode === "work" ? 1 : 0

        Item {
            VideoView {
                id: video
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: parent.width
                height: Math.min(parent.height, parent.width * 9 / 16)
                suspended: card.suspended
            }
            Text {
                anchors.top: video.bottom
                anchors.topMargin: 10
                width: parent.width
                text: "预览画面静音，只用于查看当前任务视频；播放、进度、右键和键盘操作均已禁用。"
                color: Theme.faint
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }
        WorkView {}
    }
}
