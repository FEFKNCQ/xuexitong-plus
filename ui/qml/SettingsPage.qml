import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: page
    signal guideRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.gap

        ColumnLayout {
            spacing: 2
            Text { text: "设置"; color: Theme.text; font.pixelSize: 22; font.weight: Font.DemiBold }
            Text { text: "账号、运行策略与外观。基本参数在运行面板中调整。"; color: Theme.muted; font.pixelSize: 12 }
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: Math.min(scroll.availableWidth, 880)
                spacing: Theme.gap

                Card {
                    Layout.fillWidth: true
                    title: "账号"
                    subtitle: "账号信息只保存在本机配置目录（明文）"
                    icon: ""
                    enabled: !controller.running

                    Switch {
                        text: "使用本地 cookies 登录"
                        checked: controller.useCookies
                        onToggled: controller.useCookies = checked
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: controller.useCookies
                        text: "将 cookies.txt 放在配置目录中；开启后账号密码不参与登录。"
                        color: Theme.muted
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 8
                        enabled: !controller.useCookies
                        Label { text: "账号"; color: Theme.muted }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "手机号或学习通账号"
                            text: controller.username
                            onTextEdited: controller.username = text
                            selectByMouse: true
                        }
                        Label { text: "密码"; color: Theme.muted }
                        RowLayout {
                            Layout.fillWidth: true
                            TextField {
                                id: passwordField
                                Layout.fillWidth: true
                                placeholderText: "密码"
                                echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                                text: controller.password
                                onTextEdited: controller.password = text
                            }
                            IconButton {
                                id: reveal
                                checkable: true
                                glyph: checked ? "" : ""
                                tip: checked ? "隐藏密码" : "显示密码"
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    title: "运行"
                    subtitle: "任务失败或章节未开放时的重试等待"
                    icon: ""
                    enabled: !controller.running
                    RowLayout {
                        spacing: 12
                        Label { text: "重试间隔（秒）"; color: Theme.muted }
                        SpinBox {
                            id: retrySpin
                            from: 0
                            to: 600
                            stepSize: 5
                            editable: true
                            value: Math.round(controller.retryInterval * 10)
                            textFromValue: (v, locale) => (v / 10).toFixed(1)
                            valueFromText: (t, locale) => Math.round(parseFloat(t) * 10)
                            onValueModified: controller.retryInterval = value / 10
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    title: "章节学习次数"
                    subtitle: "完成所选课程的任务点后，继续轮询章节增加学习次数"
                    icon: ""
                    enabled: !controller.running
                    Switch {
                        text: "完成课程后增加章节学习次数"
                        checked: controller.addLearningCount
                        onToggled: controller.addLearningCount = checked
                    }
                    RowLayout {
                        spacing: 12
                        enabled: controller.addLearningCount
                        Label { text: "目标总次数"; color: Theme.muted }
                        SpinBox {
                            from: 1
                            to: 10000
                            editable: true
                            value: controller.targetCount
                            onValueModified: controller.targetCount = value
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    title: "外观"
                    icon: ""
                    Segmented {
                        model: [
                            { value: "system", label: "跟随系统" },
                            { value: "light", label: "浅色" },
                            { value: "dark", label: "深色" }
                        ]
                        current: controller.themeMode
                        onPicked: value => controller.themeMode = value
                    }
                }

                Card {
                    Layout.fillWidth: true
                    title: "关于"
                    icon: ""
                    Text {
                        Layout.fillWidth: true
                        text: controller.appName + "  v" + controller.version
                        color: Theme.text
                        font.pixelSize: 13
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "基于开源项目 Samueli924/chaoxing，遵循 GPL-3.0 协议，禁止用于盈利。\n配置、cookies 和日志位于：" + controller.dataDir
                        color: Theme.muted
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                    }
                    RowLayout {
                        spacing: 8
                        IconButton {
                            glyph: ""
                            text: "打开配置目录"
                            flat: false
                            onClicked: controller.openDataDir()
                        }
                        IconButton {
                            glyph: ""
                            text: "重新查看开始引导"
                            flat: false
                            enabled: !controller.running
                            onClicked: page.guideRequested()
                        }
                    }
                }

                Item { implicitHeight: 4 }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: Theme.radiusLarge
            color: Theme.surface
            border.color: controller.dirty ? Theme.accent : Theme.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                Text {
                    Layout.fillWidth: true
                    text: controller.running ? "任务运行中，设置已锁定" : (controller.dirty ? "有未保存的修改" : "所有设置已保存到本机")
                    color: controller.dirty ? Theme.accent : Theme.muted
                    font.pixelSize: 12
                }
                Button {
                    text: "撤销修改"
                    enabled: controller.dirty && !controller.running
                    onClicked: controller.revertConfig()
                }
                Button {
                    text: "保存"
                    highlighted: true
                    enabled: controller.dirty && !controller.running
                    onClicked: controller.saveConfig()
                }
            }
        }
    }
}
