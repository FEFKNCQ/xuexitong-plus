import QtQuick
import QtQuick.Layouts
import "."

// Read-only visual panel: current video on top, the chapter quiz below.
Card {
    id: card
    property bool suspended: false
    readonly property var work: controller.work
    readonly property bool hasWork: !!(work && work.questions && work.questions.length > 0)

    title: "可视化面板"
    subtitle: "当前视频与章节检测 · 只读"
    icon: ""
    bodySpacing: 10

    actions: [
        Rectangle {
            radius: 10
            color: Theme.surfaceAlt
            border.color: Theme.border
            implicitWidth: lockRow.implicitWidth + 16
            implicitHeight: 22
            Behavior on color { ColorAnimation { duration: Theme.slow } }
            Row {
                id: lockRow
                anchors.centerIn: parent
                spacing: 4
                Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 10; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "只读"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    ]

    // ---------- top: video ----------
    Item {
        id: videoArea
        Layout.fillWidth: true
        // 16:9, but never more than 45% of the panel so the quiz keeps room below.
        Layout.preferredHeight: Math.min(width * 9 / 16, card.height * 0.45)
        VideoView {
            anchors.fill: parent
            suspended: card.suspended
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: ""
            font.family: Theme.iconFont
            font.pixelSize: 11
            color: Theme.faint
        }
        Text {
            Layout.fillWidth: true
            text: controller.videoTitle !== "" ? controller.videoTitle + " · 静音" : "视频预览静音，播放、进度、右键和键盘操作均已禁用"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 11
            elide: Text.ElideMiddle
        }
    }

    // ---------- divider: quiz header ----------
    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Behavior on color { ColorAnimation { duration: Theme.slow } } }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.accent }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: card.hasWork ? "章节检测 · " + card.work.title : "章节检测"
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                text: card.hasWork ? "共 " + card.work.questions.length + " 题 · 题库覆盖率 " + card.work.coverRate + "%" : "运行到章节检测时，下方会显示题目和填写的答案"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
        }
        StatusPill {
            visible: controller.workStatus !== ""
            text: controller.workStatus
            kind: controller.workStatus.indexOf("失败") >= 0 ? "error"
                : (controller.workStatus === "已提交" || controller.workStatus === "已保存") ? "done" : "running"
        }
    }
    // Coverage bar: grows from 0 each time a new quiz arrives.
    Rectangle {
        Layout.fillWidth: true
        height: 4
        radius: 2
        color: Theme.border
        visible: card.hasWork
        Rectangle {
            id: coverFill
            // Animate a 0..1 fraction (not a pixel width) so it is right however the bar is sized.
            property real fill: 0
            readonly property real target: card.hasWork ? card.work.coverRate / 100 : 0
            width: parent.width * fill
            height: parent.height
            radius: 2
            color: Theme.success
            NumberAnimation {
                id: coverGrow
                target: coverFill
                property: "fill"
                duration: Theme.slow * 2
                easing.type: Easing.OutCubic
            }
            function replay() {
                coverGrow.stop()
                fill = 0
                coverGrow.to = target
                coverGrow.start()
            }
            // Replay only when a different quiz arrives (status updates re-send the same quiz).
            readonly property string quizKey: card.hasWork
                ? card.work.title + "|" + card.work.questions.length + "|" + card.work.coverRate : ""
            onQuizKeyChanged: if (quizKey !== "") replay()
        }
    }

    // ---------- bottom: questions ----------
    WorkView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 120
        compactHeader: true
    }
}
