import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "."

ApplicationWindow {
    id: window
    width: 1380
    height: 880
    minimumWidth: 1140
    minimumHeight: 720
    visible: false
    title: controller.appName
    color: Theme.bg

    property int page: 0
    property bool allowClose: false
    property bool showGuide: false
    readonly property bool overlayOpen: coursePicker.visible || stopConfirm.visible
        || closeConfirm.visible || promptDialog.visible || guide.visible

    Component.onCompleted: showGuide = !controller.onboardingDone

    Settings {
        category: "window"
        property alias width: window.width
        property alias height: window.height
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- navigation pane ----------
        Rectangle {
            Layout.preferredWidth: 208
            Layout.fillHeight: true
            color: Theme.pane

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 20
                spacing: 4

                RowLayout {
                    spacing: 10
                    Layout.leftMargin: 4
                    Layout.bottomMargin: 22
                    Image {
                        source: controller.iconUrl
                        sourceSize.width: 36
                        sourceSize.height: 36
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        smooth: true
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: controller.appName; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Text { text: "学习通课程助手"; color: Theme.muted; font.pixelSize: 11 }
                    }
                }

                Repeater {
                    model: [
                        { glyph: "", label: "运行面板" },
                        { glyph: "", label: "设置" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool active: window.page === index
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Theme.radius
                        color: active ? Theme.surface : (navHover.hovered ? Theme.surfaceAlt : "transparent")
                        border.color: active ? Theme.border : "transparent"

                        Rectangle {
                            visible: parent.active
                            width: 3; height: 16; radius: 2
                            color: Theme.accent
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            spacing: 12
                            Text { text: modelData.glyph; font.family: Theme.iconFont; font.pixelSize: 15; color: parent.parent.active ? Theme.accent : Theme.muted }
                            Text { text: modelData.label; color: Theme.text; font.pixelSize: 13; font.weight: parent.parent.active ? Font.DemiBold : Font.Normal; Layout.fillWidth: true }
                            Rectangle {
                                visible: index === 1 && controller.dirty
                                width: 7; height: 7; radius: 4
                                color: Theme.accent
                                Layout.rightMargin: 12
                            }
                        }
                        HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: window.page = index }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: noteCol.implicitHeight + 20
                    radius: Theme.radius
                    color: Theme.surfaceAlt
                    ColumnLayout {
                        id: noteCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 3
                        Text { text: "仅限学习通"; color: Theme.text; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "配置保存在当前 Windows 用户目录。"
                            color: Theme.muted
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }
                }
                Text {
                    Layout.topMargin: 8
                    Layout.leftMargin: 4
                    text: "v" + controller.version
                    color: Theme.faint
                    font.pixelSize: 11
                }
            }
        }

        // ---------- pages ----------
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            currentIndex: window.page

            DashboardPage {
                overlayOpen: window.overlayOpen
                onStopRequested: stopConfirm.open()
            }
            SettingsPage { onGuideRequested: { guide.step = 0; guide.agreed = false; window.showGuide = true } }
        }
    }

    // ---------- first-run guide ----------
    Onboarding {
        id: guide
        objectName: "guide"
        anchors.fill: parent
        visible: window.showGuide
        z: 10
        onCompleted: window.showGuide = false
    }

    // ---------- toast ----------
    Rectangle {
        id: toast
        property string kind: "info"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        z: 20
        width: Math.min(560, toastText.implicitWidth + 48)
        height: 42
        radius: Theme.radius
        color: kind === "error" ? Theme.dangerSoft : kind === "warning" ? Theme.warningSoft : Theme.surface
        border.color: kind === "error" ? Theme.danger : kind === "warning" ? Theme.warning : Theme.border
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 512)
            elide: Text.ElideRight
            color: toast.kind === "error" ? Theme.danger : toast.kind === "warning" ? Theme.warning : Theme.text
            font.pixelSize: 13
        }
        Timer { id: toastTimer; interval: 4200; onTriggered: toast.opacity = 0 }
        function show(message, kind) {
            toastText.text = message
            toast.kind = kind
            toast.opacity = 1
            toastTimer.restart()
        }
    }

    // ---------- dialogs ----------
    CoursePickerDialog { id: coursePicker; objectName: "coursePicker" }

    ConfirmDialog {
        id: stopConfirm
        title: "停止任务"
        message: "立即结束当前任务进程？未完成的章节可在下次启动时重试。"
        acceptText: "停止"
        onAccepted: controller.stopRun()
    }

    ConfirmDialog {
        id: closeConfirm
        title: "任务仍在运行"
        message: "关闭窗口将结束当前任务。仍要退出吗？"
        acceptText: "退出"
        onAccepted: {
            window.allowClose = true
            controller.shutdown()
            window.close()
        }
    }

    ConfirmDialog {
        id: promptDialog
        title: "任务进程需要确认"
        acceptText: "继续"
        rejectText: "不继续"
        onAccepted: controller.answerPrompt(true)
        onRejected: controller.answerPrompt(false)
    }

    Connections {
        target: controller
        function onToast(message, kind) { toast.show(message, kind) }
        function onRunStateChanged() {
            if (!controller.running) {
                coursePicker.close()
                promptDialog.close()
                stopConfirm.close()
            }
        }
        function onCourseSelectionRequested(courses) { coursePicker.openWith(courses) }
        function onPromptRequested(text) {
            promptDialog.message = text
            promptDialog.open()
        }
    }

    onClosing: close => {
        if (controller.running && !window.allowClose) {
            close.accepted = false
            closeConfirm.open()
        }
    }
}
