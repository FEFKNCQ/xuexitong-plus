import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: page
    property bool overlayOpen: false
    signal stopRequested()

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        // ---------- left: dashboard + basic parameters ----------
        ColumnLayout {
            Layout.preferredWidth: Math.max(470, page.width * 0.44)
            Layout.maximumWidth: 640
            Layout.fillHeight: true
            spacing: Theme.gap

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    spacing: 2
                    Text { text: "运行面板"; color: Theme.text; font.pixelSize: 22; font.weight: Font.DemiBold }
                    Text {
                        text: controller.useCookies ? "使用 cookies 登录" : (controller.username !== "" ? "账号 " + controller.username : "尚未填写账号")
                        color: Theme.muted
                        font.pixelSize: 12
                    }
                }
                Item { Layout.fillWidth: true }
                StatusPill { text: controller.status; kind: controller.statusKind }
                Button {
                    visible: controller.running
                    text: "停止"
                    icon.source: ""
                    onClicked: page.stopRequested()
                }
                Button {
                    visible: !controller.running
                    text: "开始运行"
                    highlighted: true
                    onClicked: controller.startRun()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 10
                rowSpacing: 10
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "当前课程"; icon: ""; value: controller.currentCourse }
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "当前章节"; icon: ""; value: controller.currentChapter }
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "已完成任务"; icon: ""; value: String(controller.completedCount); placeholder: "0" }
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "运行时长"; icon: ""; value: controller.running || controller.completedCount > 0 ? controller.elapsed : "" ; placeholder: "00:00" }
            }

            BasicParams { Layout.fillWidth: true }

            TaskList {
                Layout.fillWidth: true
                Layout.preferredHeight: log.expanded ? 190 : 0
                Layout.fillHeight: !log.expanded
            }

            LogPanel {
                id: log
                Layout.fillWidth: true
                Layout.fillHeight: expanded
            }
        }

        // ---------- right: read-only visual panel ----------
        VisualPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            suspended: page.overlayOpen
        }
    }
}
