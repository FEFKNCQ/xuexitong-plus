import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// 学习通PLUS uninstaller (学习通PLUS.exe --uninstall), laid out like the setup wizard:
// 确认 > 卸载选项 > 正在卸载 > 完成
ApplicationWindow {
    id: window
    width: 820
    height: 560
    minimumWidth: 820
    minimumHeight: 560
    maximumWidth: 820
    maximumHeight: 560
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: "卸载 " + uninstaller.appName

    property int step: 0
    readonly property bool busy: uninstaller.state === "working"
    readonly property bool ok: uninstaller.state === "done"
    readonly property var steps: ["确认", "卸载选项", "正在卸载", "完成"]

    function go(i) { step = i }

    Connections {
        target: uninstaller
        function onStateChanged() {
            if (uninstaller.state === "working") window.go(2)
            else if (uninstaller.state === "done" || uninstaller.state === "error") window.go(3)
        }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: 8
        radius: 14
        color: Theme.surface
        border.color: Theme.border
        clip: true
        opacity: 0
        scale: 0.97
        Component.onCompleted: intro.start()
        ParallelAnimation {
            id: intro
            NumberAnimation { target: frame; property: "opacity"; to: 1; duration: Theme.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: frame; property: "scale"; to: 1; duration: Theme.slow; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- left: brand + steps ----------
            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                color: Theme.pane

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 6

                    Image {
                        source: uninstaller.iconUrl
                        sourceSize.width: 64
                        sourceSize.height: 64
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        mipmap: true
                        opacity: window.ok ? 0.35 : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.slow } }
                    }
                    Text { Layout.topMargin: 10; text: uninstaller.appName; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 20; font.weight: Font.Bold }
                    Text {
                        text: (uninstaller.version !== "" ? "版本 " + uninstaller.version + " · " : "") + "卸载程序"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }

                    Item { Layout.preferredHeight: 26 }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: stepColumn.implicitHeight
                        // Sliding marker next to the current step.
                        Rectangle {
                            width: 3
                            height: 18
                            radius: 2
                            color: Theme.accent
                            x: 0
                            y: window.step * 34 + 8
                            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                        }
                        Column {
                            id: stepColumn
                            x: 14
                            spacing: 0
                            Repeater {
                                model: window.steps
                                RowLayout {
                                    required property string modelData
                                    required property int index
                                    height: 34
                                    spacing: 10
                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        color: index < window.step ? Theme.accent : (index === window.step ? Theme.accentSoft : "transparent")
                                        border.color: index <= window.step ? Theme.accent : Theme.borderStrong
                                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: index < window.step ? "" : String(index + 1)
                                            font.family: index < window.step ? Theme.iconFont : Theme.uiFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: index < window.step ? Theme.accentText : (index === window.step ? Theme.accent : Theme.muted)
                                        }
                                    }
                                    Text {
                                        text: modelData
                                        color: index === window.step ? Theme.text : Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 13
                                        font.weight: index === window.step ? Font.DemiBold : Font.Normal
                                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "基于开源项目 Samueli924/chaoxing\n遵循 GPL-3.0 协议"
                        color: Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        lineHeight: 1.3
                        wrapMode: Text.Wrap
                    }
                }
            }

            // ---------- right: pages ----------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Title bar: drag to move, minimise, close.
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 44
                    z: 5
                    DragHandler {
                        target: null
                        onActiveChanged: if (active) window.startSystemMove()
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        IconButton { glyph: ""; tip: "最小化"; onClicked: window.showMinimized() }
                        IconButton { glyph: ""; tip: window.busy ? "卸载中，无法关闭" : "关闭"; enabled: !window.busy; onClicked: Qt.quit() }
                    }
                }

                Item {
                    id: pages
                    anchors.fill: parent
                    anchors.leftMargin: 36
                    anchors.rightMargin: 36
                    anchors.topMargin: 44
                    anchors.bottomMargin: 84
                    clip: true

                    component Page: Item {
                        property int pageIndex: 0
                        readonly property bool current: window.step === pageIndex
                        width: pages.width
                        height: pages.height
                        opacity: current ? 1 : 0
                        visible: opacity > 0.01
                        x: current ? 0 : (pageIndex < window.step ? -40 : 40)
                        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                        Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
                    }

                    // 0 确认
                    Page {
                        pageIndex: 0
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14
                            Item { Layout.preferredHeight: 24 }
                            Text {
                                text: "卸载 " + uninstaller.appName
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 34
                                font.weight: Font.Black
                            }
                            Text {
                                Layout.fillWidth: true
                                text: uninstaller.installed
                                    ? "卸载向导将从这台电脑上移除 " + uninstaller.appName + (uninstaller.version !== "" ? " " + uninstaller.version : "") + "。"
                                    : "当前运行的程序不是通过安装程序安装的（例如免安装版或开发版），无法在这里卸载。直接删除程序文件夹即可。"
                                color: uninstaller.installed ? Theme.muted : Theme.warning
                                font.family: Theme.uiFont
                                font.pixelSize: 14
                                lineHeight: 1.35
                                wrapMode: Text.Wrap
                            }
                            Repeater {
                                model: uninstaller.installed ? [
                                    { glyph: "", text: "删除安装目录中的程序文件" },
                                    { glyph: "", text: "删除桌面和开始菜单快捷方式" },
                                    { glyph: "", text: "从“设置 → 应用”中移除条目" }
                                ] : []
                                RowLayout {
                                    id: bullet
                                    required property var modelData
                                    required property int index
                                    spacing: 12
                                    opacity: 0
                                    transform: Translate { id: bulletShift; x: -10 }
                                    SequentialAnimation {
                                        running: true
                                        PauseAnimation { duration: 300 + bullet.index * 120 }
                                        ParallelAnimation {
                                            NumberAnimation { target: bullet; property: "opacity"; to: 1; duration: Theme.normal }
                                            NumberAnimation { target: bulletShift; property: "x"; to: 0; duration: Theme.normal; easing.type: Easing.OutCubic }
                                        }
                                    }
                                    Rectangle {
                                        width: 30; height: 30; radius: 8
                                        color: Theme.accentSoft
                                        Text { anchors.centerIn: parent; text: modelData.glyph; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.accent }
                                    }
                                    Text { text: modelData.text; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 13 }
                                }
                            }
                            Text {
                                visible: uninstaller.installed
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                text: "安装位置：" + uninstaller.installDir
                                color: Theme.faint
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // 1 卸载选项
                    Page {
                        pageIndex: 1
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14
                            Text { text: "卸载选项"; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 22; font.weight: Font.Bold }
                            Text {
                                Layout.fillWidth: true
                                text: "选择是否同时清除保存在本机的数据。"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                            }
                            Item { Layout.preferredHeight: 4 }
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
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                implicitHeight: dataNote.implicitHeight + 24
                                radius: Theme.radius
                                color: removeAll.checked || !clearAccount.checked ? Theme.warningSoft : Theme.sunken
                                Behavior on color { ColorAnimation { duration: Theme.normal } }
                                Text {
                                    id: dataNote
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: removeAll.checked ? "将删除整个配置目录 %APPDATA%\\ChaoxingDesktop。"
                                        : clearAccount.checked ? "其他设置和日志保留在 %APPDATA%\\ChaoxingDesktop。"
                                        : "账号和设置保留在 %APPDATA%\\ChaoxingDesktop，以后重新安装可以继续使用。"
                                    color: removeAll.checked || !clearAccount.checked ? Theme.warning : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    lineHeight: 1.3
                                    wrapMode: Text.Wrap
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // 2 正在卸载
                    Page {
                        pageIndex: 2
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 16
                            Item { Layout.preferredHeight: 30 }
                            Text { text: "正在卸载"; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 22; font.weight: Font.Bold }
                            Text {
                                text: "正在删除快捷方式和注册信息…"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                            }
                            // Indeterminate bar with the setup wizard's sheen.
                            Rectangle {
                                Layout.fillWidth: true
                                height: 8
                                radius: 4
                                color: Theme.sunken
                                clip: true
                                Rectangle {
                                    width: parent.width * 0.3
                                    height: parent.height
                                    radius: 4
                                    color: Theme.accent
                                    NumberAnimation on x {
                                        from: -pages.width * 0.3
                                        to: pages.width
                                        duration: 1100
                                        loops: Animation.Infinite
                                        running: window.busy
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // 3 完成 / 出错
                    Page {
                        pageIndex: 3
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14
                            Item { Layout.preferredHeight: 30 }
                            Rectangle {
                                width: 72; height: 72; radius: 36
                                color: window.ok ? Theme.successSoft : Theme.dangerSoft
                                scale: window.step === 3 ? 1 : 0.4
                                Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: window.ok ? "" : ""
                                    font.family: Theme.iconFont
                                    font.pixelSize: 30
                                    color: window.ok ? Theme.success : Theme.danger
                                }
                            }
                            Text {
                                text: window.ok ? "卸载完成" : "卸载没有完成"
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 26
                                font.weight: Font.Bold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: window.ok ? "程序文件会在关闭此窗口后删除。感谢使用！" : uninstaller.errorText
                                color: window.ok ? Theme.muted : Theme.danger
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                lineHeight: 1.35
                                wrapMode: Text.WrapAnywhere
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // ---------- footer ----------
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 76
                    color: "transparent"
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 36
                        anchors.rightMargin: 28
                        spacing: 10
                        AppButton {
                            visible: window.step === 1
                            text: "上一步"
                            kind: "ghost"
                            glyph: ""
                            onClicked: window.go(0)
                        }
                        Item { Layout.fillWidth: true }
                        AppButton {
                            visible: window.step < 2
                            text: uninstaller.installed ? "取消" : "关闭"
                            onClicked: Qt.quit()
                        }
                        AppButton {
                            visible: window.step === 0 && uninstaller.installed
                            text: "下一步"
                            kind: "primary"
                            onClicked: window.go(1)
                        }
                        AppButton {
                            visible: window.step === 1
                            text: "卸载"
                            glyph: ""
                            kind: "danger"
                            onClicked: uninstaller.uninstall(clearAccount.checked || removeAll.checked, removeAll.checked)
                        }
                        AppButton {
                            visible: window.step === 3 && !window.ok
                            text: "返回重试"
                            onClicked: window.go(1)
                        }
                        AppButton {
                            visible: window.step === 3
                            text: window.ok ? "完成" : "关闭"
                            kind: "primary"
                            onClicked: Qt.quit()
                        }
                    }
                }
            }
        }
    }
}
