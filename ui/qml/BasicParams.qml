import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Card {
    id: card
    title: "基本参数"
    subtitle: controller.running ? "任务运行中，参数已锁定；停止后可修改" : "点击开始时自动保存"
    icon: ""

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 14
        rowSpacing: 8
        enabled: !controller.running

        Label { text: "课程 ID"; color: Theme.muted; font.pixelSize: 12; Layout.columnSpan: 2 }
        TextField {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            placeholderText: "留空则运行时选择课程；多个 ID 用英文逗号分隔"
            text: controller.courseList
            onTextEdited: controller.courseList = text
            selectByMouse: true
        }

        Label { text: "视频速度"; color: Theme.muted; font.pixelSize: 12 }
        Label { text: "并行章节数"; color: Theme.muted; font.pixelSize: 12 }
        ComboBox {
            Layout.fillWidth: true
            model: controller.speedOptions.map(v => v === "1" ? "标准 · 1×" : v + "×")
            currentIndex: Math.max(0, controller.speedOptions.indexOf(controller.speed))
            onActivated: index => controller.speed = controller.speedOptions[index]
        }
        SpinBox {
            Layout.fillWidth: true
            from: 1
            to: 8
            value: controller.jobs
            onValueModified: controller.jobs = value
        }

        Label { text: "未开放章节"; color: Theme.muted; font.pixelSize: 12; Layout.columnSpan: 2 }
        ComboBox {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            readonly property var values: ["retry", "continue"]
            model: ["等待后重试（适合前置章节未完成）", "跳过该章节，继续后续章节"]
            currentIndex: Math.max(0, values.indexOf(controller.notopenAction))
            onActivated: index => controller.notopenAction = values[index]
        }
    }
}
