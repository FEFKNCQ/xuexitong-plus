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
    readonly property bool accountConfigured: controller.useCookies
        || (controller.username.trim() !== "" && controller.password !== "")
    readonly property bool overlayOpen: coursePicker.visible || stopConfirm.visible
        || closeConfirm.visible || promptDialog.visible || guide.visible

    Component.onCompleted: showGuide = !controller.onboardingDone

    function openSettings() { window.page = 1 }

    Settings {
        category: "window"
        property alias width: window.width
        property alias height: window.height
    }

    // Content fades and lifts in when the window first appears after the splash.
    Item {
        id: shell
        anchors.fill: parent
        opacity: 0
        transform: Translate { id: shellShift; y: 14 }

        ParallelAnimation {
            id: reveal
            running: window.visible
            NumberAnimation { target: shell; property: "opacity"; to: 1; duration: Theme.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: shellShift; property: "y"; to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
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
                            mipmap: true
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { text: controller.appName; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Text { text: "学习通课程助手"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 11 }
                        }
                    }

                    Item {
                        id: navList
                        Layout.fillWidth: true
                        implicitHeight: navColumn.implicitHeight

                        // One highlight that slides between items.
                        Rectangle {
                            id: navHighlight
                            width: parent.width
                            height: 38
                            y: window.page * (38 + navColumn.spacing)
                            radius: Theme.radius
                            color: Theme.surface
                            border.color: Theme.border
                            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                            Rectangle {
                                width: 3; height: 16; radius: 2
                                color: Theme.accent
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Column {
                            id: navColumn
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: [
                                    { glyph: "", label: "运行面板" },
                                    { glyph: "", label: "设置" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: window.page === index
                                    width: navColumn.width
                                    height: 38
                                    radius: Theme.radius
                                    color: !active && navHover.hovered ? Theme.surfaceAlt : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        spacing: 12
                                        Text {
                                            text: modelData.glyph
                                            font.family: Theme.iconFont
                                            font.pixelSize: 15
                                            color: parent.parent.active ? Theme.accent : Theme.muted
                                            Behavior on color { ColorAnimation { duration: Theme.normal } }
                                        }
                                        Text {
                                            text: modelData.label
                                            color: Theme.text
                                            font.family: Theme.uiFont
                                            font.pixelSize: 13
                                            font.weight: parent.parent.active ? Font.DemiBold : Font.Normal
                                            Layout.fillWidth: true
                                        }
                                        // Dot on 设置: unsaved changes or account still missing.
                                        Rectangle {
                                            visible: index === 1 && (controller.dirty || !window.accountConfigured)
                                            width: 7; height: 7; radius: 4
                                            color: window.accountConfigured ? Theme.accent : Theme.warning
                                            Layout.rightMargin: 12
                                            SequentialAnimation on scale {
                                                running: index === 1 && !window.accountConfigured
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 1.5; duration: 700; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                                            }
                                        }
                                    }
                                    HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: window.page = index }
                                }
                            }
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
                            Text { text: "仅限学习通"; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text {
                                Layout.fillWidth: true
                                text: "配置保存在当前 Windows 用户目录。"
                                color: Theme.muted
                                font.family: Theme.uiFont
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

            // ---------- pages (fade + slide between them) ----------
            Item {
                id: pages
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20

                component PageSlot: Item {
                    property int pageIndex: 0
                    readonly property bool current: window.page === pageIndex
                    width: pages.width
                    height: pages.height
                    opacity: current ? 1 : 0
                    // Hidden pages must be invisible so the native video view disappears with them.
                    visible: opacity > 0.01
                    x: current ? 0 : (pageIndex < window.page ? -36 : 36)
                    Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
                }

                PageSlot {
                    pageIndex: 0
                    DashboardPage {
                        anchors.fill: parent
                        overlayOpen: window.overlayOpen || !parent.current
                        accountConfigured: window.accountConfigured
                        onStopRequested: stopConfirm.open()
                        onSettingsRequested: window.openSettings()
                    }
                }
                PageSlot {
                    pageIndex: 1
                    SettingsPage {
                        anchors.fill: parent
                        onGuideRequested: {
                            guide.reset()
                            window.showGuide = true
                        }
                    }
                }
            }
        }
    }

    // ---------- first-run guide ----------
    Onboarding {
        id: guide
        objectName: "guide"
        anchors.fill: parent
        z: 10
        opacity: window.showGuide ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        onCompleted: {
            window.showGuide = false
            if (!window.accountConfigured)
                toast.show("还没有配置账号，请到“设置 → 账号”填写后再开始运行。", "warning")
        }
    }

    // ---------- toast ----------
    Rectangle {
        id: toast
        property string kind: "info"
        property bool shown: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: shown ? parent.height - height - 26 : parent.height + 8
        z: 20
        width: Math.min(620, toastRow.implicitWidth + 40)
        height: 44
        radius: Theme.radius
        color: kind === "error" ? Theme.dangerSoft : kind === "warning" ? Theme.warningSoft : Theme.surface
        border.color: kind === "error" ? Theme.danger : kind === "warning" ? Theme.warning : Theme.border
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 10
            Text {
                text: toast.kind === "error" ? "" : toast.kind === "warning" ? "" : ""
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: toast.kind === "error" ? Theme.danger : toast.kind === "warning" ? Theme.warning : Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: toastText
                width: Math.min(implicitWidth, 560)
                elide: Text.ElideRight
                color: toast.kind === "error" ? Theme.danger : toast.kind === "warning" ? Theme.warning : Theme.text
                font.family: Theme.uiFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Timer { id: toastTimer; interval: 4600; onTriggered: toast.shown = false }
        function show(message, kind) {
            toastText.text = message
            toast.kind = kind
            toast.shown = true
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
        destructive: true
        onAccepted: controller.stopRun()
    }

    ConfirmDialog {
        id: closeConfirm
        title: "任务仍在运行"
        message: "关闭窗口将结束当前任务。仍要退出吗？"
        acceptText: "退出"
        destructive: true
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
