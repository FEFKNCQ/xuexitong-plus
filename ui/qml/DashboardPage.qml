import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: page
    property bool overlayOpen: false
    property bool accountConfigured: true
    signal stopRequested()
    signal settingsRequested()

    function start() {
        if (!accountConfigured) {
            settingsRequested()
            return
        }
        controller.startRun()
    }

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
                    Text { text: "运行面板"; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 22; font.weight: Font.DemiBold }
                    Text {
                        text: controller.useCookies ? "使用 cookies 登录" : (controller.username !== "" ? "账号 " + controller.username : "尚未填写账号")
                        color: page.accountConfigured ? Theme.muted : Theme.warning
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                }
                Item { Layout.fillWidth: true }
                StatusPill { text: controller.status; kind: controller.statusKind }

                // Start / stop swap with a crossfade.
                Item {
                    implicitWidth: Math.max(startButton.implicitWidth, stopButton.implicitWidth)
                    implicitHeight: startButton.implicitHeight
                    AppButton {
                        id: startButton
                        anchors.right: parent.right
                        text: "开始运行"
                        glyph: ""
                        kind: "primary"
                        opacity: controller.running ? 0 : 1
                        visible: opacity > 0.01
                        enabled: !controller.running
                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                        onClicked: page.start()
                    }
                    AppButton {
                        id: stopButton
                        anchors.right: parent.right
                        text: "停止"
                        glyph: ""
                        kind: "danger"
                        opacity: controller.running ? 1 : 0
                        visible: opacity > 0.01
                        enabled: controller.running
                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                        onClicked: page.stopRequested()
                    }
                }
            }

            // Reminder shown until an account (or cookies login) is configured.
            Rectangle {
                id: accountBanner
                Layout.fillWidth: true
                Layout.preferredHeight: page.accountConfigured ? 0 : 50
                Layout.topMargin: page.accountConfigured ? -Theme.gap : 0
                clip: true
                radius: Theme.radiusLarge
                color: Theme.warningSoft
                border.color: Theme.warning
                opacity: page.accountConfigured ? 0 : 1
                Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                Behavior on Layout.topMargin { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 10
                    Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.warning }
                    Text {
                        Layout.fillWidth: true
                        text: "还没有配置账号。请到“设置 → 账号”填写账号密码，或开启 cookies 登录。"
                        color: Theme.text
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    AppButton {
                        text: "去设置"
                        glyph: ""
                        implicitHeight: 32
                        onClicked: page.settingsRequested()
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 10
                rowSpacing: 10
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; appearDelay: 60; label: "当前课程"; icon: ""; value: controller.currentCourse }
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; appearDelay: 110; label: "当前章节"; icon: ""; value: controller.currentChapter }
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; appearDelay: 160; label: "已完成任务"; icon: ""; countValue: controller.completedCount; counter: true }
                StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; appearDelay: 210; label: "运行时长"; icon: ""; value: controller.running || controller.completedCount > 0 ? controller.elapsed : ""; placeholder: "00:00" }
            }

            BasicParams { Layout.fillWidth: true; appearDelay: 260 }

            TaskList {
                Layout.fillWidth: true
                Layout.preferredHeight: log.expanded ? 190 : 0
                Layout.fillHeight: !log.expanded
                appearDelay: 320
            }

            LogPanel {
                id: log
                Layout.fillWidth: true
                Layout.fillHeight: expanded
                appearDelay: 380
            }
        }

        // ---------- right: read-only visual panel ----------
        VisualPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            suspended: page.overlayOpen
            appearDelay: 200
        }
    }
}
