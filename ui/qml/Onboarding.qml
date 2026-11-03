import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// First-run guide: 欢迎 > 免责声明 > 账号/密码 > 开始使用
Rectangle {
    id: guide
    signal completed()

    property int step: 0
    property bool agreed: false
    readonly property var steps: ["欢迎", "免责声明", "账号", "开始使用"]
    readonly property bool accountReady: controller.useCookies
        || (controller.username.trim() !== "" && controller.password !== "")

    color: Theme.bg

    // Swallow input so nothing behind the guide reacts.
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

    function next() {
        if (step === 2 && !controller.saveConfig())
            return
        if (step < steps.length - 1)
            step += 1
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(720, parent.width - 80)
        height: Math.min(600, parent.height - 80)
        radius: 16
        color: Theme.surface
        border.color: Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 20

            // ---- step indicator ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: guide.steps
                    RowLayout {
                        required property string modelData
                        required property int index
                        spacing: 8
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: index <= guide.step ? Theme.accent : Theme.surfaceAlt
                            border.color: index <= guide.step ? Theme.accent : Theme.border
                            Text {
                                anchors.centerIn: parent
                                text: index < guide.step ? "" : String(index + 1)
                                font.family: index < guide.step ? Theme.iconFont : font.family
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: index <= guide.step ? Theme.accentText : Theme.muted
                            }
                        }
                        Text {
                            text: modelData
                            color: index === guide.step ? Theme.text : Theme.muted
                            font.pixelSize: 13
                            font.weight: index === guide.step ? Font.DemiBold : Font.Normal
                        }
                        Rectangle {
                            visible: index < guide.steps.length - 1
                            Layout.preferredWidth: 28
                            height: 2
                            radius: 1
                            color: index < guide.step ? Theme.accent : Theme.border
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // ---- pages ----
            StackLayout {
                id: pages
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: guide.step

                // 0 欢迎
                ColumnLayout {
                    spacing: 16
                    Item { Layout.preferredHeight: 6 }
                    Image {
                        source: controller.iconUrl
                        sourceSize.width: 84
                        sourceSize.height: 84
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 84
                        mipmap: true
                    }
                    Text { text: "欢迎使用 " + controller.appName; color: Theme.text; font.pixelSize: 26; font.weight: Font.Bold }
                    Text {
                        Layout.fillWidth: true
                        text: "用几步完成初始设置。之后可以随时在“设置”页修改。"
                        color: Theme.muted
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: [
                            { glyph: "", text: "运行面板：课程、章节、任务进度和日志一目了然" },
                            { glyph: "", text: "可视化面板：只读查看当前视频和章节检测内容" },
                            { glyph: "", text: "配置、cookies 和日志只保存在本机" }
                        ]
                        RowLayout {
                            required property var modelData
                            spacing: 12
                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: Theme.accentSoft
                                Text { anchors.centerIn: parent; text: modelData.glyph; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.accent }
                            }
                            Text { text: modelData.text; color: Theme.text; font.pixelSize: 13 }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                // 1 免责声明
                ColumnLayout {
                    spacing: 12
                    Text { text: "免责声明"; color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radius
                        color: Theme.sunken
                        ScrollView {
                            id: disclaimerScroll
                            anchors.fill: parent
                            anchors.margins: 14
                            clip: true
                            contentWidth: availableWidth
                            Text {
                                width: disclaimerScroll.availableWidth
                                color: Theme.text
                                font.pixelSize: 13
                                lineHeight: 1.35
                                wrapMode: Text.Wrap
                                text: "1. 本软件基于开源项目 Samueli924/chaoxing，遵循 GPL-3.0 协议，仅供学习交流使用，禁止用于任何盈利用途，修改或衍生版本必须同样开源。\n\n"
                                    + "2. 本软件与超星、学习通官方无任何关联，不代表其立场。\n\n"
                                    + "3. 使用自动化工具可能违反学习通的用户协议及所在学校的课程或学术诚信规定，可能导致账号受限、封禁或成绩作废。是否使用、如何使用由你自行判断，相关后果由你自行承担。\n\n"
                                    + "4. 账号、密码和 cookies 以明文保存在本机 %APPDATA%\\ChaoxingDesktop 目录，请自行保管，不要在公共电脑上使用。\n\n"
                                    + "5. 本软件按“现状”提供，不对运行结果、答题正确率或任何直接、间接损失作任何保证或承担责任。\n\n"
                                    + "6. 他人或组织使用本软件进行的任何违法违规行为，与作者无关。"
                            }
                        }
                    }
                    CheckBox {
                        text: "我已阅读并同意以上声明"
                        checked: guide.agreed
                        onToggled: guide.agreed = checked
                    }
                }

                // 2 账号
                ColumnLayout {
                    spacing: 14
                    Text { text: "登录信息"; color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold }
                    Text {
                        Layout.fillWidth: true
                        text: "填写学习通账号和密码，或使用本地 cookies 登录。信息只保存在本机配置目录（明文）。"
                        color: Theme.muted
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                    Switch {
                        text: "使用本地 cookies 登录"
                        checked: controller.useCookies
                        onToggled: controller.useCookies = checked
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: controller.useCookies
                        text: "请把 cookies.txt 放入配置目录：" + controller.dataDir
                        color: Theme.muted
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 10
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
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "密码"
                            echoMode: TextInput.Password
                            text: controller.password
                            onTextEdited: controller.password = text
                            onAccepted: if (guide.accountReady) guide.next()
                        }
                    }
                    IconButton {
                        visible: controller.useCookies
                        glyph: ""
                        text: "打开配置目录"
                        flat: false
                        onClicked: controller.openDataDir()
                    }
                    Item { Layout.fillHeight: true }
                }

                // 3 开始使用
                ColumnLayout {
                    spacing: 14
                    Item { Layout.preferredHeight: 6 }
                    Rectangle {
                        width: 64; height: 64; radius: 32
                        color: Theme.successSoft
                        Text { anchors.centerIn: parent; text: ""; font.family: Theme.iconFont; font.pixelSize: 28; color: Theme.success }
                    }
                    Text { text: "设置完成"; color: Theme.text; font.pixelSize: 26; font.weight: Font.Bold }
                    Text {
                        Layout.fillWidth: true
                        text: (controller.useCookies ? "将使用本地 cookies 登录。" : "已保存账号 " + controller.username + "。")
                            + "\n进入运行面板后，在左侧“基本参数”里选择课程和速度，再点击“开始运行”。"
                        color: Theme.muted
                        font.pixelSize: 14
                        lineHeight: 1.3
                        wrapMode: Text.Wrap
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // ---- footer ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    visible: guide.step > 0 && guide.step < guide.steps.length - 1
                    text: "上一步"
                    onClicked: guide.step -= 1
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: guide.step === 1 && !guide.agreed
                    text: "需要同意声明后才能继续"
                    color: Theme.faint
                    font.pixelSize: 12
                }
                Text {
                    visible: guide.step === 2 && !guide.accountReady
                    text: "请填写账号和密码"
                    color: Theme.faint
                    font.pixelSize: 12
                }
                Button {
                    visible: guide.step < guide.steps.length - 1
                    text: guide.step === 0 ? "开始设置" : "下一步"
                    highlighted: true
                    enabled: (guide.step !== 1 || guide.agreed) && (guide.step !== 2 || guide.accountReady)
                    onClicked: guide.next()
                }
                Button {
                    visible: guide.step === guide.steps.length - 1
                    text: "开始使用"
                    highlighted: true
                    onClicked: {
                        controller.finishOnboarding()
                        guide.completed()
                    }
                }
            }
        }
    }
}
