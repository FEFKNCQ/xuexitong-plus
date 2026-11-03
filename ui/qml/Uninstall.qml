import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Styled uninstaller window (学习通PLUS.exe --uninstall).
ApplicationWindow {
    id: window
    width: 560
    height: 440
    minimumWidth: 560
    minimumHeight: 440
    maximumWidth: 560
    maximumHeight: 440
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: "卸载 " + uninstaller.appName

    readonly property string state: uninstaller.state

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: 8
        radius: 14
        color: Theme.surface
        border.color: Theme.border
        opacity: 0
        scale: 0.97
        Component.onCompleted: intro.start()
        ParallelAnimation {
            id: intro
            NumberAnimation { target: frame; property: "opacity"; to: 1; duration: Theme.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: frame; property: "scale"; to: 1; duration: Theme.slow; easing.type: Easing.OutCubic }
        }

        DragHandler {
            target: null
            onActiveChanged: if (active) window.startSystemMove()
        }

        IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            glyph: ""
            tip: "关闭"
            enabled: window.state !== "working"
            onClicked: Qt.quit()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 14

            RowLayout {
                spacing: 14
                Image {
                    source: uninstaller.iconUrl
                    sourceSize.width: 52
                    sourceSize.height: 52
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    mipmap: true
                    opacity: window.state === "done" ? 0.35 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.slow } }
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: window.state === "done" ? "已卸载 " + uninstaller.appName
                            : window.state === "error" ? "卸载没有完成" : "卸载 " + uninstaller.appName
                        color: Theme.text
                        font.family: Theme.uiFont
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                    Text {
                        text: uninstaller.version !== "" ? "版本 " + uninstaller.version : uninstaller.installDir
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 380
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: !uninstaller.installed
                    ? "当前运行的程序不是通过安装程序安装的（例如免安装版或开发版），无法在这里卸载。直接删除程序文件夹即可。"
                    : window.state === "done" ? "程序文件会在关闭此窗口后删除。感谢使用！"
                    : window.state === "error" ? uninstaller.errorText
                    : "将删除程序文件、开始菜单和桌面快捷方式，以及“应用和功能”中的条目。"
                color: window.state === "error" ? Theme.danger : Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 13
                lineHeight: 1.35
                wrapMode: Text.Wrap
            }

            ColumnLayout {
                visible: uninstaller.installed && window.state === "confirm"
                spacing: 6
                AppCheckBox {
                    id: clearAccount
                    text: "清除账号数据（账号、密码、cookies）"
                    checked: true
                    enabled: !removeAll.checked
                    opacity: enabled ? 1 : 0.5
                }
                AppCheckBox {
                    id: removeAll
                    text: "删除全部配置、日志和界面设置"
                }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 30
                    text: removeAll.checked ? "将删除整个配置目录 %APPDATA%\\ChaoxingDesktop"
                        : clearAccount.checked ? "其他设置和日志保留在 %APPDATA%\\ChaoxingDesktop"
                        : "账号和设置保留在 %APPDATA%\\ChaoxingDesktop，以后重新安装可以继续使用。"
                    color: removeAll.checked || !clearAccount.checked ? Theme.warning : Theme.faint
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    wrapMode: Text.WrapAnywhere
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
            }

            // Indeterminate bar while working.
            Rectangle {
                visible: window.state === "working"
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.sunken
                clip: true
                Rectangle {
                    width: parent.width * 0.3
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    NumberAnimation on x { from: -width; to: parent.width; duration: 1100; loops: Animation.Infinite; running: window.state === "working" }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                AppButton {
                    visible: window.state === "confirm" || window.state === "error"
                    text: "取消"
                    onClicked: Qt.quit()
                }
                AppButton {
                    visible: uninstaller.installed && window.state === "confirm"
                    text: "卸载"
                    glyph: ""
                    kind: "danger"
                    onClicked: uninstaller.uninstall(clearAccount.checked || removeAll.checked, removeAll.checked)
                }
                AppButton {
                    visible: window.state === "done"
                    text: "完成"
                    kind: "primary"
                    onClicked: Qt.quit()
                }
            }
        }
    }
}
