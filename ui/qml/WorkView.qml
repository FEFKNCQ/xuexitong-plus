import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Read-only view of the chapter quiz the worker is filling in.
Rectangle {
    id: root
    readonly property var work: controller.work
    readonly property bool hasWork: !!(work && work.questions && work.questions.length > 0)
    color: Theme.sunken
    radius: Theme.radius

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        visible: root.hasWork

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.hasWork ? root.work.title : ""
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: root.hasWork ? "共 " + root.work.questions.length + " 题 · 题库覆盖率 " + root.work.coverRate + "%" : ""
                    color: Theme.muted
                    font.pixelSize: 12
                }
            }
            StatusPill {
                text: controller.workStatus
                kind: controller.workStatus.indexOf("失败") >= 0 ? "error"
                    : (controller.workStatus === "已提交" || controller.workStatus === "已保存") ? "done" : "running"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Theme.border
            Rectangle {
                width: parent.width * (root.hasWork ? root.work.coverRate : 0) / 100
                height: parent.height
                radius: 2
                color: Theme.success
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.hasWork ? root.work.questions : []
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: QuestionCard {
                required property var modelData
                width: ListView.view.width - 10
                question: modelData
            }
            onModelChanged: positionViewAtBeginning()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.hasWork
        spacing: 8
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: ""
            font.family: Theme.iconFont
            font.pixelSize: 28
            color: Theme.faint
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "暂无答题内容"
            color: Theme.muted
            font.pixelSize: 14
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "运行到章节检测时，这里会显示题目和填写的答案"
            color: Theme.faint
            font.pixelSize: 12
        }
    }
}
