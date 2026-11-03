import QtQuick
import QtWebView
import "."

// Muted, control-less video surface. The page itself ignores pointer and keyboard input.
// The native WebView cannot be faded, so transitions happen around it: a QML placeholder
// (with a slow breathing glow) is shown while there is no video, and a short dark
// "reveal" hold covers the switch to a new video before the web view appears.
Rectangle {
    id: root
    property bool suspended: false
    property bool revealing: false
    readonly property bool showWeb: controller.videoActive && !suspended && !revealing

    color: "#05080f"
    radius: Theme.radius
    clip: true

    function reload() {
        if (!webView.visible)
            return
        // Prefer the page served by the local video proxy: WebView2 turns loadHtml() into a
        // data: URL navigation, which does not reliably play the video.
        if (controller.videoPageUrl !== "")
            webView.url = controller.videoPageUrl
        else
            webView.loadHtml(controller.videoHtml, controller.videoBaseUrl)
    }

    WebView {
        id: webView
        anchors.fill: parent
        anchors.margins: 1
        visible: root.visible && root.showWeb
        settings.javaScriptEnabled: true
        settings.localStorageEnabled: false
        settings.allowFileAccess: false
        settings.localContentCanAccessFileUrls: false
        onVisibleChanged: root.reload()
        Component.onCompleted: root.reload()
    }

    Connections {
        target: controller
        function onVideoChanged() {
            if (controller.videoActive && Theme.motion) {
                root.revealing = true
                revealTimer.restart()
            } else {
                root.reload()
            }
        }
    }
    Timer {
        id: revealTimer
        interval: 380
        onTriggered: {
            root.revealing = false
            root.reload()
        }
    }

    // Placeholder (no video, dialog open, or the brief reveal hold).
    Item {
        anchors.fill: parent
        visible: !root.showWeb
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        // Breathing glow.
        Rectangle {
            id: glow
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.9
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.31, 0.51, 0.96, 0.22) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            opacity: 0.6
            SequentialAnimation on opacity {
                running: root.visible && !root.showWeb && Theme.motion
                loops: Animation.Infinite
                NumberAnimation { to: 0.15; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.6; duration: 1800; easing.type: Easing.InOutSine }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.suspended ? "" : ""
                font.family: Theme.iconFont
                font.pixelSize: 26
                color: "#8e9bb3"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.suspended ? "预览已暂停显示"
                    : root.revealing ? "正在载入视频…"
                    : (controller.videoMessage !== "" ? controller.videoMessage : "等待视频任务开始")
                color: "#d7e0ee"
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.suspended && !root.revealing
                text: "运行学习通视频任务后，画面会自动显示"
                color: "#8e9bb3"
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }
}
